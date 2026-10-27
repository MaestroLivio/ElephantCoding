extends AppScreen

## Teacher console: class overview, per-mission evidence, local export and
## classroom defaults. The optional PIN is a local classroom courtesy lock,
## not a security boundary.

var _root: Control
var _gate_error: Label
var _pin_input: LineEdit
var _confirm: ConfirmationDialog
var _notice: Label
var _new_pin: LineEdit


func build() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Palette.BG
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	var pin := str(GameState.get_setting("teacher_pin", ""))
	if pin != "":
		_build_gate()
	else:
		_build_content()


func _build_gate() -> void:
	if _root != null:
		_root.queue_free()
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var bar := PanelContainer.new()
	bar.add_theme_stylebox_override("panel", Palette.style(Color(0.06, 0.10, 0.17, 0.96), 18, Color(1, 1, 1, 0.10), 1))
	bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	bar.offset_left = 36
	bar.offset_right = -36
	bar.offset_top = 24
	bar.offset_bottom = 108
	_root.add_child(bar)
	var h := Palette.hbox(14)
	bar.add_child(h)
	var back := Palette.ghost_button("← MENU", 16)
	back.custom_minimum_size = Vector2(130, 54)
	back.pressed.connect(func(): go("menu"))
	h.add_child(back)
	h.add_child(Palette.title("AREA INSEGNANTE", 27))

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Palette.style(Palette.CARD, 24, Palette.PURPLE, 2))
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -300
	panel.offset_right = 300
	panel.offset_top = -190
	panel.offset_bottom = 190
	_root.add_child(panel)
	var box := Palette.vbox(12)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(box)
	box.add_child(Palette.title("CODICE DOCENTE", 28))
	box.add_child(Palette.label("Inserisci il PIN impostato nelle preferenze della classe. Il PIN resta sul dispositivo.", 14, Palette.MUTED, true))
	_pin_input = LineEdit.new()
	_pin_input.secret = true
	_pin_input.placeholder_text = "PIN"
	_pin_input.custom_minimum_size = Vector2(0, 56)
	_pin_input.add_theme_font_size_override("font_size", 22)
	_pin_input.text_submitted.connect(func(_t): _check_pin())
	box.add_child(_pin_input)
	_gate_error = Palette.label("", 14, Palette.CORAL)
	box.add_child(_gate_error)
	var enter := Palette.button("ENTRA", Palette.TEAL, 18)
	enter.custom_minimum_size = Vector2(0, 56)
	enter.pressed.connect(_check_pin)
	box.add_child(enter)
	_pin_input.grab_focus()


func _check_pin() -> void:
	if _pin_input.text == str(GameState.get_setting("teacher_pin", "")):
		_root.queue_free()
		_build_content()
	else:
		_gate_error.text = "PIN non corretto. Riprova."


