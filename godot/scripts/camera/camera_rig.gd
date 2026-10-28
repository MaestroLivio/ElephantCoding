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
## Field framing only makes sense with a narrow lens; the two closer views need
## a wider one or the character fills the whole screen.
var base_fov := 32.0
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
	base_fov = fov
	_initialised = true
	_apply_mode(true)


func set_mode(m: int) -> void:
	mode = clampi(m, 0, 2)
	# Snap on a mode change: the previous framing (and its frustum shift) is
	# meaningless for the new one, so interpolating would look like a drift.
	_apply_mode(true)


func cycle_mode() -> int:
	mode = (mode + 1) % 3
	_apply_mode(true)
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
	orbit_yaw = wrapf(orbit_yaw - delta_x * 0.006, -PI, PI)
	orbit_pitch = clampf(orbit_pitch + delta_y * 0.004, -0.55, 0.55)


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
	# Only the fixed field composes itself through a frustum shift. Any other
	# mode must start from a neutral frustum, otherwise the shift computed for
	# the field also pushes the character out of the middle of the screen.
	if mode != Mode.FIXED:
		h_offset = 0.0
		v_offset = 0.0
	match mode:
		Mode.FIXED:
			fov = base_fov
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
			look_at(Vector3(0, 0.15, 0), Vector3.UP)
			# Centre the *projected* field in the safe rect: with a tilted camera
			# the near edge projects much lower than the far edge, so centring
			# the 3D pivot alone would push the field under the bottom panels.
			_center_in_safe_rect(weight)
		Mode.CHASE:
			if target == null:
				return
			fov = base_fov * 1.45
			var b := target.global_transform.basis
			var behind := b.z * (6.6 * zoom) + Vector3(0, 3.4 * zoom, 0)
			behind = behind.rotated(Vector3.UP, orbit_yaw)
			var desired2 := target.global_position + behind
			global_position = global_position.lerp(desired2, weight)
			look_at(target.global_position + Vector3(0, 1.15, 0), Vector3.UP)
		Mode.FIRST:
			if target == null:
				return
			fov = base_fov * 1.9
			var fwd := -target.global_transform.basis.z
			fwd.y = 0.0
			fwd = Vector3.FORWARD if fwd.length_squared() < 0.0001 else fwd.normalized()
			# Look where the elephant looks, turned by the drag gesture so the
			# player can glance around while the body keeps its heading.
			var yawed := fwd.rotated(Vector3.UP, orbit_yaw)
			var right := yawed.cross(Vector3.UP).normalized()
			var look_dir := yawed.rotated(right, -orbit_pitch).normalized()
			var eye := target.global_position + Vector3(0.0, 1.55, 0.0) + fwd * 0.30
			global_position = global_position.lerp(eye, weight) if weight < 1.0 else eye
			# Look along the composed direction from the *current* eye position:
			# aiming at the lagging position would tilt the whole view.
			look_at(global_position + look_dir * 8.0, Vector3.UP)


## Bounding box (viewport pixels) of the four field corners projected on screen.
func _projected_bounds() -> Rect2:
	var hw := bounds.size.x * 0.5
	var hh := bounds.size.y * 0.5
	var c := bounds.get_center()
	var minp := Vector2(INF, INF)
	var maxp := Vector2(-INF, -INF)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var sp := unproject_position(Vector3(c.x + sx * hw, 0.0, c.y + sz * hh))
			minp = minp.min(sp)
			maxp = maxp.max(sp)
	return Rect2(minp, maxp - minp)


## Shift the frustum so the projected field is centred in `safe_rect`. The
## correction is measured on screen, so it works for any field size, zoom and
## panel layout without re-deriving the projection maths.
func _center_in_safe_rect(weight: float) -> void:
	var vp := get_viewport()
	if vp == null:
		return
	var view_size := vp.get_visible_rect().size
	if view_size.x <= 1.0 or view_size.y <= 1.0:
		return
	var bbox := _projected_bounds()
	if bbox.size.x <= 0.0:
		return
	var want := Vector2(
		(safe_rect.position.x + safe_rect.size.x * 0.5) * view_size.x,
		(safe_rect.position.y + safe_rect.size.y * 0.5) * view_size.y)
	var shift := want - bbox.get_center()
	# How many pixels does one metre of frustum offset move the image?
	var probe := Vector3(bounds.get_center().x, 0.0, bounds.get_center().y)
	var before := unproject_position(probe)
	h_offset += 0.01
	v_offset += 0.01
	var after := unproject_position(probe)
	h_offset -= 0.01
	v_offset -= 0.01
	var gain := (after - before) / 0.01
	if absf(gain.x) < 0.001 or absf(gain.y) < 0.001:
		return
	h_offset += shift.x / gain.x * weight
	v_offset += shift.y / gain.y * weight
