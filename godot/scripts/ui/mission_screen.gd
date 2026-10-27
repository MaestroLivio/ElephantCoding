extends AppScreen

## Mission view. The deterministic simulator decides the outcome; this screen
## projects it on the 3D stage, animates the event stream and shows goals,
## hints, variables and step-by-step playback.

var mission: Dictionary = {}
var world: Dictionary = {}
var mission_id := ""
var builder: WorldBuilder
var rig: CameraRig
var sim: CodingSimulator
var playback: Playback
var result: Dictionary = {}
var editor: ProgramEditor

var _touch_area: Control
var _run_btn: Button
var _step_btn: Button
var _status: Label
var _steps_label: Label
var _goal_box: VBoxContainer
var _hint_box: VBoxContainer
var _hint_button: Button
var _debug_label: Label
var _camera_btn: Button
var _subtitle_panel: PanelContainer
var _subtitle_label: Label
var _success_overlay: Control
var _hint_level := 0
var _press_pos := Vector2.ZERO
var _dragging := false
var _camera_mode := 0


func build() -> void:
	mission_id = str(args.get("mission_id", ""))
	mission = MissionRepository.mission(mission_id)
	if mission.is_empty():
		var all := MissionRepository.missions()
		if not all.is_empty():
			mission = all[0]
			mission_id = str(mission.get("id", ""))
	world = MissionRepository.world(str(mission.get("world", args.get("world_id", ""))))
	_camera_mode = maxi(0, ["fixed", "chase", "first"].find(str(GameState.get_setting("camera_mode", "fixed"))))
	_build_stage()
	_build_ui()
	editor.set_mission(mission)
	_refresh_goals({}, false)
	_update_debug()
	_populate_hints()
	_set_status("Pronto. Componi il programma e premi ESEGUI.", Palette.MUTED)
	var narration := str(mission.get("narration_line", mission.get("narrative", "")))
	if narration != "":
		_show_subtitle(narration)
		Narration.speak(mission_id.to_lower(), narration, 8.0)
	Narration.subtitle.connect(_on_narration_subtitle)


func leave() -> void:
	if Narration.subtitle.is_connected(_on_narration_subtitle):
		Narration.subtitle.disconnect(_on_narration_subtitle)
	Narration.stop()


# ---------------------------------------------------------------------------
# Stage
# ---------------------------------------------------------------------------
func _build_stage() -> void:
	builder = WorldBuilder.new()
	var out := builder.build_mission(mission)
	use_stage(out.root)
	rig = CameraRig.new()
	rig.name = "CameraRig"
	out.root.add_child(rig)
	var bounds: Rect2 = out.get("bounds", Rect2(-5, -4, 10, 8))
	rig.fov = 32.0
	rig.safe_rect = Rect2(0.379, 0.111, 0.392, 0.778)
	rig.setup_for_bounds(bounds, builder.nilo)
	rig.mode = _camera_mode
	rig.zoom = 1.0
	rig.current = true


func _rebuild_stage() -> void:
	if playback != null:
		playback.builder = null
	_build_stage()
	if playback != null:
		playback.builder = builder


# ---------------------------------------------------------------------------
# UI
# ---------------------------------------------------------------------------
func _build_ui() -> void:
	_touch_area = Control.new()
	_touch_area.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_touch_area.mouse_filter = Control.MOUSE_FILTER_STOP
	_touch_area.gui_input.connect(_on_stage_touch)
	add_child(_touch_area)

	_build_top_bar()
	_build_left_panel()
	_build_right_panel()
	_build_subtitle()

	playback = Playback.new()
	playback.name = "Playback"
	playback.speed = 8.0 if bool(GameState.get_setting("reduce_motion", false)) else 3.0
	playback.event_applied.connect(_on_event)
	playback.finished.connect(_on_playback_finished)
	playback.state_changed.connect(_on_playback_state)
	add_child(playback)


