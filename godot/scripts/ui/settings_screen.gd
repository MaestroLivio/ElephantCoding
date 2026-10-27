extends AppScreen

## Accessible settings: voice, subtitles, motion, camera, classroom defaults.
## Everything is stored locally with the profile.

var _dialog: FileDialog
var _confirm: ConfirmationDialog
var _toast_line: Label


func build() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Palette.BG
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	var bar := PanelContainer.new()
	bar.add_theme_stylebox_override("panel", Palette.style(Color(0.06, 0.10, 0.17, 0.96), 18, Color(1, 1, 1, 0.10), 1))
	bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	bar.offset_left = 36
	bar.offset_right = -36
	bar.offset_top = 24
	bar.offset_bottom = 108
	add_child(bar)
	var h := Palette.hbox(14)
	bar.add_child(h)
	var back := Palette.ghost_button("← MENU", 16)
	back.custom_minimum_size = Vector2(130, 54)
	back.pressed.connect(func(): go("menu"))
	h.add_child(back)
	var t := Palette.vbox(1)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(t)
	t.add_child(Palette.label("PREFERENZE LOCALI · NESSUN ACCOUNT", 12, Palette.MUTED))
	t.add_child(Palette.title("Impostazioni", 27))
	h.add_child(Palette.chip(GameState.current_nickname(), Palette.YELLOW, Palette.INK))

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Palette.style(Palette.CARD, 22, Color(1, 1, 1, 0.10), 1))
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -460
	panel.offset_right = 460
	panel.offset_top = -350
	panel.offset_bottom = 366
	add_child(panel)
	var scroll := Palette.scroll()
	panel.add_child(scroll)
	var box := Palette.vbox(12)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)

	box.add_child(_section("VOCE E SOTTOTITOLI"))
	box.add_child(_toggle_row("Voce narrante", "voice", "Riproduce la voce registrata o la sintesi del sistema."))
	box.add_child(_toggle_row("Sottotitoli sempre visibili", "subtitles", "Utile in aule rumorose e per chi preferisce leggere."))
	box.add_child(_toggle_row("Sintesi vocale di riserva", "tts_fallback", "Se manca un clip audio, usa la voce italiana del dispositivo."))
	box.add_child(_volume_row())

	box.add_child(_section("ACCESSIBILITÀ"))
	box.add_child(_toggle_row("Controlli grandi", "large_controls", "Testi e pulsanti più grandi per touch screen e kiosk."))
	box.add_child(_toggle_row("Riduci animazioni", "reduce_motion", "Esecuzione istantanea e meno movimento."))
	box.add_child(_toggle_row("Contrasto rinforzato", "high_contrast", "Aumenta il contrasto di testi e superfici."))
	box.add_child(_camera_row())
	box.add_child(_toggle_row("Suggerisci la soluzione", "show_solution", "Mostra il pulsante Soluzione nelle missioni (per docenti)."))

	box.add_child(_section("CLASSE E PERCORSO"))
	box.add_child(_toggle_row("Modalità classe", "classroom_mode", "Interfaccia semplificata per la lavagna interattiva."))
	box.add_child(_toggle_row("Mondi sempre accessibili", "free_worlds", "Se disattivato, i mondi si sbloccano in ordine."))
	box.add_child(_toggle_row("Comandi touch", "touch_controls", "Mostra joystick e pulsanti camera nelle scene 3D."))

	box.add_child(_section("DATI DEL PROFILO"))
	var data_row := Palette.hbox(10)
	box.add_child(data_row)
	var export_btn := Palette.button("ESPORTA PROGRESSI", Palette.TEAL, 15)
	export_btn.custom_minimum_size = Vector2(0, 50)
	export_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	export_btn.pressed.connect(_export)
	data_row.add_child(export_btn)
	var import_btn := Palette.ghost_button("IMPORTA", 15)
	import_btn.custom_minimum_size = Vector2(150, 50)
	import_btn.pressed.connect(func(): _dialog.popup_centered(Vector2i(760, 560)))
	data_row.add_child(import_btn)
	var reset_btn := Palette.ghost_button("AZZERA", 15)
	reset_btn.custom_minimum_size = Vector2(140, 50)
	reset_btn.add_theme_color_override("font_color", Palette.CORAL)
	reset_btn.pressed.connect(func(): _confirm.popup_centered())
	data_row.add_child(reset_btn)

	_toast_line = Palette.label("", 13, Palette.MUTED)
	box.add_child(_toast_line)
	box.add_child(Palette.label("Licenza dell'app: CC BY 4.0. Vedi Crediti e licenze per le note di terze parti.", 12, Palette.MUTED, true))
	box.add_child(Palette.spacer(10))

	_dialog = FileDialog.new()
	_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_dialog.filters = PackedStringArray(["*.json ; Profili ElephantCoding"])
	_dialog.title = "Importa un profilo"
	_dialog.file_selected.connect(_import)
	add_child(_dialog)

	_confirm = ConfirmationDialog.new()
	_confirm.title = "Azzerare i progressi?"
	_confirm.dialog_text = "Verranno cancellati progressi, creazioni e badge del profilo attivo. L'operazione non si può annullare."
	_confirm.confirmed.connect(func():
		GameState.reset_progress()
		_toast_line.text = "Progressi azzerati per " + GameState.current_nickname() + "."
		_toast_line.add_theme_color_override("font_color", Palette.YELLOW))
	add_child(_confirm)


