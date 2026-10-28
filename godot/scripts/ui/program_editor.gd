class_name ProgramEditor
extends VBoxContainer

## Dual editor: a touch-first block/bead editor and a text editor for the
## Italian DSL. Both produce plain DSL source; the deterministic simulator is
## the only component that decides whether a program works.

signal source_changed(source: String)
signal run_requested
signal step_requested
signal reset_requested

const CONTAINERS := ["RIPETI", "SE", "FINCHÉ", "PER"]

var mission: Dictionary = {}
var mode := "text"
var current_tab := "blocks"

var blocks: Array = []
var _target: Array = []
var _target_name := "programma"
var _text_source := ""
var _ignore := false

var _tabs: HBoxContainer
var _blocks_tab: Button
var _text_tab: Button
var _stack: Control
var _block_scroll: ScrollContainer
var _block_list: VBoxContainer
var _palette: HFlowContainer
var _text_panel: VBoxContainer
var _code: CodeEdit
var _hint: Label
var _target_bar: HBoxContainer
var _target_label: Label
var _root_btn: Button
var _error_line := 0
var _graphic := false


func _ready() -> void:
	add_theme_constant_override("separation", 10)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_target = blocks
	_build_chrome()


func _build_chrome() -> void:
	var head := Palette.hbox(8)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(head)

	_tabs = Palette.hbox(6)
	_tabs.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(_tabs)
	_blocks_tab = Palette.button("BLOCCHI", Palette.PURPLE, 16)
	_blocks_tab.custom_minimum_size = Vector2(132, 44)
	_blocks_tab.pressed.connect(func(): _switch_tab("blocks"))
	_tabs.add_child(_blocks_tab)
	_text_tab = Palette.button("TESTO", Palette.CARD_LIGHT, 16)
	_text_tab.custom_minimum_size = Vector2(132, 44)
	_text_tab.pressed.connect(func(): _switch_tab("text"))
	_tabs.add_child(_text_tab)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(spacer)

	_hint = Palette.label("", 14, Palette.MUTED)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	head.add_child(_hint)

	_stack = Control.new()
	_stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stack)

	# --- block editor -----------------------------------------------------
	var block_box := Palette.vbox(8)
	block_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	block_box.mouse_filter = Control.MOUSE_FILTER_PASS
	_stack.add_child(block_box)

	_target_bar = Palette.hbox(8)
	_target_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	block_box.add_child(_target_bar)
	_target_label = Palette.label("Sto aggiungendo a: programma", 15, Palette.MUTED)
	_target_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_target_bar.add_child(_target_label)
	_root_btn = Palette.icon_button("chevron_up", "", Palette.CARD_LIGHT, 14, Vector2(48, 40), 18)
	_root_btn.tooltip_text = "Torna al programma principale"
	_root_btn.pressed.connect(func():
		_target = blocks
		_target_name = "programma"
		_rebuild())
	_target_bar.add_child(_root_btn)

	_block_scroll = Palette.scroll()
	block_box.add_child(_block_scroll)
	_block_list = Palette.vbox(8)
	_block_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_block_scroll.add_child(_block_list)

	_palette = HFlowContainer.new()
	_palette.add_theme_constant_override("h_separation", 8)
	_palette.add_theme_constant_override("v_separation", 8)
	block_box.add_child(_palette)

	# --- text editor ------------------------------------------------------
	_text_panel = Palette.vbox(8)
	_text_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_text_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	_text_panel.visible = false
	_stack.add_child(_text_panel)

	_code = CodeEdit.new()
	_code.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_code.custom_minimum_size = Vector2(0, 260)
	_code.placeholder_text = "Scrivi qui il programma di Nilo…\nEsempio: AVANTI 2\nDESTRA\nRIPETI x3 { AVANTI 1; FOTO }"
	_code.add_theme_font_size_override("font_size", 20)
	_code.add_theme_color_override("font_color", Palette.CREAM)
	_code.add_theme_color_override("background_color", Color("#0c1626"))
	_code.add_theme_color_override("current_line_color", Color(1, 1, 1, 0.06))
	_code.add_theme_color_override("line_number_color", Palette.MUTED)
	_code.add_theme_constant_override("line_spacing", 6)
	_code.gutters_draw_line_numbers = true
	_code.highlight_current_line = true
	_code.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_code.indent_size = 2
	_code.text_changed.connect(_on_text_changed)
	_text_panel.add_child(_code)

	var text_palette := FlowContainer.new()
	text_palette.add_theme_constant_override("h_separation", 8)
	text_palette.add_theme_constant_override("v_separation", 8)
	_text_panel.add_child(text_palette)
	_fill_text_palette(text_palette)

	_rebuild_palette()
	_rebuild()


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------
func set_mission(p_mission: Dictionary) -> void:
	mission = p_mission
	mode = str(mission.get("editor", "text"))
	_graphic = mode in ["icons", "beads"]
	current_tab = "blocks" if _graphic else "text"
	blocks = []
	_target = blocks
	_target_name = "programma"
	var starter := str(mission.get("starter_program", ""))
	_text_source = starter
	if _code != null:
		_code.text = starter
	_apply_mode_visibility()
	_rebuild_palette()
	_rebuild()
	_switch_tab(current_tab)


