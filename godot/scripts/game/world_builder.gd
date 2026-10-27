class_name WorldBuilder
extends RefCounted

## Builds the 3D projection of a mission, a hub or the title diorama.
## Everything is generated from primitives and mission JSON: no external 3D
## asset is required, which keeps the whole project CC-BY compatible.

const CELL := 1.25

var root: Node3D
var nilo: Nilo
var mission: Dictionary = {}
var grid: Dictionary = {}
var theme: Dictionary = {}
var entity_nodes: Dictionary = {}
var trace_mesh: ImmediateMesh
var trace_node: MeshInstance3D
var center := Vector2.ZERO
var bounds := Rect2()
var portals: Array = []


func _mat(color: Color, emission := 0.0, rough := 0.8) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emission
	return m


func _box(parent: Node3D, size: Vector3, pos: Vector3, color: Color, emission := 0.0) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat(color, emission)
	mi.position = pos
	parent.add_child(mi)
	return mi


func _cylinder(parent: Node3D, radius: float, height: float, pos: Vector3, color: Color, emission := 0.0, rot := Vector3.ZERO) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 14
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat(color, emission)
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


func _sphere(parent: Node3D, radius: float, pos: Vector3, color: Color, emission := 0.0, scale_v := Vector3.ONE) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 14
	mesh.rings = 7
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat(color, emission)
	mi.position = pos
	mi.scale = scale_v
	parent.add_child(mi)
	return mi


func _label(parent: Node3D, text: String, pos: Vector3, color := Color.WHITE, size := 46, pixel_size := 0.004) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.position = pos
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.font_size = size
	l.outline_size = 8
	l.modulate = color
	l.outline_modulate = Color(0.04, 0.07, 0.12, 0.9)
	l.pixel_size = pixel_size
	parent.add_child(l)
	return l


func _color(value, fallback: Color) -> Color:
	if value is Color:
		return value
	if value is String:
		return Color(value)
	return fallback


func _environment(parent: Node3D, t: Dictionary) -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	var sky := _color(t.get("sky", "#9bd1e5"), Color("#9bd1e5"))
	t["sky"] = sky
	env.background_mode = Environment.BG_COLOR
	env.background_color = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = sky.lerp(Color.WHITE, 0.55)
	env.ambient_light_energy = 0.32
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	we.environment = env
	parent.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -38, 0)
	sun.light_energy = 0.70
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 40.0
	parent.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-25, 140, 0)
	fill.light_energy = 0.22
	fill.shadow_enabled = false
	parent.add_child(fill)


func cell_to_world(c, y := 0.0) -> Vector3:
	var cx: float = float((int(grid.get("min_x", 0)) + int(grid.get("max_x", 9)))) * 0.5
	var cy: float = float((int(grid.get("min_y", 0)) + int(grid.get("max_y", 7)))) * 0.5
	return Vector3((float(c.x) - cx) * CELL, y, -(float(c.y) - cy) * CELL)


func _setup_grid(m: Dictionary) -> void:
	mission = m
	grid = m.get("grid", {"min_x": 0, "min_y": 0, "max_x": 9, "max_y": 7})
	theme = m.get("scene_theme", {"sky": "#9bd1e5", "ground": "#6bbf59", "accent": "#ffd166", "prop": "tree"})
	theme["ground"] = _color(theme.get("ground"), Color("#6bbf59"))
	theme["accent"] = _color(theme.get("accent"), Color("#ffd166"))
	theme["sky"] = _color(theme.get("sky"), Color("#9bd1e5"))
	var w: int = int(grid.max_x) - int(grid.min_x) + 1
	var h: int = int(grid.max_y) - int(grid.min_y) + 1
	center = Vector2((int(grid.min_x) + int(grid.max_x)) * 0.5, (int(grid.min_y) + int(grid.max_y)) * 0.5)
	bounds = Rect2(-w * CELL * 0.5, -h * CELL * 0.5, w * CELL, h * CELL)