func _section(text: String) -> Control:
	var box := Palette.vbox(2)
	var l := Palette.label(text, 13, Palette.YELLOW)
	box.add_child(l)
	var line := ColorRect.new()
	line.color = Color(1, 1, 1, 0.10)
	line.custom_minimum_size = Vector2(0, 1)
	box.add_child(line)
	return box


func _toggle_row(title: String, key: String, hint: String) -> PanelContainer:
	var row := PanelContainer.new()
	row.add_theme_stylebox_override("panel", Palette.style(Color(1, 1, 1, 0.045), 12))
	var h := Palette.hbox(12)
	row.add_child(h)
	var v := Palette.vbox(2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(v)
	v.add_child(Palette.label(title, 17, Palette.CREAM))
	v.add_child(Palette.label(hint, 12, Palette.MUTED, true))
	var toggle := CheckButton.new()
	toggle.button_pressed = bool(GameState.get_setting(key, false))
	toggle.custom_minimum_size = Vector2(74, 52)
	toggle.focus_mode = Control.FOCUS_ALL
	toggle.toggled.connect(func(on: bool):
		GameState.set_setting(key, on)
		if key == "classroom_mode" and on:
			GameState.set_setting("large_controls", true)
			GameState.set_setting("subtitles", true))
	h.add_child(toggle)
	return row


func _volume_row() -> PanelContainer:
	var row := PanelContainer.new()
	row.add_theme_stylebox_override("panel", Palette.style(Color(1, 1, 1, 0.045), 12))
	var h := Palette.hbox(12)
	row.add_child(h)
	var label := Palette.label("Volume", 17, Palette.CREAM)
	label.custom_minimum_size = Vector2(160, 0)
	h.add_child(label)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = float(GameState.get_setting("volume", 0.9))
	slider.custom_minimum_size = Vector2(0, 44)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var value_label := Palette.label("%d%%" % int(slider.value * 100.0), 14, Palette.MUTED)
	value_label.custom_minimum_size = Vector2(56, 0)
	slider.value_changed.connect(func(v: float):
		GameState.set_setting("volume", v)
		value_label.text = "%d%%" % int(v * 100.0))
	h.add_child(slider)
	h.add_child(value_label)
	return row


func _camera_row() -> PanelContainer:
	var row := PanelContainer.new()
	row.add_theme_stylebox_override("panel", Palette.style(Color(1, 1, 1, 0.045), 12))
	var h := Palette.hbox(12)
	row.add_child(h)
	var v := Palette.vbox(2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(v)
	v.add_child(Palette.label("Vista 3D predefinita", 17, Palette.CREAM))
	v.add_child(Palette.label("Le tre viste richieste dal progetto: campo fisso, inseguimento, prima persona.", 12, Palette.MUTED, true))
	var option := OptionButton.new()
	option.add_item("Campo fisso", 0)
	option.add_item("Inseguimento", 1)
	option.add_item("Prima persona", 2)
	option.custom_minimum_size = Vector2(220, 50)
	var current := str(GameState.get_setting("camera_mode", "fixed"))
	option.select(maxi(0, ["fixed", "chase", "first"].find(current)))
	option.item_selected.connect(func(index: int):
		GameState.set_setting("camera_mode", ["fixed", "chase", "first"][index]))
	h.add_child(option)
	return row


func _export() -> void:
	var path: String = GameState.export_progress()
	if path.is_empty():
		_toast_line.text = "Esportazione non riuscita."
		_toast_line.add_theme_color_override("font_color", Palette.CORAL)
		return
	var abs_path := ProjectSettings.globalize_path(path)
	_toast_line.text = "Esportato in: " + abs_path
	_toast_line.add_theme_color_override("font_color", Palette.GREEN)
	DisplayServer.clipboard_set(abs_path)
	OS.shell_open(ProjectSettings.globalize_path("user://exports"))


func _import(path: String) -> void:
	if GameState.import_progress(path):
		_toast_line.text = "Profilo importato: " + path.get_file()
		_toast_line.add_theme_color_override("font_color", Palette.GREEN)
	else:
		_toast_line.text = "File non valido o profili pieni."
		_toast_line.add_theme_color_override("font_color", Palette.CORAL)