func _apply_mode_visibility() -> void:
	if _tabs != null:
		_tabs.visible = not _graphic
	if _hint != null:
		_hint.add_theme_font_size_override("font_size", 13 if _graphic else 14)


func is_graphic() -> bool:
	return _graphic


func get_source() -> String:
	if current_tab == "text":
		return _code.text if _code != null else _text_source
	return _serialize(blocks, 0)


func set_source(text: String, sync_text_tab := true) -> void:
	_text_source = text
	if _code != null and sync_text_tab:
		_ignore = true
		_code.text = text
		_ignore = false
	source_changed.emit(get_source())


func show_error_line(line: int, message := "") -> void:
	_error_line = line
	if line > 0 and _code != null:
		_code.set_line_background_color(line - 1, Color(0.94, 0.28, 0.43, 0.28))
		_code.set_caret_line(line - 1)
		_code.set_caret_column(0)
		_code.grab_focus()
	if message != "":
		_hint.text = message
		_hint.add_theme_color_override("font_color", Palette.CORAL)


func clear_error() -> void:
	if _code != null:
		for i in range(_code.get_line_count()):
			_code.set_line_background_color(i, Color.TRANSPARENT)
	_error_line = 0
	_hint.text = ""
	_hint.add_theme_color_override("font_color", Palette.MUTED)


func mark_success() -> void:
	clear_error()
	_hint.text = "Programma eseguito"
	_hint.add_theme_color_override("font_color", Palette.GREEN)


# ---------------------------------------------------------------------------
# Tabs
# ---------------------------------------------------------------------------
func _switch_tab(tab: String) -> void:
	current_tab = tab
	if _block_scroll != null:
		_block_scroll.get_parent().visible = tab == "blocks"
	if _text_panel != null:
		_text_panel.visible = tab == "text"
	_blocks_tab.add_theme_stylebox_override("normal", Palette.style(Palette.PURPLE if tab == "blocks" else Palette.CARD_LIGHT, 14))
	_text_tab.add_theme_stylebox_override("normal", Palette.style(Palette.PURPLE if tab == "text" else Palette.CARD_LIGHT, 14))
	if tab == "text" and _code != null:
		_code.grab_focus()


func _on_text_changed() -> void:
	if _ignore:
		return
	_text_source = _code.text
	source_changed.emit(_text_source)


# ---------------------------------------------------------------------------
# Block model
# ---------------------------------------------------------------------------
func _rebuild_palette() -> void:
	if _palette == null:
		return
	for c in _palette.get_children():
		c.queue_free()
	var entries := _palette_entries()
	for e in entries:
		var b: Button
		if _graphic:
			b = _graphic_tile(e)
		else:
			b = Palette.button(str(e.label), e.get("color", Palette.CARD_LIGHT), 15)
			b.custom_minimum_size = Vector2(0, 44)
		b.pressed.connect(func(): _add_block(str(e.op)))
		_palette.add_child(b)