func _build_top_bar() -> void:
	var bar := PanelContainer.new()
	bar.add_theme_stylebox_override("panel", Palette.style(Color(0.06, 0.10, 0.17, 0.95), 18, Color(1, 1, 1, 0.10), 1))
	bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	bar.offset_left = 24
	bar.offset_right = -24
	bar.offset_top = 16
	bar.offset_bottom = 88
	add_child(bar)

	var h := Palette.hbox(10)
	bar.add_child(h)

	var back := Palette.ghost_button("← MONDO", 16)
	back.custom_minimum_size = Vector2(128, 50)
	back.pressed.connect(func(): go("hub", {"world_id": str(world.get("id", mission.get("world", "")))}))
	h.add_child(back)

	var titles := Palette.vbox(0)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(titles)
	titles.add_child(Palette.label(mission_id + " · " + str(world.get("title", str(mission.get("world", "")))), 12, Palette.MUTED))
	var title := Palette.label(str(mission.get("title", "Missione")), 22, Palette.CREAM)
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.max_lines_visible = 1
	title.clip_text = true
	titles.add_child(title)

	_steps_label = Palette.label("passi 0", 13, Palette.MUTED)
	_steps_label.custom_minimum_size = Vector2(90, 0)
	h.add_child(_steps_label)

	_camera_btn = Palette.ghost_button("VISTA", 14)
	_camera_btn.custom_minimum_size = Vector2(128, 48)
	_camera_btn.pressed.connect(_cycle_camera)
	h.add_child(_camera_btn)
	_update_camera_button()

	var zoom_in := Palette.ghost_button("+", 20)
	zoom_in.custom_minimum_size = Vector2(48, 48)
	zoom_in.tooltip_text = "Avvicina la vista"
	zoom_in.pressed.connect(func():
		if rig != null:
			rig.zoom_by(0.88))
	h.add_child(zoom_in)
	var zoom_out := Palette.ghost_button("-", 20)
	zoom_out.custom_minimum_size = Vector2(48, 48)
	zoom_out.tooltip_text = "Allontana la vista"
	zoom_out.pressed.connect(func():
		if rig != null:
			rig.zoom_by(1.14))
	h.add_child(zoom_out)

	var voice := Palette.ghost_button("VOCE", 14)
	voice.custom_minimum_size = Vector2(96, 48)
	voice.pressed.connect(func():
		var enabled := not bool(GameState.get_setting("voice", true))
		GameState.set_setting("voice", enabled)
		toast("Voce " + ("attiva" if enabled else "disattivata"), 1.6)
		voice.text = "VOCE ON" if enabled else "VOCE OFF")
	voice.text = "VOCE ON" if bool(GameState.get_setting("voice", true)) else "VOCE OFF"
	h.add_child(voice)

	if bool(GameState.get_setting("show_solution", false)):
		var solution := Palette.ghost_button("SOLUZIONE", 13)
		solution.custom_minimum_size = Vector2(110, 48)
		solution.pressed.connect(_show_solution)
		h.add_child(solution)


func _editor_label(editor: String) -> String:
	return {
		"icons": "ICONE",
		"beads": "PERLE",
		"text": "TESTO",
		"structured": "STRUTTURATO",
		"coordinates": "COORDINATE",
		"pseudocode": "PSEUDOCODICE",
		"systems": "SISTEMI",
		"data": "DATI",
	}.get(editor, editor.to_upper())


func _build_left_panel() -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Palette.style(Color(0.06, 0.10, 0.17, 0.95), 20, Color(1, 1, 1, 0.10), 1))
	panel.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	panel.offset_left = 24
	panel.offset_right = 606
	panel.offset_top = 100
	panel.offset_bottom = -24
	add_child(panel)

	var box := Palette.vbox(8)
	panel.add_child(box)

	var head := Palette.hbox(8)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(head)
	head.add_child(Palette.label("PROGRAMMA DI NILO", 13, Palette.MUTED))
	var grow := Control.new()
	grow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(grow)
	head.add_child(Palette.label(_editor_label(str(mission.get("editor", "text"))), 12, Palette.PURPLE))

	editor = ProgramEditor.new()
	editor.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(editor)

	var actions := Palette.hbox(8)
	box.add_child(actions)
	_run_btn = Palette.button("ESEGUI", Palette.TEAL, 20)
	_run_btn.custom_minimum_size = Vector2(0, 62)
	_run_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_run_btn.pressed.connect(_on_run)
	actions.add_child(_run_btn)
	_step_btn = Palette.button("PASSO", Palette.CARD_LIGHT, 17)
	_step_btn.custom_minimum_size = Vector2(120, 62)
	_step_btn.pressed.connect(_on_step)
	actions.add_child(_step_btn)
	var reset := Palette.ghost_button("RESET", 15)
	reset.custom_minimum_size = Vector2(100, 62)
	reset.pressed.connect(_on_reset)
	actions.add_child(reset)

	_status = Palette.label("", 14, Palette.MUTED)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(0, 40)
	box.add_child(_status)