func build_mission(m: Dictionary) -> Dictionary:
	root = Node3D.new()
	root.name = "MissionStage"
	entity_nodes = {}
	portals = []
	_setup_grid(m)
	_environment(root, theme)
	var ground: Color = theme.get("ground", Color("#6bbf59"))
	var accent: Color = theme.get("accent", Color("#ffd166"))

	var min_x: int = int(grid.min_x)
	var max_x: int = int(grid.max_x)
	var min_y: int = int(grid.min_y)
	var max_y: int = int(grid.max_y)
	# tiles
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			var col := ground if (x + y) % 2 == 0 else ground.darkened(0.07)
			var tile := _box(root, Vector3(CELL * 0.98, 0.12, CELL * 0.98), cell_to_world(Vector2i(x, y), -0.06), col)
			tile.name = "Tile_%d_%d" % [x, y]
	# grid lines
	var line_col: Color = accent.lerp(Color.WHITE, 0.3)
	var w: int = max_x - min_x + 1
	var h: int = max_y - min_y + 1
	for i in range(w + 1):
		var px := bounds.position.x + i * CELL
		_box(root, Vector3(0.025, 0.015, h * CELL), Vector3(px, 0.008, 0), line_col)
	for j in range(h + 1):
		var pz := bounds.position.y + j * CELL
		_box(root, Vector3(w * CELL, 0.015, 0.025), Vector3(0, 0.008, pz), line_col)
	# border
	var border := accent.darkened(0.25)
	_box(root, Vector3(w * CELL + 0.3, 0.20, 0.16), Vector3(0, 0.06, bounds.position.y - 0.08), border)
	_box(root, Vector3(w * CELL + 0.3, 0.20, 0.16), Vector3(0, 0.06, bounds.position.y + h * CELL + 0.08), border)
	_box(root, Vector3(0.16, 0.20, h * CELL + 0.3), Vector3(bounds.position.x - 0.08, 0.06, bounds.position.y + h * CELL * 0.5), border)
	_box(root, Vector3(0.16, 0.20, h * CELL + 0.3), Vector3(bounds.position.x + w * CELL + 0.08, 0.06, bounds.position.y + h * CELL * 0.5), border)

	# obstacles
	for c in m.get("obstacles", []):
		var cell := Vector2i(int(c[0]), int(c[1]))
		var p := cell_to_world(cell, 0.32)
		_box(root, Vector3(CELL * 0.82, 0.64, CELL * 0.82), p, Color("#5b4b63"))
		_box(root, Vector3(CELL * 0.70, 0.10, CELL * 0.70), p + Vector3(0, 0.37, 0), Color("#ffb703"))

	# entities
	var many: bool = m.get("entities", []).size() > 12
	for e in m.get("entities", []):
		var node := _build_entity(e, many)
		entity_nodes[str(e.id)] = node

	# start marker
	var spawn_c = m.get("spawn", {}).get("cell", [0, 0])
	var spawn_cell := Vector2i(int(spawn_c[0]), int(spawn_c[1]))
	var start_ring := _cylinder(root, CELL * 0.40, 0.04, cell_to_world(spawn_cell, 0.02), Palette.TEAL, 1.4)
	start_ring.name = "StartRing"

	# trace
	trace_mesh = ImmediateMesh.new()
	trace_node = MeshInstance3D.new()
	trace_node.mesh = trace_mesh
	var tm := StandardMaterial3D.new()
	tm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tm.vertex_color_use_as_albedo = true
	tm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	trace_node.material_override = tm
	root.add_child(trace_node)

	# props around the field
	_scatter_props()

	# Nilo
	nilo = Nilo.new()
	nilo.name = "Nilo"
	root.add_child(nilo)
	var heading: int = ["N", "E", "S", "W"].find(str(m.get("spawn", {}).get("heading", "E")))
	if heading < 0:
		heading = 1
	nilo.teleport(cell_to_world(spawn_cell, 0.04), heading)

	# target halo
	if m.get("goal", {}).has("reach"):
		var rc = m.goal.reach
		var rp := cell_to_world(Vector2i(int(rc[0]), int(rc[1])), 0.025)
		var ring := _cylinder(root, CELL * 0.38, 0.035, rp, Palette.YELLOW, 1.8)
		ring.name = "GoalRing"

	return {"root": root, "nilo": nilo, "bounds": bounds, "cell_size": CELL, "entity_nodes": entity_nodes, "builder": self}