func _build_content() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var bar := PanelContainer.new()
	bar.add_theme_stylebox_override("panel", Palette.style(Color(0.06, 0.10, 0.17, 0.96), 18, Color(1, 1, 1, 0.10), 1))
	bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	bar.offset_left = 36
	bar.offset_right = -36
	bar.offset_top = 24
	bar.offset_bottom = 108
	_root.add_child(bar)
	var h := Palette.hbox(12)
	bar.add_child(h)
	var back := Palette.ghost_button("← MENU", 16)
	back.custom_minimum_size = Vector2(130, 54)
	back.pressed.connect(func(): go("menu"))
	h.add_child(back)
	var t := Palette.vbox(1)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(t)
	t.add_child(Palette.label("CONSOLE DOCENTE · DATI LOCALI", 12, Palette.MUTED))
	t.add_child(Palette.title("Panoramica della classe", 26))
	h.add_child(Palette.chip(GameState.current_nickname(), Palette.YELLOW, Palette.INK))
	var export_btn := Palette.button("ESPORTA", Palette.TEAL, 15)
	export_btn.custom_minimum_size = Vector2(140, 50)
	export_btn.pressed.connect(_export)
	h.add_child(export_btn)

	# left summary
	var left := PanelContainer.new()
	left.add_theme_stylebox_override("panel", Palette.style(Color(0.06, 0.10, 0.17, 0.95), 20, Color(1, 1, 1, 0.10), 1))
	left.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	left.offset_left = 36
	left.offset_right = 460
	left.offset_top = 124
	left.offset_bottom = -24
	_root.add_child(left)
	var lscroll := Palette.scroll()
	left.add_child(lscroll)
	var lb := Palette.vbox(10)
	lb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lscroll.add_child(lb)

	var all_ids: Array = []
	for w in MissionRepository.worlds():
		all_ids.append_array(w.get("mission_ids", []))
	var done: int = GameState.completed_count(all_ids)
	lb.add_child(Palette.label("PROFILO ATTIVO", 12, Palette.MUTED))
	lb.add_child(Palette.title(GameState.current_nickname(), 24))
	lb.add_child(Palette.label("%d missioni completate su %d · %d%%" % [done, all_ids.size(), int(100.0 * float(done) / maxf(1.0, all_ids.size()))], 14, Palette.CREAM, true))
	var total_bar := Palette.progress_bar(float(done) / maxf(1.0, all_ids.size()), Palette.TEAL)
	total_bar.custom_minimum_size = Vector2(0, 16)
	lb.add_child(total_bar)
	lb.add_child(Palette.spacer(4))
	lb.add_child(Palette.label("PER MONDO", 12, Palette.MUTED))
	for w in MissionRepository.worlds():
		var ids: Array = w.get("mission_ids", [])
		var wd: int = GameState.completed_count(ids)
		var row := Palette.vbox(2)
		var rh := Palette.hbox(6)
		rh.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var name_l := Palette.label(str(w.get("code", "")) + " · " + str(w.get("title", "")), 13, Palette.CREAM)
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rh.add_child(name_l)
		rh.add_child(Palette.label("%d/%d" % [wd, ids.size()], 12, Palette.MUTED))
		row.add_child(rh)
		row.add_child(Palette.progress_bar(float(wd) / maxf(1.0, ids.size()), Palette.GREEN))
		lb.add_child(row)

	lb.add_child(Palette.spacer(8))
	lb.add_child(Palette.label("PREFERENZE CLASSE", 12, Palette.MUTED))
	lb.add_child(_switch("Mondi sempre accessibili", "free_worlds"))
	lb.add_child(_switch("Suggerisci la soluzione", "show_solution"))
	lb.add_child(_switch("Modalità classe", "classroom_mode"))
	lb.add_child(_switch("Controlli grandi", "large_controls"))

	lb.add_child(Palette.spacer(4))
	lb.add_child(Palette.label("PIN DOCENTE (facoltativo)", 12, Palette.MUTED))
	var pin_row := Palette.hbox(6)
	lb.add_child(pin_row)
	_new_pin = LineEdit.new()
	_new_pin.placeholder_text = "Nuovo PIN"
	_new_pin.custom_minimum_size = Vector2(0, 46)
	_new_pin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_new_pin.add_theme_font_size_override("font_size", 15)
	pin_row.add_child(_new_pin)
	var pin_btn := Palette.ghost_button("SALVA", 13)
	pin_btn.custom_minimum_size = Vector2(96, 46)
	pin_btn.pressed.connect(_save_pin)
	pin_row.add_child(pin_btn)
	lb.add_child(Palette.label("Il PIN non cifra i dati: è un blocco cortese per la lavagna condivisa.", 11, Palette.MUTED, true))

	var reset := Palette.ghost_button("AZZERA PROGRESSI PROFILO", 13)
	reset.custom_minimum_size = Vector2(0, 48)
	reset.add_theme_color_override("font_color", Palette.CORAL)
	reset.pressed.connect(func(): _confirm.popup_centered())
	lb.add_child(reset)

	_notice = Palette.label("", 12, Palette.MUTED, true)
	lb.add_child(_notice)

	# right table
	var right := PanelContainer.new()
	right.add_theme_stylebox_override("panel", Palette.style(Color(0.06, 0.10, 0.17, 0.95), 20, Color(1, 1, 1, 0.10), 1))
	right.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	right.offset_left = 476
	right.offset_right = -36
	right.offset_top = 124
	right.offset_bottom = -24
	_root.add_child(right)
	var rv := Palette.vbox(8)
	right.add_child(rv)
	var rh := Palette.hbox(8)
	rh.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rv.add_child(rh)
	rh.add_child(Palette.label("EVIDENZE PER MISSIONE", 13, Palette.MUTED))
	var grow := Control.new()
	grow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rh.add_child(grow)
	rh.add_child(Palette.label("stato · tentativi · passi migliori · aiuti", 12, Palette.MUTED))

	var scroll := Palette.scroll()
	rv.add_child(scroll)
	var table := Palette.vbox(3)
	table.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(table)

	for w in MissionRepository.worlds():
		var header := Palette.hbox(8)
		header.mouse_filter = Control.MOUSE_FILTER_IGNORE
		header.add_child(Palette.chip(str(w.get("code", "")), Palette.PURPLE))
		header.add_child(Palette.label(str(w.get("title", "")), 15, Palette.CREAM))
		table.add_child(header)
		for m in MissionRepository.world_missions(str(w.get("id", ""))):
			table.add_child(_mission_row(m))

	_confirm = ConfirmationDialog.new()
	_confirm.title = "Azzerare i progressi?"
	_confirm.dialog_text = "Verranno cancellati progressi, creazioni e badge del profilo attivo."
	_confirm.confirmed.connect(func():
		GameState.reset_progress()
		_notice.text = "Progressi azzerati."
		_notice.add_theme_color_override("font_color", Palette.YELLOW)
		_root.queue_free()
		_build_content())
	add_child(_confirm)

	lb.add_child(Palette.spacer(4))
	lb.add_child(Palette.label("Nota: il gioco non richiede account e non invia dati. L'esportazione è un file JSON locale da consegnare al docente.", 11, Palette.MUTED, true))