func _palette_entries() -> Array:
	if _graphic:
		return _graphic_entries()
	# Reading order of the three movement commands: left, forward, right.
	var simple := [
		{"label": "SINISTRA", "op": "SINISTRA", "color": Palette.BLUE},
		{"label": "AVANTI", "op": "AVANTI", "color": Palette.TEAL},
		{"label": "DESTRA", "op": "DESTRA", "color": Palette.BLUE},
	]
	var actions := [
		{"label": "RACCOGLI", "op": "RACCOGLI", "color": Palette.YELLOW},
		{"label": "ATTIVA", "op": "ATTIVA", "color": Palette.CORAL},
		{"label": "FOTO", "op": "FOTO", "color": Palette.PURPLE},
	]
	var structured := [
		{"label": "RIPETI x…", "op": "RIPETI", "color": Palette.GREEN},
		{"label": "SE … ALLORA", "op": "SE", "color": Palette.GREEN},
		{"label": "FINCHÉ …", "op": "FINCHÉ", "color": Palette.GREEN},
	]
	var extra := [
		{"label": "VAI A (x,y)", "op": "VAI A", "color": Palette.CORAL},
		{"label": "IMPOSTA variabile", "op": "IMPOSTA", "color": Palette.PURPLE},
		{"label": "PER i DA a A", "op": "PER", "color": Palette.GREEN},
		{"label": "ASPETTA", "op": "ASPETTA", "color": Palette.MUTED},
	]
	if mode == "coordinates":
		return simple + extra.slice(0, 1) + structured
	return simple + actions + structured + extra


## Pictorial commands. The first worlds only see the commands they actually
## need, so the tray stays short and every tile fits on a touch screen.
func _graphic_entries() -> Array:
	var all := [
		{"label": "SINISTRA", "op": "SINISTRA", "icon": "left", "color": Palette.BLUE},
		{"label": "AVANTI", "op": "AVANTI", "icon": "forward", "color": Palette.TEAL},
		{"label": "DESTRA", "op": "DESTRA", "icon": "right", "color": Palette.BLUE},
		{"label": "RACCOGLI", "op": "RACCOGLI", "icon": "collect", "color": Palette.YELLOW},
		{"label": "PRENDI", "op": "PRENDI", "icon": "prendi", "color": Palette.YELLOW},
		{"label": "DEPOSITA", "op": "DEPOSITA", "icon": "deposita", "color": Palette.YELLOW},
		{"label": "TOCCA", "op": "TOCCA", "icon": "tocca", "color": Palette.CORAL},
		{"label": "ATTIVA", "op": "ATTIVA", "icon": "attiva", "color": Palette.CORAL},
		{"label": "ACCENDI", "op": "ACCENDI", "icon": "accendi", "color": Palette.CORAL},
		{"label": "APRI", "op": "APRI", "icon": "apri", "color": Palette.PURPLE},
		{"label": "FOTO", "op": "FOTO", "icon": "foto", "color": Palette.PURPLE},
		{"label": "SUONA", "op": "SUONA", "icon": "suona", "color": Palette.PURPLE},
		{"label": "PAUSA", "op": "PAUSA", "icon": "pausa", "color": Palette.MUTED},
		{"label": "RIPETI", "op": "RIPETI", "icon": "ripeti", "color": Palette.GREEN},
	]
	var level := str(mission.get("id", "")).get_slice("-", 0)
	if level == "INF":
		var keep := ["AVANTI", "DESTRA", "SINISTRA", "RACCOGLI", "TOCCA", "SUONA", "PAUSA", "RIPETI"]
		return all.filter(func(e): return keep.has(str(e.op)))
	return all