func _build_entity(e: Dictionary, compact: bool) -> Node3D:
	var node := Node3D.new()
	node.name = "Entity_" + str(e.get("id", "x"))
	var kind: String = str(e.get("kind", "target"))
	var cell: Array = e.get("cell", [0, 0])
	var p := cell_to_world(Vector2i(int(cell[0]), int(cell[1])), 0.05)
	node.position = p
	node.set_meta("entity_id", str(e.get("id", "")))
	node.set_meta("kind", kind)
	root.add_child(node)
	var color := Palette.TEAL
	var glyph := "*"
	match kind:
		"collect":
			color = Palette.YELLOW
			glyph = "*"
			_cylinder(node, 0.12, 0.55, Vector3(0, 0.28, 0), color, 0.3)
			_sphere(node, 0.22, Vector3(0, 0.62, 0), color, 0.55)
			var ring := _cylinder(node, 0.28, 0.035, Vector3(0, 0.10, 0), color, 0.9)
			ring.rotation.x = PI * 0.5
		"activate", "target":
			color = Palette.CORAL if kind == "activate" else Palette.BLUE
			glyph = "!"
			_cylinder(node, 0.24, 0.18, Vector3(0, 0.09, 0), Color("#394b61"))
			_box(node, Vector3(0.12, 0.55, 0.12), Vector3(0, 0.46, 0), color)
			_sphere(node, 0.11, Vector3(0, 0.78, 0), color, 0.7)
			var ring2 := _cylinder(node, 0.30, 0.02, Vector3(0, 0.20, 0), color, 0.5)
			ring2.rotation.x = PI * 0.5
		"photo":
			color = Palette.PURPLE
			glyph = "o"
			_box(node, Vector3(0.45, 0.32, 0.28), Vector3(0, 0.38, 0), Color("#2b2d42"))
			var lens := _cylinder(node, 0.12, 0.10, Vector3(0, 0.38, -0.16), color, 0.6, Vector3(PI * 0.5, 0, 0))
			_box(node, Vector3(0.14, 0.10, 0.14), Vector3(0, 0.60, 0), color)
		_:
			color = Palette.BLUE
			glyph = "?"
			_cylinder(node, 0.20, 0.12, Vector3(0, 0.06, 0), color, 0.5)
			_box(node, Vector3(0.06, 1.0, 0.06), Vector3(0, 0.56, 0), Color("#f1faee"))
			_box(node, Vector3(0.40, 0.24, 0.03), Vector3(0.20, 0.92, 0), color)
	if not compact:
		_label(node, str(e.get("label", glyph)), Vector3(0, 1.18, 0), Palette.CREAM, 40)
	return node


func _scatter_props() -> void:
	var prop: String = str(theme.get("prop", "tree"))
	var positions := [
		Vector2(bounds.position.x - 1.2, bounds.position.y - 1.0),
		Vector2(bounds.position.x + bounds.size.x + 1.2, bounds.position.y - 0.8),
		Vector2(bounds.position.x - 1.4, bounds.position.y + bounds.size.y + 1.0),
		Vector2(bounds.position.x + bounds.size.x + 1.1, bounds.position.y + bounds.size.y + 1.2),
		Vector2(bounds.position.x + bounds.size.x * 0.25, bounds.position.y - 1.4),
		Vector2(bounds.position.x + bounds.size.x * 0.75, bounds.position.y - 1.5),
		Vector2(bounds.position.x - 1.3, bounds.position.y + bounds.size.y * 0.5),
		Vector2(bounds.position.x + bounds.size.x + 1.3, bounds.position.y + bounds.size.y * 0.55),
	]
	for p in positions:
		_prop(prop, Vector3(p.x, 0, p.y), 1.0)


