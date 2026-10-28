extends AppScreen

## World hub: Nilo walks on a procedural plaza, portals are mission doors and
## the bottom strip always offers a large touch target for every mission.

var world: Dictionary = {}
var missions: Array = []
var builder: WorldBuilder
var rig: CameraRig
var _joystick: TouchJoystick
var _touch_area: Control
var _press_position := Vector2.ZERO
var _camera_label: Label


func build() -> void:
	var world_id := str(args.get("world_id", "giardino"))
	world = MissionRepository.world(world_id)
	if world.is_empty():
		var all := MissionRepository.worlds()
		if not all.is_empty():
			world = all[0]
	missions = MissionRepository.world_missions(str(world.get("id", "")))
	if missions.is_empty():
		missions = MissionRepository.missions().slice(0, 10)
	_build_stage()
	_build_ui()
	if not mission_ids().is_empty():
		Narration.speak("mondo_" + str(world.get("id", "")), str(world.get("title", "")) + ". " + str(world.get("description", "")), 8.0)


func mission_ids() -> Array:
	var out: Array = []
	for m in missions:
		out.append(str(m.get("id", "")))
	return out


func _build_stage() -> void:
	builder = WorldBuilder.new()
	var out := builder.build_hub(world, missions)
	use_stage(out.root)
	rig = CameraRig.new()
	rig.name = "CameraRig"
	out.root.add_child(rig)
	rig.fov = 32.0
	rig.safe_rect = Rect2(0.05, 0.14, 0.90, 0.63)
	rig.setup_for_bounds(out.get("bounds", Rect2(-8, -5.5, 16, 11)), builder.nilo)
	rig.current = true
	rig.set_mode(CameraRig.Mode.FIXED)


func _set_camera_mode(name: String) -> void:
	if rig == null:
		return
	var index := ["fixed", "chase", "first"].find(name)
	if index < 0:
		index = 0
	rig.set_mode(index)


func _build_ui() -> void:
	_touch_area = Control.new()
	_touch_area.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_touch_area.mouse_filter = Control.MOUSE_FILTER_STOP
	_touch_area.gui_input.connect(_on_stage_input)
	add_child(_touch_area)

	var header := PanelContainer.new()
	header.add_theme_stylebox_override("panel", Palette.style(Color(0.06, 0.10, 0.17, 0.94), 20, Color(1, 1, 1, 0.10), 1))
	header.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	header.offset_left = 36
	header.offset_right = -36
	header.offset_top = 24
	header.offset_bottom = 118
	add_child(header)

	var h := Palette.hbox(14)
	header.add_child(h)
	var back := Palette.ghost_button("← MONDI", 17)
	back.custom_minimum_size = Vector2(130, 54)
	back.pressed.connect(func(): go("worlds"))
	h.add_child(back)

	var titles := Palette.vbox(1)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(titles)
	titles.add_child(Palette.title(str(world.get("title", "Mondo")), 26))
	titles.add_child(Palette.label(str(world.get("language", "")) + " · " + str(world.get("age", "")), 14, WORLD_TINT()))

	var ids := mission_ids()
	var done: int = GameState.completed_count(ids)
	h.add_child(Palette.chip("%d / %d" % [done, ids.size()], Palette.CARD_LIGHT))
	if done >= ids.size() and ids.size() > 0:
		h.add_child(Palette.chip("MONDO COMPLETO", Palette.GREEN, Palette.INK))

	var camera_btn := Palette.ghost_button("VISTA", 15)
	camera_btn.custom_minimum_size = Vector2(120, 50)
	camera_btn.pressed.connect(_cycle_camera)
	h.add_child(camera_btn)

	var recenter := Palette.ghost_button("CENTRA", 15)
	recenter.custom_minimum_size = Vector2(110, 50)
	recenter.pressed.connect(func():
		if rig != null:
			rig.recenter())
	h.add_child(recenter)

	# world label in the 3D scene is enough; strip is the main navigation.
	var strip := PanelContainer.new()
	strip.add_theme_stylebox_override("panel", Palette.style(Color(0.06, 0.10, 0.17, 0.94), 20, Color(1, 1, 1, 0.10), 1))
	strip.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	strip.offset_left = 36
	strip.offset_right = -36
	strip.offset_top = -172
	strip.offset_bottom = -22
	add_child(strip)

	var sv := Palette.vbox(6)
	strip.add_child(sv)
	var strip_head := Palette.hbox(8)
	strip_head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sv.add_child(strip_head)
	strip_head.add_child(Palette.label("MISSIONI DEL MONDO", 13, Palette.MUTED))
	strip_head.add_child(Palette.label("Tocca una porta o una scheda per iniziare", 12, Palette.MUTED))

	var cards := Palette.hbox(10)
	cards.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sv.add_child(cards)
	var first_incomplete := -1
	for i in range(missions.size()):
		if not GameState.is_complete(str(missions[i].get("id", ""))) and first_incomplete < 0:
			first_incomplete = i
	for i in range(missions.size()):
		cards.add_child(_mission_card(missions[i], i == first_incomplete))

	_joystick = TouchJoystick.new()
	_joystick.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_joystick.offset_left = 44
	_joystick.offset_top = -402
	_joystick.offset_right = 234
	_joystick.offset_bottom = -212
	_joystick.visible = bool(GameState.get_setting("touch_controls", true))
	add_child(_joystick)