func _graphic_tile(entry: Dictionary) -> Button:
	var tint: Color = entry.get("color", Palette.CARD_LIGHT)
	var b := Button.new()
	b.custom_minimum_size = Vector2(88, 84)
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = str(entry.get("label", entry.get("op", "")))
	b.add_theme_stylebox_override("normal", _tile_style(tint.darkened(0.66), tint, 2))
	b.add_theme_stylebox_override("hover", _tile_style(tint.darkened(0.54), Palette.CREAM, 2))
	b.add_theme_stylebox_override("pressed", _tile_style(tint.darkened(0.74), tint, 2))
	b.add_theme_stylebox_override("focus", _tile_style(tint.darkened(0.54), Palette.CREAM, 2))

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 2)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(box)
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 4
	box.offset_right = -4
	box.offset_top = 4
	box.offset_bottom = -4

	var glyph := GameIcon.new(str(entry.get("icon", "•")), 40.0, tint.lightened(0.22))
	glyph.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(glyph)
	var caption := Palette.label(str(entry.get("label", "")), 10, Palette.CREAM)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(caption)
	return b


func _tile_style(bg: Color, border: Color, border_width: int) -> StyleBoxFlat:
	var s := Palette.style(bg, 16, border, border_width)
	s.content_margin_left = 4
	s.content_margin_right = 4
	s.content_margin_top = 4
	s.content_margin_bottom = 4
	s.shadow_size = 0
	return s


func _add_block(op: String) -> void:
	var b := {"op": op}
	match op:
		"AVANTI":
			b["n"] = 1
		"RIPETI":
			b["n"] = 3
			b["body"] = []
		"SE":
			b["cond"] = "acqua >= 2"
			b["body"] = []
			b["else_body"] = []
		"FINCHÉ":
			b["cond"] = "acqua < 5"
			b["body"] = []
		"PER":
			b["var_name"] = "i"
			b["from"] = "0"
			b["to"] = "3"
			b["body"] = []
		"VAI A":
			b["x"] = 0
			b["y"] = 0
		"IMPOSTA":
			b["var_name"] = "casse"
			b["expr"] = "0"
		"ASPETTA":
			b["n"] = 1
	_target.append(b)
	if op == "RIPETI" or op == "FINCHÉ" or op == "PER":
		_target = b.body
		_target_name = "ciclo"
	elif op == "SE":
		_target = b.body
		_target_name = "allora"
	_model_changed()
	_rebuild()


func _model_changed() -> void:
	clear_error()
	source_changed.emit(get_source())


func _remove_block(arr: Array, block: Dictionary) -> void:
	for i in range(arr.size()):
		if is_same(arr[i], block):
			arr.remove_at(i)
			return
		var child: Dictionary = arr[i]
		for key in ["body", "else_body"]:
			if child.get(key) is Array:
				_remove_block(child[key], block)


func _move_block(arr: Array, block: Dictionary, delta: int) -> bool:
	for i in range(arr.size()):
		if is_same(arr[i], block):
			var j := i + delta
			if j < 0 or j >= arr.size():
				return false
			var tmp = arr[i]
			arr[i] = arr[j]
			arr[j] = tmp
			return true
		var child: Dictionary = arr[i]
		for key in ["body", "else_body"]:
			if child.get(key) is Array:
				if _move_block(child[key], block, delta):
					return true
	return false


func _rebuild() -> void:
	if _block_list == null:
		return
	_ignore = true
	for c in _block_list.get_children():
		c.queue_free()
	if blocks.is_empty():
		if _graphic:
			var empty_box := Palette.vbox(10)
			empty_box.alignment = BoxContainer.ALIGNMENT_CENTER
			empty_box.custom_minimum_size = Vector2(0, 120)
			var hint_icon := GameIcon.new("chevron_down", 42, Palette.MUTED)
			hint_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			empty_box.add_child(hint_icon)
			var empty := Palette.label("Tocca un comando qui sotto", 15, Palette.MUTED, true)
			empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			empty_box.add_child(empty)
			_block_list.add_child(empty_box)
		else:
			var empty := Palette.label("Il programma è vuoto. Tocca un comando qui sotto per iniziare.", 16, Palette.MUTED, true)
			empty.custom_minimum_size = Vector2(0, 70)
			_block_list.add_child(empty)
	else:
		_render_into(blocks, _block_list, 0)
	if not _graphic:
		_block_list.add_child(_tail_button(blocks, "fine programma"))
	_ignore = false
	if _target_label != null:
		_target_label.text = ("Dentro " if _graphic else "Sto aggiungendo a: ") + _target_name
	if _target_bar != null:
		_target_bar.visible = not _graphic or not is_same(_target, blocks)
	# The tray is rebuilt only when the mission changes: recreating the tiles on
	# every edit left the old buttons alive until the end of the frame, so a
	# quick second tap could hit a dying tile and append the command twice.