func _switch(label: String, key: String) -> HBoxContainer:
	var row := Palette.hbox(8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := Palette.label(label, 13, Palette.CREAM)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	var toggle := CheckButton.new()
	toggle.button_pressed = bool(GameState.get_setting(key, false))
	toggle.custom_minimum_size = Vector2(66, 44)
	toggle.toggled.connect(func(on: bool):
		GameState.set_setting(key, on)
		if key == "classroom_mode" and on:
			GameState.set_setting("large_controls", true)
			GameState.set_setting("subtitles", true))
	row.add_child(toggle)
	return row


func _mission_row(m: Dictionary) -> PanelContainer:
	var id := str(m.get("id", ""))
	var pr: Dictionary = GameState.progress_for(id)
	var complete := bool(pr.get("completed", false))
	var attempts := int(pr.get("attempts", 0))
	var best := int(pr.get("best_steps", 0))
	var hints := int(pr.get("hints", 0))
	var row := PanelContainer.new()
	row.add_theme_stylebox_override("panel", Palette.style(Color(1, 1, 1, 0.035) if attempts == 0 else (Color(0.10, 0.24, 0.18, 0.6) if complete else Color(0.28, 0.18, 0.14, 0.6)), 8))
	var h := Palette.hbox(8)
	row.add_child(h)
	var id_l := Palette.label(id, 12, Palette.MUTED)
	id_l.custom_minimum_size = Vector2(56, 0)
	h.add_child(id_l)
	var title := Palette.label(str(m.get("title", "")), 13, Palette.CREAM)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.max_lines_visible = 1
	h.add_child(title)
	var state := "✓" if complete else ("in corso" if attempts > 0 else "—")
	h.add_child(Palette.label(state, 12, Palette.GREEN if complete else (Palette.YELLOW if attempts > 0 else Palette.MUTED)))
	h.add_child(Palette.label("%dt" % attempts, 12, Palette.MUTED))
	h.add_child(Palette.label("%dp" % best if best > 0 else "—", 12, Palette.MUTED))
	h.add_child(Palette.label("%da" % hints, 12, Palette.MUTED))
	return row


func _save_pin() -> void:
	var pin := _new_pin.text.strip_edges()
	GameState.set_setting("teacher_pin", pin)
	_new_pin.text = ""
	_notice.text = "PIN salvato." if pin != "" else "PIN rimosso."
	_notice.add_theme_color_override("font_color", Palette.GREEN)


func _export() -> void:
	var path: String = GameState.export_progress()
	if path.is_empty():
		_notice.text = "Esportazione non riuscita."
		_notice.add_theme_color_override("font_color", Palette.CORAL)
		return
	var abs_path := ProjectSettings.globalize_path(path)
	DisplayServer.clipboard_set(abs_path)
	_notice.text = "Esportato: " + abs_path
	_notice.add_theme_color_override("font_color", Palette.GREEN)
	OS.shell_open(ProjectSettings.globalize_path("user://exports"))
