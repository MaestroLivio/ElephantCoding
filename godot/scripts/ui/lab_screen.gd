extends AppScreen

## Officina dei robot: a free sandbox that shares the same deterministic
## simulator as the missions. Teachers can use it for live demonstrations.

var mission: Dictionary = {}
var builder: WorldBuilder
var rig: CameraRig
var sim: CodingSimulator
var playback: Playback
var editor: ProgramEditor
var result: Dictionary = {}
var _status: Label
var _camera_mode := 0
var _preset := "prato"
var _touch_area: Control
var _run_btn: Button


func build() -> void:
	_build_mission()
	_build_stage()
	_build_ui()
	editor.set_mission(mission)
	Narration.speak("officina", "Benvenuto nell'officina dei robot. Scrivi un programma libero: Nilo lo eseguirà sulla griglia.", 7.0)


func _build_mission() -> void:
	var obstacles: Array = []
	var entities: Array = []
	var theme := {"sky": "#16263d", "ground": "#2f6d63", "accent": "#ffd166", "prop": "gear"}
	match _preset:
		"labirinto":
			obstacles = [[2, 1], [2, 2], [2, 3], [4, 3], [4, 4], [4, 5], [6, 1], [6, 2]]
			theme = {"sky": "#1b2a41", "ground": "#4a4e69", "accent": "#4cc9f0", "prop": "house"}
		"giardino":
			entities = [
				{"id": "lab-mela", "kind": "collect", "cell": [2, 2], "label": "Mela", "glyph": "*"},
				{"id": "lab-fiore", "kind": "collect", "cell": [4, 1], "label": "Fiore", "glyph": "*"},
				{"id": "lab-foto", "kind": "photo", "cell": [6, 4], "label": "Reperto", "glyph": "o"},
			]
			theme = {"sky": "#bde0fe", "ground": "#6bbf59", "accent": "#ffd166", "prop": "tree"}
		_:
			theme = {"sky": "#16263d", "ground": "#2f6d63", "accent": "#ffd166", "prop": "gear"}
	mission = {
		"schema_version": 1,
		"id": "LAB",
		"world": "officina",
		"title": "Officina dei robot",
		"editor": "text",
		"grid": {"min_x": 0, "min_y": 0, "max_x": 8, "max_y": 6},
		"spawn": {"cell": [0, 3], "heading": "E"},
		"obstacles": obstacles,
		"entities": entities,
		"initial_vars": {},
		"sensors": {},
		"goal": {},
		"scene_theme": theme,
		"reference_program": "",
		"starter_program": "",
		"hints": [],
	}


func _build_stage() -> void:
	builder = WorldBuilder.new()
	var out := builder.build_mission(mission)
	use_stage(out.root)
	rig = CameraRig.new()
	out.root.add_child(rig)
	rig.fov = 32.0
	rig.safe_rect = Rect2(0.379, 0.111, 0.392, 0.778)
	rig.setup_for_bounds(out.get("bounds", Rect2(-5, -4, 10, 8)), builder.nilo)
	rig.mode = _camera_mode
	rig.current = true


func _rebuild_stage() -> void:
	_build_stage()