func _build_right_panel() -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Palette.style(Color(0.06, 0.10, 0.17, 0.95), 20, Color(1, 1, 1, 0.10), 1))
	panel.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	panel.offset_left = -366
	panel.offset_right = -24
	panel.offset_top = 100
	panel.offset_bottom = -24
	add_child(panel)

	var outer := Palette.vbox(6)
	panel.add_child(outer)
	var scroll := Palette.scroll()
	outer.add_child(scroll)
	var box := Palette.vbox(10)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)

	box.add_child(Palette.label("OBIETTIVO", 13, Palette.MUTED))
	box.add_child(Palette.label(str(mission.get("coding_goal", mission.get("narrative", ""))), 14, Palette.CREAM, true))
	_goal_box = Palette.vbox(4)
	box.add_child(_goal_box)

	box.add_child(Palette.spacer(4))
	box.add_child(Palette.label("AIUTI", 13, Palette.MUTED))
	_hint_button = Palette.button("MOSTRA UN AIUTO", Palette.YELLOW, 15)
	_hint_button.custom_minimum_size = Vector2(0, 46)
	_hint_button.pressed.connect(_on_hint)
	box.add_child(_hint_button)
	_hint_box = Palette.vbox(4)
	box.add_child(_hint_box)

	box.add_child(Palette.spacer(4))
	box.add_child(Palette.label("DIAGNOSTICA", 13, Palette.MUTED))
	_debug_label = Palette.label("Nessuna esecuzione.", 13, Palette.MUTED, true)
	_debug_label.custom_minimum_size = Vector2(0, 60)
	box.add_child(_debug_label)


func _build_subtitle() -> void:
	_subtitle_panel = PanelContainer.new()
	_subtitle_panel.add_theme_stylebox_override("panel", Palette.style(Color(0.04, 0.07, 0.12, 0.90), 14, Color(1, 1, 1, 0.10), 1))
	_subtitle_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_subtitle_panel.offset_left = 610
	_subtitle_panel.offset_right = -372
	_subtitle_panel.offset_top = -100
	_subtitle_panel.offset_bottom = -28
	_subtitle_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_subtitle_panel)
	_subtitle_label = Palette.label("", 16, Palette.CREAM, true)
	_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_subtitle_label.max_lines_visible = 3
	_subtitle_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_subtitle_panel.add_child(_subtitle_label)


func _show_subtitle(text: String) -> void:
	if _subtitle_panel == null:
		return
	_subtitle_label.text = text
	_subtitle_panel.visible = text != ""


# ---------------------------------------------------------------------------
# Execution
# ---------------------------------------------------------------------------
func _on_run() -> void:
	if playback == null:
		return
	if playback.playing:
		playback.pause()
		return
	if not result.is_empty() and playback.index > 0 and not playback.is_finished():
		playback.play()
		_set_status("Riprendo l'esecuzione…", Palette.CREAM)
		return
	_execute(true)


func _on_step() -> void:
	if playback == null:
		return
	if result.is_empty() or playback.is_finished():
		_execute(false)
		if result.is_empty():
			return
		if not playback.step() and playback.is_finished():
			_on_playback_finished()
	else:
		playback.pause()
		if not playback.step() and playback.is_finished():
			_on_playback_finished()


func _execute(auto_play: bool) -> void:
	_hide_success()
	var source := editor.get_source()
	if source.strip_edges().is_empty():
		toast("Scrivi almeno un comando per Nilo.", 3.0, Palette.YELLOW)
		_set_status("Il programma è vuoto.", Palette.YELLOW)
		return
	editor.clear_error()
	_rebuild_stage()
	playback.reset()
	sim = CodingSimulator.new()
	sim.setup(mission)
	result = sim.run(source)
	_refresh_goals(result.get("checks", {}), true)
	_update_debug()
	_set_status("Programma eseguito: osserva Nilo.", Palette.CREAM)
	if not result.parse_error.is_empty():
		var line := int(result.parse_error.get("line", 0))
		editor.show_error_line(line, str(result.parse_error.get("message", "Errore di sintassi.")))
		_set_status("Errore di sintassi alla riga %d." % line, Palette.CORAL)
		Narration.speak("errore", "C'è un errore alla riga %d. Controlla il comando e riprova." % line, 4.0)
		return
	var events: Array = result.get("events", [])
	playback.load_events(events, builder)
	if auto_play:
		playback.play()
		_run_btn.text = "PAUSA"
	else:
		_run_btn.text = "CONTINUA"
	if events.is_empty():
		_on_playback_finished()


