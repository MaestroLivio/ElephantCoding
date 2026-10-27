extends AppScreen

## World map: nine worlds in curriculum order, with progress and soft locks
## (disabled only when the teacher turns free exploration off).

const WORLD_TINT := {
	"INF": Palette.TEAL,
	"P1": Palette.GREEN,
	"P2": Palette.YELLOW,
	"P3": Palette.BLUE,
	"P4": Palette.CORAL,
	"P5": Palette.PURPLE,
	"S1": Palette.TEAL,
	"S2": Palette.PURPLE,
	"S3": Palette.CORAL,
}

var worlds: Array = []


func build() -> void:
	_build_ui()


func _build_ui() -> void:
	worlds = MissionRepository.worlds()

	# A quiet gradient keeps the nine cards readable; this screen is a menu, not
	# a 3D scene.
	var gradient := Gradient.new()
	gradient.set_color(0, Color("#12233a"))
	gradient.set_color(1, Color("#1b3450"))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.3)
	texture.fill_to = Vector2(1.05, 1.0)
	texture.width = 256
	texture.height = 256
	var backdrop := TextureRect.new()
	backdrop.texture = texture
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_SCALE
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)

	var header := PanelContainer.new()
	header.add_theme_stylebox_override("panel", Palette.style(Color(0.06, 0.10, 0.17, 0.94), 20, Color(1, 1, 1, 0.10), 1))
	header.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	header.offset_left = 36
	header.offset_right = -36
	header.offset_top = 28
	header.offset_bottom = 132
	add_child(header)

	var h := Palette.hbox(16)
	header.add_child(h)
	var back := Palette.ghost_button("← MENU", 17)
	back.custom_minimum_size = Vector2(132, 56)
	back.pressed.connect(func(): go("menu"))
	h.add_child(back)

	var titles := Palette.vbox(2)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(titles)
	titles.add_child(Palette.title("SCEGLI UN MONDO", 28))
	titles.add_child(Palette.label("Nove tappe, dalla prima sequenza ai sistemi complessi. Ogni mondo dura circa dieci missioni.", 14, Palette.MUTED, true))

	var all_ids: Array = []
	for w in worlds:
		all_ids.append_array(w.get("mission_ids", []))
	var done: int = GameState.completed_count(all_ids)
	h.add_child(Palette.chip("%d / %d missioni" % [done, all_ids.size()], Palette.CARD_LIGHT))

	var profile := Palette.chip(GameState.current_nickname(), Palette.YELLOW, Palette.INK)
	h.add_child(profile)

	var scroll := Palette.scroll()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 36
	scroll.offset_right = -36
	scroll.offset_top = 152
	scroll.offset_bottom = -28
	add_child(scroll)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_right", 14)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(margin)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 18)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(grid)

	for i in range(worlds.size()):
		var idx := i
		var world: Dictionary = worlds[i]
		grid.add_child(_world_card(world, idx))


func _world_card(world: Dictionary, index: int) -> PanelContainer:
	var code := str(world.get("code", "?"))
	var tint: Color = WORLD_TINT.get(code, Palette.TEAL)
	var ids: Array = world.get("mission_ids", [])
	var done: int = GameState.completed_count(ids)
	var complete: bool = done >= ids.size() and ids.size() > 0
	var unlocked := _is_unlocked(index)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 236)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", Palette.style(Color(0.09, 0.15, 0.24, 0.96) if unlocked else Color(0.07, 0.09, 0.13, 0.96), 20, tint if unlocked else Color(1, 1, 1, 0.08), 2))
	var box := Palette.vbox(8)
	card.add_child(box)

	var top := Palette.hbox(8)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(top)
	top.add_child(Palette.chip(code, tint, Palette.INK))
	top.add_child(Palette.chip(str(world.get("age", "")), Palette.CARD_LIGHT, Palette.CREAM))
	var grow := Control.new()
	grow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(grow)
	if complete:
		top.add_child(Palette.chip("COMPLETATO", Palette.GREEN, Palette.INK))
	elif not unlocked:
		top.add_child(Palette.chip("BLOCCATO", Palette.CARD_LIGHT, Palette.MUTED))
	else:
		top.add_child(Palette.chip("%d/%d" % [done, ids.size()], Palette.CARD_LIGHT))

	var title := Palette.label(str(world.get("title", code)), 23, Palette.CREAM if unlocked else Palette.MUTED, true)
	title.custom_minimum_size = Vector2(0, 58)
	box.add_child(title)
	box.add_child(Palette.label(str(world.get("language", "")), 14, tint if unlocked else Palette.MUTED))
	box.add_child(Palette.label(str(world.get("description", "")), 14, Palette.MUTED, true))

	var bar_row := Palette.hbox(8)
	bar_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(bar_row)
	var bar := Palette.progress_bar(float(done) / maxf(1.0, float(ids.size())), tint)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.custom_minimum_size = Vector2(0, 12)
	bar_row.add_child(bar)
	bar_row.add_child(Palette.label("%d/%d" % [done, ids.size()], 13, Palette.MUTED))

	var enter := Palette.button("ENTRA NEL MONDO" if unlocked else "COMPLETA IL MONDO PRECEDENTE", tint if unlocked else Palette.CARD_LIGHT, 16)
	enter.custom_minimum_size = Vector2(0, 48)
	enter.disabled = not unlocked
	enter.pressed.connect(func():
		if unlocked:
			go("hub", {"world_id": world.get("id", "")}))
	box.add_child(enter)
	return card


func _is_unlocked(index: int) -> bool:
	if bool(GameState.get_setting("free_worlds", true)):
		return true
	if index <= 0:
		return true
	var prev: Dictionary = worlds[index - 1]
	var ids: Array = prev.get("mission_ids", [])
	return GameState.completed_count(ids) >= ids.size()
