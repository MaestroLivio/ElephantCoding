extends AppScreen

## Title screen: a procedural 3D diorama behind a large, touch-first menu.

var builder: WorldBuilder
var _cam: Camera3D
var _angle := 0.5
var _menu_cam_active := true
var _modal: Control


func build() -> void:
	_build_stage()
	_build_ui()
	Narration.speak("benvenuto", "Ciao! Sono Nilo. Insieme impareremo a programmare viaggiando per nove mondi.", 7.0)


func _build_stage() -> void:
	builder = WorldBuilder.new()
	var out := builder.build_menu_stage()
	_cam = out.get("camera")
	use_stage(out.root)
	if _cam != null:
		_cam.current = true
		_place_camera()


func _place_camera() -> void:
	if _cam == null:
		return
	var r := 17.5
	_cam.position = Vector3(sin(_angle) * r, 7.2, cos(_angle) * r)
	_cam.look_at(Vector3(0, 1.1, 0))
	_cam.fov = 40.0
	# The menu panel covers the left half of the screen; shift the diorama into
	# the free right-hand area instead of hiding it behind the panel.
	_cam.h_offset = -5.1


func _process(delta: float) -> void:
	if _menu_cam_active and _cam != null:
		_angle += delta * 0.045
		_place_camera()


func _build_ui() -> void:
	var left := PanelContainer.new()
	left.add_theme_stylebox_override("panel", Palette.style(Color(0.06, 0.10, 0.17, 0.90), 26, Color(1, 1, 1, 0.10), 1))
	left.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	left.offset_left = 54
	left.offset_top = 54
	left.offset_right = 754
	left.offset_bottom = -54
	add_child(left)

	var box := Palette.vbox(14)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	left.add_child(box)

	var kicker := Palette.hbox(10)
	kicker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(kicker)
	kicker.add_child(Palette.chip("GIOCO EDUCATIVO", Palette.TEAL, Palette.INK))
	kicker.add_child(Palette.chip("90 MISSIONI", Palette.YELLOW, Palette.INK))
	kicker.add_child(Palette.chip("9 MONDI", Palette.PURPLE))

	var title := Palette.title("ELEPHANT\nCODING", 62)
	title.add_theme_constant_override("line_spacing", -6)
	box.add_child(title)

	var sub := Palette.label("Nilo l'elefantino che programma", 25, Palette.YELLOW)
	box.add_child(sub)
	box.add_child(Palette.label("Coding, matematica e pensiero computazionale per la scuola primaria e secondaria. Comandi grandi, voce, sottotitoli e percorsi senza barriere.", 17, Palette.MUTED, true))
	box.add_child(Palette.spacer(6))

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	box.add_child(grid)

	var play := Palette.button("GIOCA", Palette.CORAL, 24)
	play.custom_minimum_size = Vector2(0, 70)
	play.pressed.connect(func(): go("worlds"))
	grid.add_child(play)

	var lab := Palette.button("OFFICINA", Palette.TEAL, 20)
	lab.custom_minimum_size = Vector2(0, 70)
	lab.pressed.connect(func(): go("lab"))
	grid.add_child(lab)

	var teacher := Palette.ghost_button("AREA INSEGNANTE", 18)
	teacher.custom_minimum_size = Vector2(0, 56)
	teacher.pressed.connect(func(): go("teacher"))
	grid.add_child(teacher)

	var settings := Palette.ghost_button("IMPOSTAZIONI", 18)
	settings.custom_minimum_size = Vector2(0, 56)
	settings.pressed.connect(func(): go("settings"))
	grid.add_child(settings)

	box.add_child(Palette.spacer(2))

	var footer := Palette.hbox(10)
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(footer)
	var credits := Palette.ghost_button("CREDITI E LICENZE", 15)
	credits.custom_minimum_size = Vector2(0, 44)
	credits.pressed.connect(func(): go("credits"))
	footer.add_child(credits)
	var quit := Palette.ghost_button("ESCI", 15)
	quit.custom_minimum_size = Vector2(110, 44)
	quit.pressed.connect(func(): get_tree().quit())
	footer.add_child(quit)
	var grow := Control.new()
	grow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	footer.add_child(grow)
	footer.add_child(Palette.label("v0.1.1 · CC BY 4.0", 13, Palette.MUTED))

	# top-right profile card
	var profile := PanelContainer.new()
	profile.add_theme_stylebox_override("panel", Palette.style(Color(0.06, 0.10, 0.17, 0.88), 18, Color(1, 1, 1, 0.12), 1))
	profile.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	profile.offset_left = -430
	profile.offset_right = -54
	profile.offset_top = 54
	profile.offset_bottom = 168
	add_child(profile)
	var ph := Palette.hbox(12)
	profile.add_child(ph)
	var avatar := PanelContainer.new()
	avatar.add_theme_stylebox_override("panel", Palette.style(Palette.YELLOW, 999))
	avatar.custom_minimum_size = Vector2(58, 58)
	ph.add_child(avatar)
	var av := Palette.label("N", 30, Palette.INK)
	av.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	av.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	avatar.add_child(av)
	var info := Palette.vbox(2)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ph.add_child(info)
	info.add_child(Palette.label("PROFILO", 12, Palette.MUTED))
	info.add_child(Palette.label(GameState.current_nickname(), 21, Palette.CREAM))
	var total := MissionRepository.total_missions()
	var done: int = GameState.completed_count(MissionRepository.mission_ids("giardino") + MissionRepository.mission_ids("officina") + MissionRepository.mission_ids("borgo") + MissionRepository.mission_ids("isola") + MissionRepository.mission_ids("centro") + MissionRepository.mission_ids("cittadella") + MissionRepository.mission_ids("arcipelago") + MissionRepository.mission_ids("metropoli") + MissionRepository.mission_ids("savana"))
	info.add_child(Palette.label("%d / %d missioni" % [done, total], 13, Palette.MUTED))
	var swap := Palette.ghost_button("CAMBIA", 14)
	swap.custom_minimum_size = Vector2(0, 44)
	swap.pressed.connect(_open_profiles)
	ph.add_child(swap)

	var tip := PanelContainer.new()
	tip.add_theme_stylebox_override("panel", Palette.style(Color(0.06, 0.10, 0.17, 0.72), 18))
	tip.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	tip.offset_left = -430
	tip.offset_right = -54
	tip.offset_bottom = -54
	tip.offset_top = -128
	add_child(tip)
	tip.add_child(Palette.label("Suggerimento: usa un dito per trascinare la vista e due dita per lo zoom. Tutto funziona anche con mouse e tastiera.", 14, Palette.MUTED, true))