func _on_reset() -> void:
	_hide_success()
	result = {}
	if playback != null:
		playback.reset()
	_rebuild_stage()
	editor.clear_error()
	_refresh_goals({}, false)
	_update_debug()
	_set_status("Pronto. Componi il programma e premi ESEGUI.", Palette.MUTED)
	_run_btn.text = "ESEGUI"


func _on_playback_state(playing: bool, index: int, total: int) -> void:
	if _run_btn != null:
		if playing:
			_run_btn.text = "PAUSA"
		elif index >= total and total > 0:
			_run_btn.text = "RIPETI"
		else:
			_run_btn.text = "CONTINUA" if index > 0 else "ESEGUI"
	if _steps_label != null:
		_steps_label.text = "passi %d" % _count_steps(index)


func _count_steps(index: int) -> int:
	if playback == null:
		return 0
	var n := 0
	for i in range(mini(index, playback.events.size())):
		if str(playback.events[i].get("kind", "")) == "step":
			n += 1
	return n


func _on_playback_finished() -> void:
	if result.is_empty():
		return
	var steps := int(result.get("steps", 0))
	var success := bool(result.get("success", false))
	_refresh_goals(result.get("checks", {}), true)
	_update_debug()
	GameState.record_attempt(mission_id, success, steps, _hint_level)
	if success:
		editor.mark_success()
		_set_status("Missione compiuta in %d passi!" % steps, Palette.GREEN)
		_run_btn.text = "RIPETI"
		if builder != null and builder.nilo != null:
			builder.nilo.celebrate()
		GameState.award_badge(mission_id)
		Narration.speak(mission_id.to_lower() + "_ok", str(mission.get("success_text", "Missione compiuta!")), 6.0)
		_show_success(steps)
	else:
		var reason := str(result.get("failure_reason", "Obiettivo non raggiunto."))
		_set_status(reason, Palette.CORAL)
		toast(reason, 5.0, Palette.CORAL)
		_run_btn.text = "RIPROVA"
		var evs: Array = result.get("events", [])
		if not evs.is_empty() and str(evs[-1].get("kind", "")) == "error":
			var msg := str(evs[-1].get("message", ""))
			if msg != "":
				Narration.speak("errore", msg, 5.0)


func _on_event(ev: Dictionary) -> void:
	var kind := str(ev.get("kind", ""))
	if kind == "variable_change":
		_update_debug()
	elif kind == "no_effect":
		var msg := str(ev.get("message", ""))
		if msg != "":
			_set_status(msg, Palette.YELLOW)


# ---------------------------------------------------------------------------
# Goals, hints, debug
# ---------------------------------------------------------------------------
func _refresh_goals(checks: Dictionary, has_result: bool) -> void:
	if _goal_box == null:
		return
	for c in _goal_box.get_children():
		c.queue_free()
	var items := _goal_items()
	if items.is_empty():
		_goal_box.add_child(Palette.label("Esplora liberamente: non ci sono vincoli.", 13, Palette.MUTED, true))
		return
	for item in items:
		var key := str(item.get("key", ""))
		var has_key := checks.has(key)
		var ok := bool(checks.get(key, false)) if has_key else false
		var glyph := "•"
		var color := Palette.MUTED
		if has_result and has_key:
			glyph = "✓" if ok else "✕"
			color = Palette.GREEN if ok else Palette.CORAL
		var row := Palette.hbox(8)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var g := Palette.label(glyph, 16, color)
		g.custom_minimum_size = Vector2(18, 0)
		row.add_child(g)
		var t := Palette.label(str(item.get("text", "")), 13, color if has_result else Palette.CREAM, true)
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(t)
		_goal_box.add_child(row)


