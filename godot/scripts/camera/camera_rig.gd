class_name CameraRig
extends Camera3D

## Three camera modes required by the design: fixed field, 3D chase, first person.
## In FIXED mode the rig frames the whole field inside `safe_rect`, a normalised
## screen rect (0..1) that excludes the UI panels. Those panels cover the shared
## full-screen 3D viewport, so the field must be composed into the strip that
## stays visible instead of the raw screen centre.

enum Mode { FIXED, CHASE, FIRST }

const ELEVATION_DEG := 58.0
const FIT_MARGIN := 0.86

var mode: int = Mode.FIXED
var target: Node3D
var bounds := Rect2(-6, -5, 12, 10)
var safe_rect := Rect2(0.0, 0.0, 1.0, 1.0)
var orbit_yaw := 0.0
var orbit_pitch := 0.0
var zoom := 1.0
var auto_orbit := false
var _initialised := false


func setup_for_bounds(p_bounds: Rect2, p_target: Node3D = null) -> void:
	bounds = p_bounds
	target = p_target
	_initialised = true
	_apply_mode(true)


func set_mode(m: int) -> void:
	mode = clampi(m, 0, 2)
	_apply_mode(false)


func cycle_mode() -> int:
	mode = (mode + 1) % 3
	_apply_mode(false)
	return mode


func mode_name() -> String:
	return ["CAMPO FISSO", "INSEGUIMENTO", "PRIMA PERSONA"][mode]


func cycle_name() -> String:
	return ["CAMPO FISSO", "INSEGUIMENTO 3D", "PRIMA PERSONA"][mode]


func _apply_mode(immediate: bool) -> void:
	if not _initialised:
		return
	if immediate:
		_reposition(1.0)


func orbit_by(delta_x: float, delta_y: float) -> void:
	orbit_yaw -= delta_x * 0.006
	orbit_pitch = clampf(orbit_pitch + delta_y * 0.004, -0.5, 0.4)


func zoom_by(factor: float) -> void:
	zoom = clampf(zoom * factor, 0.55, 2.0)


func recenter() -> void:
	orbit_yaw = 0.0
	orbit_pitch = 0.0
	zoom = 1.0


func _process(delta: float) -> void:
	if not _initialised:
		return
	if auto_orbit:
		orbit_yaw += delta * 0.09
	_reposition(1.0 - exp(-delta * 6.0))


func _reposition(weight: float) -> void:
	var center := Vector3(0, 0, 0)
	if target != null:
		center = target.global_position
	match mode:
		Mode.FIXED:
			var view := get_viewport()
			var view_size: Vector2 = view.get_visible_rect().size if view != null else Vector2(1600, 900)
			var aspect: float = view_size.x / maxf(view_size.y, 1.0)
			var half_v := deg_to_rad(fov) * 0.5
			var tan_v := tan(half_v)
			var tan_h := tan_v * aspect
			var half_w: float = maxf(0.06, safe_rect.size.x * FIT_MARGIN)
			var half_h: float = maxf(0.06, safe_rect.size.y * FIT_MARGIN)
			var elevation := deg_to_rad(ELEVATION_DEG)
			# Fit the near edge of the field (the widest on screen) horizontally
			# and the projected depth vertically.
			var near_pull: float = bounds.size.y * 0.5 * cos(elevation)
			var by_width: float = bounds.size.x / (2.0 * half_w * tan_h) + near_pull
			var by_depth: float = bounds.size.y * 0.5 * sin(elevation) / (half_h * tan_v)
			var distance: float = maxf(by_width, by_depth) * zoom
			var offset := Vector3(0.0, sin(elevation), cos(elevation)) * distance
			offset = offset.rotated(Vector3.UP, orbit_yaw)
			offset.y += orbit_pitch * distance * 0.35
			var desired := Vector3(0, 0, 0) + offset
			global_position = global_position.lerp(desired, weight) if weight < 1.0 else desired
			look_at(Vector3(0, 0.4, 0), Vector3.UP)
			# Shift the frustum so the field centre lands in the middle of the
			# safe rect instead of the middle of the whole screen.
			var ndc_x: float = safe_rect.position.x + safe_rect.size.x * 0.5
			var ndc_y: float = safe_rect.position.y + safe_rect.size.y * 0.5
			h_offset = lerpf(h_offset, -(ndc_x * 2.0 - 1.0) * distance * tan_h, weight)
			v_offset = lerpf(v_offset, -(ndc_y * 2.0 - 1.0) * distance * tan_v, weight)
		Mode.CHASE:
			if target == null:
				return
			var b := target.global_transform.basis
			var behind := b.z * (5.4 * zoom) + Vector3(0, 3.05 * zoom, 0)
			behind = behind.rotated(Vector3.UP, orbit_yaw)
			var desired2 := target.global_position + behind
			global_position = global_position.lerp(desired2, weight)
			look_at(target.global_position + Vector3(0, 1.15, 0), Vector3.UP)
		Mode.FIRST:
			if target == null:
				return
			var fwd := -target.global_transform.basis.z
			var eye := target.global_position + Vector3(0, 1.55, 0) + fwd * 0.30
			global_position = global_position.lerp(eye, weight)
			look_at(eye + fwd * 5.0, Vector3.UP)