# ---------------------------------------------------------------------------
# Profiles
# ---------------------------------------------------------------------------
func _open_profiles() -> void:
	if _modal != null:
		_modal.queue_free()
	_modal = Control.new()
	_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_modal)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_modal.add_child(dim)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Palette.style(Palette.CARD, 24, Palette.PURPLE, 2))
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -400
	panel.offset_right = 400
	panel.offset_top = -300
	panel.offset_bottom = 300
	_modal.add_child(panel)

	var box := Palette.vbox(14)
	panel.add_child(box)
	box.add_child(Palette.title("CHI STA GIOCANDO?", 30))
	box.add_child(Palette.label("I profili restano su questo dispositivo. Nessun account, nessun dato inviato in rete.", 14, Palette.MUTED, true))

	var list := Palette.vbox(8)
	box.add_child(list)
	for i in range(GameState.profiles.size()):
		var p: Dictionary = GameState.profiles[i]
		var idx := i
		var row := PanelContainer.new()
		row.add_theme_stylebox_override("panel", Palette.style(Palette.CARD_LIGHT if i != GameState.active_index else Color("#2a5b57"), 12))
		list.add_child(row)
		var h := Palette.hbox(10)
		row.add_child(h)
		var name_l := Palette.label(str(p.get("nickname", "Profilo")), 18, Palette.CREAM)
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(name_l)
		var n_done := int(p.get("progress", {}).size())
		h.add_child(Palette.label("%d missioni" % n_done, 13, Palette.MUTED))
		if i != GameState.active_index:
			var use := Palette.button("USA", Palette.TEAL, 15)
			use.custom_minimum_size = Vector2(90, 46)
			use.pressed.connect(func():
				GameState.select_profile(idx)
				_refresh_profiles())
			h.add_child(use)
		else:
			h.add_child(Palette.chip("ATTIVO", Palette.TEAL, Palette.INK))
		if GameState.profiles.size() > 1:
			var del := Palette.ghost_button("ELIMINA", 13)
			del.custom_minimum_size = Vector2(0, 42)
			del.pressed.connect(func():
				if GameState.delete_profile(idx):
					_refresh_profiles())
			h.add_child(del)

	box.add_child(Palette.spacer(4))
	var new_row := Palette.hbox(8)
	box.add_child(new_row)
	var name_edit := LineEdit.new()
	name_edit.placeholder_text = "Nome del nuovo profilo"
	name_edit.custom_minimum_size = Vector2(0, 52)
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_edit.add_theme_font_size_override("font_size", 18)
	new_row.add_child(name_edit)
	var create := Palette.button("CREA PROFILO", Palette.YELLOW, 16)
	create.custom_minimum_size = Vector2(180, 52)
	create.pressed.connect(func():
		if GameState.new_profile(name_edit.text):
			_refresh_profiles()
		else:
			toast("Hai raggiunto il limite di 8 profili.", 3.0, Palette.CORAL))
	new_row.add_child(create)

	var close := Palette.button("CHIUDI", Palette.CORAL, 17)
	close.custom_minimum_size = Vector2(0, 54)
	close.pressed.connect(func():
		_modal.queue_free()
		_modal = null
		go("menu"))
	box.add_child(close)


func _refresh_profiles() -> void:
	if _modal != null:
		_modal.queue_free()
		_modal = null
	_open_profiles()