func _goal_items() -> Array:
	var items: Array = []
	var goal: Dictionary = mission.get("goal", {})
	if goal.has("reach"):
		items.append({"key": "reach", "text": "Raggiungi la cella (%d, %d)" % [int(goal.reach[0]), int(goal.reach[1])]})
	if goal.has("collect_all"):
		items.append({"key": "collect_all", "text": "Raccogli: " + _labels_for(goal.collect_all)})
	if goal.has("activate_all"):
		items.append({"key": "activate_all", "text": "Attiva: " + _labels_for(goal.activate_all)})
	if goal.has("photo_all"):
		items.append({"key": "photo_all", "text": "Fotografa: " + _labels_for(goal.photo_all)})
	if goal.has("visit_order"):
		items.append({"key": "visit_order", "text": "Visita le tappe nell'ordine indicato"})
	if goal.get("trace_closed", false):
		items.append({"key": "trace_closed", "text": "Chiudi la traccia tornando al punto iniziale"})
	if goal.get("vars") is Dictionary:
		for k in goal.vars:
			items.append({"key": "var_" + str(k), "text": "La variabile «%s» deve valere %s" % [str(k), str(goal.vars[k])]})
	if goal.get("min_vars") is Dictionary:
		for k in goal.min_vars:
			items.append({"key": "min_" + str(k), "text": "La variabile «%s» deve essere almeno %s" % [str(k), str(goal.min_vars[k])]})
	if goal.get("event_counts") is Dictionary:
		for kind in goal.event_counts:
			items.append({"key": "event_" + str(kind), "text": "Almeno %d eventi «%s»" % [int(goal.event_counts[kind]), str(kind)]})
	return items


func _labels_for(ids: Array) -> String:
	var names: Array = []
	var counts: Dictionary = {}
	for id in ids:
		var found := str(id)
		for e in mission.get("entities", []):
			if str(e.get("id", "")) == str(id):
				found = str(e.get("label", id))
				break
		names.append(found)
		counts[found] = int(counts.get(found, 0)) + 1
	if counts.size() == 1:
		var only := str(counts.keys()[0])
		var n := int(counts[only])
		return ("%d × " % n) + only
	return ", ".join(names)


func _populate_hints() -> void:
	for c in _hint_box.get_children():
		c.queue_free()
	_hint_level = 0
	_update_hint_button()


func _on_hint() -> void:
	var hints: Array = mission.get("hints", [])
	if _hint_level >= hints.size():
		toast("Hai già visto tutti gli aiuti di questa missione.", 3.0, Palette.MUTED)
		return
	var hint: Dictionary = hints[_hint_level]
	_hint_level += 1
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Palette.style(Color(1, 1, 1, 0.06), 10))
	var l := Palette.label(str(hint.get("text", "")), 13, Palette.CREAM, true)
	panel.add_child(l)
	_hint_box.add_child(panel)
	Narration.speak("%s_hint%d" % [mission_id.to_lower(), _hint_level], str(hint.get("text", "")), 6.0)
	_update_hint_button()


func _update_hint_button() -> void:
	if _hint_button == null:
		return
	var total: int = mission.get("hints", []).size()
	var left := maxi(0, total - _hint_level)
	_hint_button.text = "MOSTRA UN AIUTO (%d)" % left if left > 0 else "AIUTI ESAURITI"
	_hint_button.disabled = left <= 0


func _update_debug() -> void:
	if _debug_label == null:
		return
	if result.is_empty():
		_debug_label.text = "Nessuna esecuzione. Premi ESEGUI per vedere le variabili."
		return
	var state: Dictionary = result.get("state", {})
	var vars: Dictionary = state.get("vars", {})
	var lines: Array = []
	var count := 0
	for k in vars:
		if count >= 9:
			lines.append("…")
			break
		var v = vars[k]
		if v is Array:
			lines.append("%s = [%s]" % [str(k), ", ".join(v.map(func(x): return str(x)))])
		else:
			lines.append("%s = %s" % [str(k), str(v)])
		count += 1
	lines.append("passi: %d · tick: %d" % [int(result.get("steps", 0)), int(result.get("ticks", 0))])
	_debug_label.text = "\n".join(lines)


func _show_solution() -> void:
	var ref := str(mission.get("reference_program", ""))
	if ref.is_empty():
		toast("Questa missione non ha una soluzione di riferimento.", 3.0, Palette.MUTED)
		return
	editor.set_source(ref)
	_set_status("Soluzione caricata nell'editor. Premi ESEGUI per provarla.", Palette.YELLOW)