func _prop(kind: String, pos: Vector3, s := 1.0) -> void:
	var node := Node3D.new()
	node.position = pos
	node.scale = Vector3.ONE * s
	root.add_child(node)
	match kind:
		"acacia", "tree":
			_cylinder(node, 0.10, 1.25, Vector3(0, 0.62, 0), Color("#7f5539"))
			_sphere(node, 0.62, Vector3(0, 1.45, 0), Color("#588157"), 0.0, Vector3(1.3, 0.55, 1.3))
			_sphere(node, 0.42, Vector3(0.35, 1.62, 0.15), Color("#6a994e"), 0.0, Vector3(1.1, 0.45, 1.1))
		"gear":
			_cylinder(node, 0.42, 0.20, Vector3(0, 0.55, 0), Color("#ffb703"))
			for i in range(8):
				var a := TAU * float(i) / 8.0
				_box(node, Vector3(0.16, 0.20, 0.20), Vector3(cos(a) * 0.46, 0.55, sin(a) * 0.46), Color("#e76f51"))
			_cylinder(node, 0.46, 0.08, Vector3(0, 0.30, 0), Color("#8d7bf6"))
		"house":
			_box(node, Vector3(1.1, 0.8, 0.9), Vector3(0, 0.4, 0), Color("#f1e3d3"))
			var roof := PrismMesh.new()
			roof.size = Vector3(1.25, 0.55, 1.0)
			var rm := MeshInstance3D.new()
			rm.mesh = roof
			rm.material_override = _mat(Palette.CORAL)
			rm.position = Vector3(0, 1.0, 0)
			node.add_child(rm)
			_box(node, Vector3(0.22, 0.35, 0.05), Vector3(0, 0.28, -0.46), Color("#6d597a"))
		"palm":
			_cylinder(node, 0.08, 1.7, Vector3(0, 0.85, 0), Color("#b07d62"))
			for i in range(5):
				var a2 := TAU * float(i) / 5.0
				var leaf := _box(node, Vector3(0.75, 0.05, 0.18), Vector3(cos(a2) * 0.32, 1.72, sin(a2) * 0.32), Color("#2a9d8f"))
				leaf.rotation.y = -a2
				leaf.rotation.z = 0.22
		"antenna":
			_cylinder(node, 0.07, 2.0, Vector3(0, 1.0, 0), Color("#cdb4db"))
			_sphere(node, 0.18, Vector3(0, 2.05, 0), Palette.TEAL, 1.3)
			_box(node, Vector3(0.5, 0.08, 0.5), Vector3(0, 0.04, 0), Color("#6d597a"))
		"tower":
			_box(node, Vector3(0.85, 2.2, 0.85), Vector3(0, 1.1, 0), Color("#8fa3b8"))
			_box(node, Vector3(1.0, 0.18, 1.0), Vector3(0, 2.25, 0), Palette.YELLOW)
			for i in range(3):
				_box(node, Vector3(0.14, 0.22, 0.05), Vector3(0, 0.7 + i * 0.45, -0.44), Palette.TEAL, 0.7)
		"boat":
			_box(node, Vector3(1.4, 0.32, 0.6), Vector3(0, 0.25, 0), Color("#7f5539"))
			_cylinder(node, 0.05, 1.5, Vector3(0, 1.0, 0), Color("#e9c46a"))
			var sail := PrismMesh.new()
			sail.size = Vector3(0.8, 0.9, 0.05)
			var sm := MeshInstance3D.new()
			sm.mesh = sail
			sm.material_override = _mat(Color("#f1faee"))
			sm.position = Vector3(0, 1.15, 0)
			node.add_child(sm)
		"skyscraper":
			_box(node, Vector3(0.9, 2.6, 0.9), Vector3(0, 1.3, 0), Color("#4a4e69"))
			for i in range(6):
				for j in range(2):
					_box(node, Vector3(0.10, 0.14, 0.04), Vector3(-0.25 + j * 0.50, 0.45 + i * 0.35, -0.46), Palette.YELLOW, 0.8)
		_:
			_cylinder(node, 0.35, 0.35, Vector3(0, 0.18, 0), Palette.PURPLE)
			_sphere(node, 0.28, Vector3(0, 0.55, 0), Palette.CORAL)


func build_menu_stage() -> Dictionary:
	root = Node3D.new()
	root.name = "MenuStage"
	theme = {"sky": "#0f1b2d", "ground": "#2a9d8f", "accent": "#ffd166", "prop": "palm"}
	grid = {"min_x": 0, "min_y": 0, "max_x": 12, "max_y": 8}
	_environment(root, theme)
	# floating island
	var island := _cylinder(root, 5.6, 0.55, Vector3(0, -0.25, 0), Color("#2a9d8f"))
	island.name = "Island"
	_cylinder(root, 4.8, 0.10, Vector3(0, 0.05, 0), Color("#8ac926"))
	# path
	for i in range(5):
		_box(root, Vector3(1.0, 0.03, 0.8), Vector3(-2.0 + i * 1.0, 0.11, 0.2), Color("#ffd166"), 0.15)
	# props
	for p in [Vector3(-4.0, 0, -2.2), Vector3(4.2, 0, -2.0), Vector3(-4.4, 0, 2.4), Vector3(4.4, 0, 2.2), Vector3(0, 0, -3.2)]:
		theme["prop"] = ["palm", "tree", "antenna", "gear", "tower"][randi() % 5]
		_prop(str(theme["prop"]), p, 1.2)
	nilo = Nilo.new()
	nilo.name = "Nilo"
	root.add_child(nilo)
	nilo.teleport(Vector3(0, 0.12, 0.4), 2)

	var cam := Camera3D.new()
	cam.position = Vector3(0, 5.0, 11.0)
	cam.look_at_from_position(Vector3(0, 5.0, 11.0), Vector3(0, 1.0, 0), Vector3.UP)
	cam.fov = 42
	root.add_child(cam)
	return {"root": root, "nilo": nilo, "camera": cam, "center": Vector3(0, 0.8, 0)}