func _render_into(arr: Array, parent: VBoxContainer, depth: int) -> void:
	for block in arr:
		parent.add_child(_row(block, arr, depth))
		if block.get("body") is Array:
			var label := "corpo"
			if block.op == "SE":
				label = "allora"
			parent.add_child(_body_panel(block.body, label, arr, depth + 1))
		if block.get("else_body") is Array:
			parent.add_child(_body_panel(block.else_body, "altrimenti", arr, depth + 1))


func _body_panel(body: Array, label: String, parent_arr: Array, depth: int) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := Palette.style(Color(1, 1, 1, 0.05), 12)
	style.content_margin_left = 12
	style.content_margin_right = 8
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	style.shadow_size = 0
	var selected := is_same(_target, body)
	if selected:
		style.border_width_left = 4
		style.border_color = Palette.TEAL
	panel.add_theme_stylebox_override("panel", style)

	var box := Palette.vbox(6)
	panel.add_child(box)
	var header := Palette.hbox(6)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(header)
	var tag := Palette.label(label.to_upper(), 12, Palette.TEAL if selected else Palette.MUTED)
	header.add_child(tag)
	var grow := Control.new()
	grow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(grow)
	var add_btn: Button
	if _graphic:
		add_btn = Palette.icon_button("plus", "", Palette.CARD_LIGHT, 12, Vector2(40, 34), 16)
		add_btn.tooltip_text = "Aggiungi qui"
	else:
		add_btn = Palette.ghost_button("+ AGGIUNGI QUI", 12)
		add_btn.custom_minimum_size = Vector2(0, 34)
	add_btn.pressed.connect(func():
		_target = body
		_target_name = label
		_rebuild())
	header.add_child(add_btn)
	if body.is_empty():
		var empty := Palette.label("(vuoto)", 13, Palette.MUTED)
		empty.custom_minimum_size = Vector2(0, 22)
		box.add_child(empty)
	else:
		var inner := Palette.vbox(6)
		box.add_child(inner)
		_render_into(body, inner, depth)
	# Re-rendering nested containers needs the recursive tail too.
	box.add_child(_tail_button(body, label))
	return panel