# ---------------------------------------------------------------------------
# Success overlay
# ---------------------------------------------------------------------------
func _show_success(steps: int) -> void:
	_hide_success()
	_success_overlay = Control.new()
	_success_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_success_overlay)

	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.05, 0.09, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_success_overlay.add_child(dim)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Palette.style(Palette.CARD, 26, Palette.GREEN, 3))
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -370
	panel.offset_right = 370
	panel.offset_top = -250
	panel.offset_bottom = 250
	_success_overlay.add_child(panel)

	var box := Palette.vbox(14)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(box)
	var stars := 3 - mini(2, _hint_level)
	var star_text := "★".repeat(stars) + "☆".repeat(3 - stars)
	var star_label := Palette.label(star_text, 40, Palette.YELLOW)
	star_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(star_label)
	var title := Palette.title("MISSIONE COMPIUTA!", 34)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var sub := Palette.label(str(mission.get("success_text", "")), 17, Palette.CREAM, true)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)
	var stats := Palette.label("Passi simulati: %d · Aiuti usati: %d" % [steps, _hint_level], 14, Palette.MUTED)
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(stats)

	var next_id := _next_mission_id()
	var actions := Palette.hbox(10)
	box.add_child(actions)
	var again := Palette.ghost_button("RIPETI", 16)
	again.custom_minimum_size = Vector2(0, 56)
	again.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	again.pressed.connect(func():
		_hide_success()
		_on_reset())
	actions.add_child(again)

	if next_id != "":
		var nxt := Palette.button("PROSSIMA MISSIONE", Palette.GREEN, 17)
		nxt.custom_minimum_size = Vector2(0, 56)
		nxt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nxt.pressed.connect(func(): go("mission", {"world_id": str(mission.get("world", "")), "mission_id": next_id}))
		actions.add_child(nxt)

	var hub := Palette.ghost_button("TORNA AL MONDO", 15)
	hub.custom_minimum_size = Vector2(0, 56)
	hub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hub.pressed.connect(func(): go("hub", {"world_id": str(mission.get("world", ""))}))
	actions.add_child(hub)

	var bonus := str(mission.get("extension", ""))
	if bonus != "":
		box.add_child(Palette.label("Prova anche: " + bonus, 13, Palette.MUTED, true))


func _hide_success() -> void:
	if _success_overlay != null:
		_success_overlay.queue_free()
		_success_overlay = null


func _next_mission_id() -> String:
	var ids := MissionRepository.mission_ids(str(mission.get("world", "")))
	var index := ids.find(mission_id)
	if index >= 0 and index + 1 < ids.size():
		return str(ids[index + 1])
	return ""


# ---------------------------------------------------------------------------
# Camera and input
# ---------------------------------------------------------------------------
func _cycle_camera() -> void:
	if rig == null:
		return
	_camera_mode = rig.cycle_mode()
	_update_camera_button()
	var names := ["fixed", "chase", "first"]
	GameState.set_setting("camera_mode", names[_camera_mode])
	toast("Vista: " + rig.cycle_name(), 1.5, Palette.CREAM)


func _update_camera_button() -> void:
	if _camera_btn == null or rig == null:
		return
	var short := ["FISSA", "SEGUI", "1ª PERSONA"]
	_camera_btn.text = "VISTA: " + short[clampi(_camera_mode, 0, 2)]


func _on_stage_touch(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and rig != null:
			rig.zoom_by(0.92)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and rig != null:
			rig.zoom_by(1.08)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_press_pos = event.position
				_dragging = true
			else:
				_dragging = false
	elif event is InputEventMouseMotion and _dragging and rig != null:
		rig.orbit_by(event.relative.x, event.relative.y)
	elif event is InputEventScreenTouch:
		_press_pos = event.position
	elif event is InputEventScreenDrag and rig != null:
		rig.orbit_by(event.relative.x, event.relative.y)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1:
				_camera_mode = 0
				if rig != null:
					rig.set_mode(0)
				_update_camera_button()
			KEY_2:
				_camera_mode = 1
				if rig != null:
					rig.set_mode(1)
				_update_camera_button()
			KEY_3:
				_camera_mode = 2
				if rig != null:
					rig.set_mode(2)
				_update_camera_button()
			KEY_F5:
				_on_run()
			KEY_F6:
				_on_step()
			KEY_F7:
				_on_reset()
			KEY_ESCAPE:
				go("hub", {"world_id": str(mission.get("world", ""))})


func _on_narration_subtitle(text: String, _seconds: float) -> void:
	_show_subtitle(text)


func _set_status(text: String, color: Color) -> void:
	if _status == null:
		return
	_status.text = text
	_status.add_theme_color_override("font_color", color)