func build_hub(world: Dictionary, missions: Array) -> Dictionary:
	root = Node3D.new()
	root.name = "HubStage"
	portals = []
	theme = world.get("theme", {"sky": "#9bd1e5", "ground": "#6bbf59", "accent": "#ffd166", "prop": "tree"})
	theme["ground"] = _color(theme.get("ground"), Color("#6bbf59"))
	theme["accent"] = _color(theme.get("accent"), Color("#ffd166"))
	theme["sky"] = _color(theme.get("sky"), Color("#9bd1e5"))
	grid = {"min_x": 0, "min_y": 0, "max_x": 14, "max_y": 10}
	_environment(root, theme)
	var ground: Color = theme.get("ground", Color("#6bbf59"))
	_box(root, Vector3(20.0, 0.3, 14.0), Vector3(0, -0.15, 0), ground)
	_box(root, Vector3(18.0, 0.05, 12.0), Vector3(0, 0.02, 0), ground.lightened(0.05))
	# decorative ring
	for i in range(40):
		var a := TAU * float(i) / 40.0
		_box(root, Vector3(0.16, 0.035, 0.16), Vector3(cos(a) * 7.2, 0.07, sin(a) * 5.2), theme.get("accent", Palette.YELLOW), 0.25)
	# portals in two arcs
	for i in range(missions.size()):
		var row := i / 5
		var col := i % 5
		var px := -4.4 + col * 2.2
		var pz := -2.2 + row * 4.0
		var m: Dictionary = missions[i]
		var id := str(m.get("id", ""))
		var portal := Node3D.new()
		portal.position = Vector3(px, 0, pz)
		root.add_child(portal)
		_cylinder(portal, 0.58, 0.10, Vector3(0, 0.05, 0), theme.get("accent", Palette.YELLOW), 0.35)
		var ring := _cylinder(portal, 0.48, 0.08, Vector3(0, 0.10, 0), Palette.TEAL, 0.7)
		ring.rotation.x = PI * 0.5
		_box(portal, Vector3(0.10, 1.35, 0.10), Vector3(-0.42, 0.70, 0), Color("#f1faee"))
		_box(portal, Vector3(0.10, 1.35, 0.10), Vector3(0.42, 0.70, 0), Color("#f1faee"))
		_box(portal, Vector3(1.0, 0.10, 0.10), Vector3(0, 1.40, 0), theme.get("accent", Palette.YELLOW))
		# Only the mission code floats in 3D: titles live in the card strip and
		# would overlap between the two rows of portals.
		_label(portal, str(m.get("id", "")), Vector3(0, 1.95, 0), Palette.CREAM, 64, 0.007)
		portals.append({"id": id, "node": portal, "position": Vector3(px, 0, pz)})
	# Nilo
	nilo = Nilo.new()
	nilo.name = "Nilo"
	root.add_child(nilo)
	nilo.teleport(Vector3(0, 0.06, 4.1), 0)
	# props
	for p in [Vector3(-7.0, 0, -4.0), Vector3(7.0, 0, -4.0), Vector3(-7.0, 0, 4.0), Vector3(7.0, 0, 4.0)]:
		_prop(str(theme.get("prop", "tree")), p, 1.3)
	return {"root": root, "nilo": nilo, "portals": portals, "bounds": Rect2(-8, -5.5, 16, 11)}


func set_entity_state(entity_id: String, active: bool) -> void:
	if not entity_nodes.has(entity_id):
		return
	var node: Node3D = entity_nodes[entity_id]
	if active:
		var tw = root.create_tween()
		tw.tween_property(node, "scale", Vector3(1.18, 1.18, 1.18), 0.12)
		tw.tween_property(node, "scale", Vector3.ONE, 0.18)
		for child in node.get_children():
			if child is MeshInstance3D and child.material_override is StandardMaterial3D:
				var mat: StandardMaterial3D = child.material_override
				mat.emission_enabled = true
				mat.emission = Palette.GREEN
				mat.emission_energy_multiplier = 0.55


func draw_trace(cells: Array) -> void:
	if trace_mesh == null:
		return
	trace_mesh.clear_surfaces()
	if cells.size() < 2:
		return
	trace_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for c in cells:
		var p := cell_to_world(Vector2i(int(c[0]), int(c[1])), 0.14)
		trace_mesh.surface_set_color(Palette.YELLOW)
		trace_mesh.surface_add_vertex(p)
	trace_mesh.surface_end()