func _tail_button(_arr: Array, label: String) -> Control:
	if _graphic:
		var gap := Control.new()
		gap.custom_minimum_size = Vector2(0, 2)
		gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return gap
	var row := Palette.hbox(6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var line := ColorRect.new()
	line.color = Color(1, 1, 1, 0.06)
	line.custom_minimum_size = Vector2(2, 20)
	row.add_child(line)
	var l := Palette.label("aggiungi " + label, 11, Palette.MUTED)
	row.add_child(l)
	return row


func _row(block: Dictionary, arr: Array, depth: int) -> PanelContainer:
	var op := str(block.get("op", "?"))
	var tint := Palette.CARD_LIGHT
	match op:
		"AVANTI": tint = Color("#1b4d52")
		"DESTRA", "SINISTRA": tint = Color("#1b3b62")
		"RACCOGLI", "PRENDI", "DEPOSITA", "TOCCA", "ATTIVA", "ACCENDI", "FOTO": tint = Color("#4a3a1c")
		"RIPETI", "SE", "FINCHÉ", "PER": tint = Color("#24462f")
		"VAI A", "MUOVI": tint = Color("#4a2c2c")
		"APRI", "SUONA", "PAUSA", "IMPOSTA": tint = Color("#382b55")
	var panel := PanelContainer.new()
	var style := Palette.style(tint, 12)
	style.shadow_size = 0
	style.content_margin_left = 10
	style.content_margin_right = 8
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(0, 52 if not _graphic else 56)

	var h := Palette.hbox(8)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(h)

	if _graphic:
		var glyph_icon := GameIcon.new(_icon_for(op), 28.0, Palette.CREAM)
		h.add_child(glyph_icon)
	else:
		var glyph := Palette.label(_glyph(op), 20, Palette.CREAM)
		glyph.custom_minimum_size = Vector2(28, 0)
		glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		h.add_child(glyph)

	var title := Palette.label(_title(op), 13 if _graphic else 16, Palette.CREAM)
	title.custom_minimum_size = Vector2(0 if _graphic else 82, 0)
	h.add_child(title)

	match op:
		"AVANTI", "ASPETTA", "RIPETI":
			if _graphic:
				h.add_child(_stepper(block, "n", 0 if op == "ASPETTA" else 1))
			else:
				var spin := SpinBox.new()
				spin.min_value = 0 if op == "ASPETTA" else 1
				spin.max_value = 50
				spin.value = int(block.get("n", 1))
				spin.custom_minimum_size = Vector2(88, 40)
				spin.value_changed.connect(func(v: float):
					block["n"] = int(v)
					_model_changed())
				h.add_child(spin)
			h.add_child(Palette.label("passi" if op == "AVANTI" else "volte", 13 if not _graphic else 11, Palette.MUTED))
		"VAI A":
			var sx := SpinBox.new()
			sx.min_value = -20
			sx.max_value = 40
			sx.value = int(block.get("x", 0))
			sx.custom_minimum_size = Vector2(80, 40)
			sx.value_changed.connect(func(v: float):
				block["x"] = int(v)
				_model_changed())
			h.add_child(sx)
			h.add_child(Palette.label(",", 16, Palette.MUTED))
			var sy := SpinBox.new()
			sy.min_value = -20
			sy.max_value = 40
			sy.value = int(block.get("y", 0))
			sy.custom_minimum_size = Vector2(80, 40)
			sy.value_changed.connect(func(v: float):
				block["y"] = int(v)
				_model_changed())
			h.add_child(sy)
		"SE", "FINCHÉ":
			var cond := LineEdit.new()
			cond.text = str(block.get("cond", ""))
			cond.custom_minimum_size = Vector2(0, 40)
			cond.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			cond.add_theme_font_size_override("font_size", 15)
			cond.text_changed.connect(func(t: String):
				block["cond"] = t
				_model_changed())
			h.add_child(cond)
		"IMPOSTA":
			var name_edit := LineEdit.new()
			name_edit.text = str(block.get("var_name", "x"))
			name_edit.custom_minimum_size = Vector2(86, 40)
			name_edit.add_theme_font_size_override("font_size", 15)
			name_edit.text_changed.connect(func(t: String):
				block["var_name"] = t
				_model_changed())
			h.add_child(name_edit)
			h.add_child(Palette.label("=", 16, Palette.MUTED))
			var expr := LineEdit.new()
			expr.text = str(block.get("expr", "0"))
			expr.custom_minimum_size = Vector2(0, 40)
			expr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			expr.add_theme_font_size_override("font_size", 15)
			expr.text_changed.connect(func(t: String):
				block["expr"] = t
				_model_changed())
			h.add_child(expr)
		"PER":
			var v := LineEdit.new()
			v.text = str(block.get("var_name", "i"))
			v.custom_minimum_size = Vector2(58, 40)
			v.add_theme_font_size_override("font_size", 15)
			v.text_changed.connect(func(t: String):
				block["var_name"] = t
				_model_changed())
			h.add_child(v)
			h.add_child(Palette.label("da", 13, Palette.MUTED))
			var f := LineEdit.new()
			f.text = str(block.get("from", "0"))
			f.custom_minimum_size = Vector2(48, 40)
			f.text_changed.connect(func(t: String):
				block["from"] = t
				_model_changed())
			h.add_child(f)
			h.add_child(Palette.label("a", 13, Palette.MUTED))
			var t2 := LineEdit.new()
			t2.text = str(block.get("to", "3"))
			t2.custom_minimum_size = Vector2(48, 40)
			t2.text_changed.connect(func(t: String):
				block["to"] = t
				_model_changed())
			h.add_child(t2)

	var grow := Control.new()
	grow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(grow)

	var up := _mini("↑")
	up.pressed.connect(func():
		if _move_block(blocks, block, -1):
			_model_changed()
			_rebuild())
	h.add_child(up)
	var down := _mini("↓")
	down.pressed.connect(func():
		if _move_block(blocks, block, 1):
			_model_changed()
			_rebuild())
	h.add_child(down)
	var del := _mini("✕")
	del.add_theme_color_override("font_color", Palette.CORAL)
	del.pressed.connect(func():
		_remove_block(blocks, block)
		_model_changed()
		_rebuild())
	h.add_child(del)
	return panel


## Graphic counter used by the first worlds: − number +, no keyboard or spinner.
func _stepper(block: Dictionary, key: String, min_value: int) -> HBoxContainer:
	var value := int(block.get(key, 1))
	var row := Palette.hbox(2)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var minus := _mini("−")
	minus.custom_minimum_size = Vector2(34, 34)
	minus.disabled = value <= min_value
	minus.pressed.connect(func():
		if int(block.get(key, 1)) > min_value:
			block[key] = int(block.get(key, 1)) - 1
			_model_changed()
			_rebuild())
	row.add_child(minus)
	var number := Palette.label(str(value), 18, Palette.CREAM)
	number.custom_minimum_size = Vector2(34, 0)
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(number)
	var plus := _mini("+")
	plus.custom_minimum_size = Vector2(34, 34)
	plus.pressed.connect(func():
		block[key] = mini(50, int(block.get(key, 1)) + 1)
		_model_changed()
		_rebuild())
	row.add_child(plus)
	return row


func _icon_for(op: String) -> String:
	match op:
		"AVANTI": return "forward"
		"DESTRA": return "right"
		"SINISTRA": return "left"
		"RACCOGLI": return "collect"
		"PRENDI": return "prendi"
		"DEPOSITA": return "deposita"
		"TOCCA": return "tocca"
		"ATTIVA": return "attiva"
		"ACCENDI": return "accendi"
		"APRI": return "apri"
		"FOTO": return "foto"
		"SUONA": return "suona"
		"PAUSA": return "pausa"
		"RIPETI": return "ripeti"
		"SE": return "target"
		"FINCHÉ": return "ripeti"
		"PER": return "ripeti"
		"VAI A": return "target"
		"IMPOSTA": return "code"
		"ASPETTA": return "pausa"
		_: return "forward"


func _mini(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(40, 40)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 18)
	b.add_theme_color_override("font_color", Palette.CREAM)
	b.add_theme_stylebox_override("normal", Palette.style(Color(1, 1, 1, 0.07), 10))
	b.add_theme_stylebox_override("pressed", Palette.style(Color(1, 1, 1, 0.16), 10))
	return b


func _title(op: String) -> String:
	match op:
		"VAI A": return "VAI A"
		"IMPOSTA": return "IMPOSTA"
		"FINCHÉ": return "FINCHÉ"
		"ASPETTA": return "ASPETTA"
		"RIPETI": return "RIPETI"
		"SE": return "SE"
		"PER": return "PER"
		"PRENDI": return "PRENDI"
		"DEPOSITA": return "DEPOSITA"
		"TOCCA": return "TOCCA"
		"ACCENDI": return "ACCENDI"
		"APRI": return "APRI"
		"SUONA": return "SUONA"
		"PAUSA": return "PAUSA"
		_: return op


func _glyph(op: String) -> String:
	match op:
		"AVANTI": return "↑"
		"DESTRA": return "↻"
		"SINISTRA": return "↺"
		"RACCOGLI": return "★"
		"PRENDI": return "↓"
		"DEPOSITA": return "↑"
		"TOCCA": return "◎"
		"ATTIVA": return "!"
		"ACCENDI": return "☀"
		"APRI": return "▯"
		"FOTO": return "◉"
		"SUONA": return "♪"
		"PAUSA": return "❚❚"
		"RIPETI": return "↻"
		"SE": return "?"
		"FINCHÉ": return "∞"
		"PER": return "∀"
		"VAI A": return "◎"
		"IMPOSTA": return "="
		"ASPETTA": return "…"
		_: return "•"


# ---------------------------------------------------------------------------
# Serialisation
# ---------------------------------------------------------------------------
func _serialize(arr: Array, depth: int) -> String:
	var pad := "\t".repeat(depth)
	var lines: Array = []
	for block in arr:
		var op := str(block.get("op", ""))
		match op:
			"AVANTI":
				var n := int(block.get("n", 1))
				lines.append(pad + ("AVANTI" if n <= 1 else "AVANTI %d" % n))
			"DESTRA", "SINISTRA", "RACCOGLI", "PRENDI", "DEPOSITA", "ATTIVA", "FOTO", "APRI", "ACCENDI", "TOCCA", "SUONA", "PAUSA", "SALUTA":
				lines.append(pad + op)
			"ASPETTA":
				lines.append(pad + "ASPETTA %d" % int(block.get("n", 1)))
			"VAI A":
				lines.append(pad + "VAI A (%d,%d)" % [int(block.get("x", 0)), int(block.get("y", 0))])
			"IMPOSTA":
				lines.append(pad + "IMPOSTA %s = %s" % [str(block.get("var_name", "x")), str(block.get("expr", "0"))])
			"RIPETI":
				var count := maxi(1, int(block.get("n", 1)))
				lines.append(pad + "RIPETI x%d {" % count)
				lines.append(_serialize(block.get("body", []), depth + 1))
				lines.append(pad + "}")
			"SE":
				lines.append(pad + "SE %s ALLORA {" % str(block.get("cond", "VERO")))
				lines.append(_serialize(block.get("body", []), depth + 1))
				lines.append(pad + "} ALTRIMENTI {")
				lines.append(_serialize(block.get("else_body", []), depth + 1))
				lines.append(pad + "}")
			"FINCHÉ":
				lines.append(pad + "FINCHÉ %s {" % str(block.get("cond", "VERO")))
				lines.append(_serialize(block.get("body", []), depth + 1))
				lines.append(pad + "}")
			"PER":
				lines.append(pad + "PER %s DA %s A %s {" % [str(block.get("var_name", "i")), str(block.get("from", "0")), str(block.get("to", "3"))])
				lines.append(_serialize(block.get("body", []), depth + 1))
				lines.append(pad + "}")
	var out := "\n".join(lines)
	return out.strip_edges(false, true)


# ---------------------------------------------------------------------------
# Text snippets
# ---------------------------------------------------------------------------
func _fill_text_palette(palette: FlowContainer) -> void:
	var snippets := [
		{"label": "SINISTRA", "text": "SINISTRA\n"},
		{"label": "AVANTI", "text": "AVANTI "},
		{"label": "DESTRA", "text": "DESTRA\n"},
		{"label": "RIPETI x3", "text": "RIPETI x3 {\n\t\n}\n"},
		{"label": "SE … ALLORA", "text": "SE \nALLORA {\n\t\n}\n"},
		{"label": "FINCHÉ", "text": "FINCHÉ  {\n\t\n}\n"},
		{"label": "VAI A", "text": "VAI A (0,0)\n"},
		{"label": "IMPOSTA", "text": "IMPOSTA x = 0\n"},
		{"label": "PER OGNI", "text": "PER OGNI punto IN elenco {\n\tVAI A punto\n}\n"},
		{"label": "PROCEDURA", "text": "PROCEDURA nome() {\n\t\n}\n"},
		{"label": "RACCOGLI", "text": "RACCOGLI\n"},
		{"label": "ATTIVA", "text": "ATTIVA\n"},
		{"label": "FOTO", "text": "FOTO\n"},
	]
	for s in snippets:
		var b := Palette.ghost_button(str(s.label), 14)
		b.custom_minimum_size = Vector2(0, 38)
		b.pressed.connect(func(): _insert_snippet(str(s.text)))
		palette.add_child(b)


func _insert_snippet(text: String) -> void:
	if _code == null:
		return
	if _code.has_selection():
		_code.delete_selection()
	_code.insert_text_at_caret(text)
	_code.grab_focus()
	_on_text_changed()