func WORLD_TINT() -> Color:
	var code := str(world.get("code", "P1"))
	return {
		"INF": Palette.TEAL, "P1": Palette.GREEN, "P2": Palette.YELLOW,
		"P3": Palette.BLUE, "P4": Palette.CORAL, "P5": Palette.PURPLE,
		"S1": Palette.TEAL, "S2": Palette.PURPLE, "S3": Palette.CORAL,
	}.get(code, Palette.TEAL)


func _mission_card(mission: Dictionary, current: bool) -> PanelContainer:
	var id := str(mission.get("id", ""))
	var complete: bool = GameState.is_complete(id)
	var tint := Palette.GREEN if complete else (Palette.YELLOW if current else Palette.CARD_LIGHT)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(136, 92)
	card.add_theme_stylebox_override("panel", Palette.style(Color(0.10, 0.17, 0.27) if not complete else Color(0.12, 0.26, 0.20), 14, tint, 2))
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_open_mission(id)
		elif event is InputEventScreenTouch and event.pressed:
			_open_mission(id))

	var box := Palette.vbox(3)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(box)
	var top := Palette.hbox(4)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(top)
	top.add_child(Palette.label(id, 13, tint))
	var grow := Control.new()
	grow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(grow)
	if complete:
		top.add_child(Palette.label("✓", 16, Palette.GREEN))
	var title := Palette.label(str(mission.get("title", "")), 14, Palette.CREAM, true)
	title.max_lines_visible = 3
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.custom_minimum_size = Vector2(0, 54)
	box.add_child(title)
	return card


func _open_mission(id: String) -> void:
	if id == "":
		return
	go("mission", {"world_id": str(world.get("id", "")), "mission_id": id})


func _cycle_camera() -> void:
	if rig == null:
		return
	rig.cycle_mode()
	toast("Vista: " + rig.cycle_name(), 1.6, Palette.CREAM)
	if _camera_label != null:
		_camera_label.text = rig.cycle_name()


func _process(delta: float) -> void:
	if builder == null or builder.nilo == null or rig == null:
		return
	if _joystick == null:
		return
	var v: Vector2 = _joystick.value
	if v.length() < 0.1:
		builder.nilo.walking = false
		return
	var basis := rig.global_transform.basis
	var forward := -basis.z
	forward.y = 0
	forward = forward.normalized()
	var right := basis.x
	right.y = 0
	right = right.normalized()
	var dir: Vector3 = (right * v.x + forward * (-v.y)).normalized()
	var speed := 4.2 * minf(1.0, v.length())
	builder.nilo.position += dir * speed * delta
	var b: Rect2 = Rect2(-8.4, -5.8, 16.8, 11.6)
	builder.nilo.position.x = clampf(builder.nilo.position.x, b.position.x, b.position.x + b.size.x)
	builder.nilo.position.z = clampf(builder.nilo.position.z, b.position.y, b.position.y + b.size.y)
	builder.nilo.face_direction(dir)
	builder.nilo.walking = true


func _on_stage_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_press_position = event.position
		else:
			if event.position.distance_to(_press_position) < 24.0:
				_pick_portal(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_press_position = event.position
		else:
			if event.position.distance_to(_press_position) < 8.0:
				_pick_portal(event.position)


func _pick_portal(screen_pos: Vector2) -> void:
	if rig == null or builder == null:
		return
	var origin := rig.project_ray_origin(screen_pos)
	var normal := rig.project_ray_normal(screen_pos)
	if absf(normal.y) < 0.001:
		return
	var t := -origin.y / normal.y
	if t <= 0:
		return
	var point := origin + normal * t
	var best := -1
	var best_dist := 1.5
	for i in range(builder.portals.size()):
		var p: Dictionary = builder.portals[i]
		var pos: Vector3 = p.get("position", Vector3.ZERO)
		var d := Vector2(point.x - pos.x, point.z - pos.z).length()
		if d < best_dist:
			best_dist = d
			best = i
	if best >= 0:
		_open_mission(str(builder.portals[best].get("id", "")))