func _build_ui() -> void:
	_touch_area = Control.new()
	_touch_area.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_touch_area.mouse_filter = Control.MOUSE_FILTER_STOP
	_touch_area.gui_input.connect(_on_stage_touch)
	add_child(_touch_area)

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
	var back := Palette.ghost_button("← MENU", 16)
	back.custom_minimum_size = Vector2(128, 50)
	back.pressed.connect(func(): go("menu"))
	h.add_child(back)
	var titles := Palette.vbox(0)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(titles)
	titles.add_child(Palette.label("OFFICINA DEI ROBOT · SANDBOX", 12, Palette.MUTED))
	titles.add_child(Palette.title("Programma libero", 24))

	h.add_child(Palette.chip("SANDBOX", Palette.CARD_LIGHT))
	var preset_prato := Palette.ghost_button("PRATO", 13)
	preset_prato.custom_minimum_size = Vector2(94, 46)
	preset_prato.pressed.connect(func(): _set_preset("prato"))
	h.add_child(preset_prato)
	var preset_lab := Palette.ghost_button("LABIRINTO", 13)
	preset_lab.custom_minimum_size = Vector2(112, 46)
	preset_lab.pressed.connect(func(): _set_preset("labirinto"))
	h.add_child(preset_lab)
	var preset_garden := Palette.ghost_button("GIARDINO", 13)
	preset_garden.custom_minimum_size = Vector2(106, 46)
	preset_garden.pressed.connect(func(): _set_preset("giardino"))
	h.add_child(preset_garden)

	var cam := Palette.ghost_button("VISTA", 14)
	cam.custom_minimum_size = Vector2(96, 46)
	cam.pressed.connect(func():
		if rig != null:
			_camera_mode = rig.cycle_mode()
			toast("Vista: " + rig.cycle_name(), 1.4))
	h.add_child(cam)

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
	head.add_child(Palette.label("PROGRAMMA LIBERO", 13, Palette.MUTED))
	var grow := Control.new()
	grow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(grow)
	head.add_child(Palette.label("TESTO", 12, Palette.PURPLE))

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
	var reset := Palette.ghost_button("PULISCI", 15)
	reset.custom_minimum_size = Vector2(120, 62)
	reset.pressed.connect(_on_reset)
	actions.add_child(reset)

	_status = Palette.label("Scrivi un programma e premi ESEGUI.", 14, Palette.MUTED, true)
	_status.custom_minimum_size = Vector2(0, 40)
	box.add_child(_status)

	# right panel with the command recap
	var right := PanelContainer.new()
	right.add_theme_stylebox_override("panel", Palette.style(Color(0.06, 0.10, 0.17, 0.92), 20, Color(1, 1, 1, 0.10), 1))
	right.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	right.offset_left = -366
	right.offset_right = -24
	right.offset_top = 100
	right.offset_bottom = -24
	add_child(right)
	var rscroll := Palette.scroll()
	right.add_child(rscroll)
	var rb := Palette.vbox(8)
	rb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rscroll.add_child(rb)
	rb.add_child(Palette.title("PROMEMORIA", 20))
	rb.add_child(Palette.label("Tocca un comando nell'editor per inserirlo. La sintassi è italiana e tollerante a maiuscole e spazi.", 13, Palette.MUTED, true))
	var commands := [
		["AVANTI 2", "due passi nella direzione del muso"],
		["DESTRA / SINISTRA", "gira di 90 gradi"],
		["RIPETI x3 { … }", "ripete il blocco"],
		["VAI A (4,2)", "raggiunge coordinate"],
		["MUOVI X +3", "spostamento su un asse"],
		["IMPOSTA x = 0", "crea o aggiorna una variabile"],
		["SE … ALLORA { } ALTRIMENTI { }", "scelta condizionale"],
		["FINCHÉ condizione { }", "ciclo con condizione"],
		["PER i DA 0 A 4 { }", "ciclo numerico"],
		["PER OGNI p IN lista { }", "ciclo su lista"],
		["PROCEDURA nome() { }", "sottoprogramma riutilizzabile"],
		["FUNZIONE f(a) { RITORNA a }", "funzione con valore"],
		["RACCOGLI / ATTIVA / FOTO", "azioni sul campo"],
		["TRACCIA (x,y) / CHIUDI", "disegna e chiudi una figura"],
	]
	for c in commands:
		var row := PanelContainer.new()
		row.add_theme_stylebox_override("panel", Palette.style(Color(1, 1, 1, 0.05), 10))
		var rv := Palette.vbox(2)
		row.add_child(rv)
		rv.add_child(Palette.label(str(c[0]), 14, Palette.YELLOW))
		rv.add_child(Palette.label(str(c[1]), 12, Palette.MUTED, true))
		rb.add_child(row)
	rb.add_child(Palette.spacer(4))
	rb.add_child(Palette.label("IDEE", 13, Palette.MUTED))
	rb.add_child(Palette.label("Disegna un quadrato con TRACCIA, riempi una riga di oggetti con RIPETI, oppure costruisci una procedura che accende tutte le porte.", 13, Palette.CREAM, true))

	playback = Playback.new()
	playback.speed = 3.0
	playback.finished.connect(_on_finished)
	playback.state_changed.connect(_on_playback_state)
	add_child(playback)


func _set_preset(name: String) -> void:
	_preset = name
	_build_mission()
	result = {}
	_build_stage()
	editor.set_mission(mission)
	_status.text = "Preset «%s» caricato." % name
	_status.add_theme_color_override("font_color", Palette.MUTED)


func _on_run() -> void:
	if playback != null and playback.playing:
		playback.pause()
		return
	var source := editor.get_source()
	if source.strip_edges().is_empty():
		toast("Scrivi almeno un comando.", 2.6, Palette.YELLOW)
		return
	editor.clear_error()
	result = {}
	_build_stage()
	playback.reset()
	sim = CodingSimulator.new()
	sim.setup(mission)
	result = sim.run(source)
	if not result.parse_error.is_empty():
		var line := int(result.parse_error.get("line", 0))
		editor.show_error_line(line, str(result.parse_error.get("message", "")))
		_status.text = "Errore di sintassi alla riga %d." % line
		_status.add_theme_color_override("font_color", Palette.CORAL)
		return
	playback.load_events(result.get("events", []), builder)
	playback.play()
	_status.text = "Esecuzione in corso…"
	_status.add_theme_color_override("font_color", Palette.CREAM)


func _on_reset() -> void:
	result = {}
	if playback != null:
		playback.reset()
	_build_stage()
	editor.clear_error()
	_status.text = "Area pulita. Scrivi un nuovo programma."
	_status.add_theme_color_override("font_color", Palette.MUTED)


func _on_finished() -> void:
	if result.is_empty():
		return
	if bool(result.get("success", false)) or str(result.get("error", "")) == "":
		_status.text = "Esecuzione conclusa senza errori. Prova a cambiare preset!"
		_status.add_theme_color_override("font_color", Palette.GREEN)
		GameState.add_creation({"type": "lab", "preset": _preset, "source": editor.get_source(), "at": Time.get_datetime_string_from_system(true)})
	else:
		_status.text = str(result.get("failure_reason", "Errore di esecuzione."))
		_status.add_theme_color_override("font_color", Palette.CORAL)


func _on_playback_state(playing: bool, index: int, total: int) -> void:
	if _run_btn == null:
		return
	if playing:
		_run_btn.text = "PAUSA"
	elif total > 0 and index >= total:
		_run_btn.text = "RIPETI"
	else:
		_run_btn.text = "ESEGUI"


func _on_stage_touch(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and rig != null:
			rig.zoom_by(0.92)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and rig != null:
			rig.zoom_by(1.08)
