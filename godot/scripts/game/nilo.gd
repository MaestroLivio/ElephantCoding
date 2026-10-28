class_name Nilo
extends Node3D

## Original low-poly Nilo, built from primitives so the project ships no
## third-party 3D assets and remains CC-BY compatible.

const TURN_SPEED := 9.0
const SPIN_SPEED := 7.0

var walking := false
var _phase := 0.0
var _body: MeshInstance3D
var _head: Node3D
var _trunk: Node3D
var _legs: Array = []
var _tween: Tween
var _base_body_y := 0.92
var _reduced_motion := false
var _idle_time := 0.0
var _target_yaw := 0.0
var _spinning := false


func _ready() -> void:
	_reduced_motion = bool(GameState.get_setting("reduce_motion", false))
	_build()
	scale = Vector3(0.82, 0.82, 0.82)


func _mat(color: Color, rough := 0.72, metal := 0.0, emission := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emission
	return m


func _mesh(mesh: Mesh, color: Color, pos: Vector3, parent: Node3D, rough := 0.72, emission := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat(color, rough, 0.0, emission)
	mi.position = pos
	parent.add_child(mi)
	return mi


func _sphere(parent: Node3D, pos: Vector3, scale_v: Vector3, color: Color, emission := 0.0) -> MeshInstance3D:
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	sm.radial_segments = 16
	sm.rings = 8
	var mi := _mesh(sm, color, pos, parent, 0.7, emission)
	mi.scale = scale_v
	return mi


func _cyl(parent: Node3D, pos: Vector3, radius: float, height: float, color: Color, rot := Vector3.ZERO, emission := 0.0) -> MeshInstance3D:
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = height
	cm.radial_segments = 12
	var mi := _mesh(cm, color, pos, parent, 0.7, emission)
	mi.rotation = rot
	return mi


func _build() -> void:
	var skin := Color("#8fa3b8")
	var skin_light := Color("#b9c8d8")
	var ear := Color("#e8a6b8")
	var dark := Color("#34495e")
	var backpack := Color("#ff8c42")
	var strap := Color("#2ec4b6")

	var root := Node3D.new()
	root.name = "Body"
	add_child(root)
	_body = _sphere(root, Vector3(0, _base_body_y, 0.02), Vector3(1.05, 1.05, 1.35), skin)

	# back legs
	for x in [-0.3, 0.3]:
		for z in [0.28]:
			var leg := _cyl(root, Vector3(x, 0.28, z), 0.14, 0.5, skin_light)
			_legs.append(leg)
	# front legs
	for x in [-0.3, 0.3]:
		for z in [-0.25]:
			var leg2 := _cyl(root, Vector3(x, 0.28, z), 0.14, 0.5, skin_light)
			_legs.append(leg2)

	# toenails
	for x in [-0.3, 0.3]:
		for z in [-0.25, 0.28]:
			var nail := _sphere(root, Vector3(x - 0.04, 0.035, z - 0.1), Vector3(0.06, 0.04, 0.09), Color("#f5e6c8"))
			nail.rotation.x = 0.2

	# head
	_head = Node3D.new()
	_head.position = Vector3(0, 1.5, -0.28)
	root.add_child(_head)
	_sphere(_head, Vector3.ZERO, Vector3(0.78, 0.74, 0.76), skin)
	# ears
	for side in [-1, 1]:
		var ear_mesh := _sphere(_head, Vector3(side * 0.38, 0.06, 0.05), Vector3(0.34, 0.46, 0.08), skin)
		ear_mesh.rotation.z = side * -0.15
		var inner := _sphere(_head, Vector3(side * 0.40, 0.06, 0.02), Vector3(0.22, 0.32, 0.04), ear)
		inner.rotation.z = side * -0.15
	# eyes
	for side2 in [-1, 1]:
		_sphere(_head, Vector3(side2 * 0.17, 0.05, -0.34), Vector3(0.11, 0.12, 0.07), Color("#17202a"))
		_sphere(_head, Vector3(side2 * 0.155, 0.08, -0.385), Vector3(0.035, 0.035, 0.02), Color.WHITE)
	# tusks
	for side3 in [-1, 1]:
		var tusk := _cyl(_head, Vector3(side3 * 0.13, -0.20, -0.28), 0.035, 0.28, Color("#fff1d0"), Vector3(0.55, 0, side3 * 0.15))
		tusk.scale = Vector3(1, 1, 1)
	# trunk
	_trunk = Node3D.new()
	_trunk.position = Vector3(0, -0.18, -0.34)
	_head.add_child(_trunk)
	_cyl(_trunk, Vector3(0, -0.04, -0.08), 0.13, 0.26, skin, Vector3(0.55, 0, 0))
	_cyl(_trunk, Vector3(0, -0.20, -0.22), 0.10, 0.26, skin, Vector3(0.85, 0, 0))
	_cyl(_trunk, Vector3(0, -0.34, -0.28), 0.08, 0.22, skin_light, Vector3(1.15, 0, 0))
	# mouth / smile
	_sphere(_head, Vector3(0, -0.12, -0.35), Vector3(0.12, 0.03, 0.03), dark)

	# scarf
	var scarf := _cyl(root, Vector3(0, 1.17, -0.04), 0.30, 0.10, strap)
	scarf.scale = Vector3(1.0, 1.0, 1.35)

	# backpack
	var bp := BoxMesh.new()
	bp.size = Vector3(0.62, 0.62, 0.32)
	var bp_mesh := _mesh(bp, backpack, Vector3(0, 1.02, 0.38), root)
	bp_mesh.rotation.x = -0.12
	var pocket := BoxMesh.new()
	pocket.size = Vector3(0.40, 0.24, 0.12)
	_mesh(pocket, Color("#e76f51"), Vector3(0, 0.90, 0.56), root)
	for side4 in [-1, 1]:
		var strap_mesh := BoxMesh.new()
		strap_mesh.size = Vector3(0.07, 0.62, 0.06)
		_mesh(strap_mesh, strap, Vector3(side4 * 0.22, 1.12, 0.14), root)
	# tail
	var tail := _cyl(root, Vector3(0, 0.92, 0.65), 0.035, 0.38, skin_light, Vector3(-0.7, 0, 0))
	var tail_tip := _sphere(root, Vector3(0, 0.76, 0.82), Vector3(0.09, 0.12, 0.09), dark)
	tail_tip.rotation.x = 0.2


func _process(delta: float) -> void:
	_update_facing(delta)
	_idle_time += delta
	if walking and not _reduced_motion:
		_phase += delta * 10.0
		for i in range(_legs.size()):
			var direction := 1.0 if i % 2 == 0 else -1.0
			_legs[i].rotation.x = sin(_phase) * 0.38 * direction
		if _body != null:
			_body.position.y = _base_body_y + absf(sin(_phase)) * 0.045
		if _trunk != null:
			_trunk.rotation.x = sin(_phase * 0.5) * 0.12
	else:
		for leg in _legs:
			leg.rotation.x = lerpf(leg.rotation.x, 0.0, minf(1.0, delta * 8.0))
		if _body != null:
			_body.position.y = lerpf(_body.position.y, _base_body_y + sin(_idle_time * 1.8) * 0.012, minf(1.0, delta * 4.0))
		if _trunk != null and not _reduced_motion:
			_trunk.rotation.z = sin(_idle_time * 0.9) * 0.035


## Facing is interpolated here instead of by a tween: a tween on rotation:y
## would run in parallel with the walk tween, the two would overwrite each
## other and Nilo could end up facing away from the direction he just walked.
func _update_facing(delta: float) -> void:
	if _spinning:
		rotation.y = move_toward(rotation.y, _target_yaw, delta * SPIN_SPEED)
		if is_equal_approx(rotation.y, _target_yaw):
			_spinning = false
			rotation.y = wrapf(rotation.y, -PI, PI)
			_target_yaw = rotation.y
		return
	var diff := wrapf(_target_yaw - rotation.y, -PI, PI)
	var step := minf(absf(diff), delta * TURN_SPEED)
	rotation.y += signf(diff) * step


func _aim(yaw: float, immediate := false) -> void:
	_target_yaw = yaw
	_spinning = false
	if immediate or _reduced_motion:
		rotation.y = wrapf(yaw, -PI, PI)


func face_heading(heading: int, immediate := false) -> void:
	_aim(-float(heading) * PI * 0.5, immediate)


## Turns Nilo towards a world-space direction (used by the free-walk hub).
func face_direction(dir: Vector3) -> void:
	if Vector2(dir.x, dir.z).length_squared() < 0.0001:
		return
	_target_yaw = atan2(-dir.x, -dir.z)
	_spinning = false


func move_to_world(target: Vector3, heading: int, duration := 0.32, immediate := false) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_aim(-float(heading) * PI * 0.5, immediate)
	if immediate or _reduced_motion:
		position = target
		walking = false
		return
	walking = true
	_tween = create_tween()
	_tween.tween_property(self, "position", target, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_callback(func(): walking = false)


func teleport(world_pos: Vector3, heading: int) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	position = world_pos
	_aim(-float(heading) * PI * 0.5, true)
	walking = false


func celebrate() -> void:
	if _reduced_motion:
		return
	_target_yaw = rotation.y + TAU
	_spinning = true
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3(0.88, 0.92, 0.88), 0.12)
	tw.tween_property(self, "scale", Vector3(0.82, 0.82, 0.82), 0.22)


func oops() -> void:
	if _reduced_motion:
		return
	var tw := create_tween()
	tw.tween_property(self, "rotation:z", 0.10, 0.12)
	tw.tween_property(self, "rotation:z", -0.08, 0.16)
	tw.tween_property(self, "rotation:z", 0.0, 0.12)
