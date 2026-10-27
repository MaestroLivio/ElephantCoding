class_name TouchJoystick
extends Control

## Large, high-contrast virtual stick for touch screens and kiosks.
## Reports a normalised Vector2. Works with mouse, finger and pen so the
## same build can be tested on a desktop.

signal moved(value: Vector2)
signal released

const DEADZONE := 0.16

var value := Vector2.ZERO
var _pointer := -1
var _centre := Vector2.ZERO
var _radius := 52.0
var _active := false


func _ready() -> void:
	custom_minimum_size = Vector2(190, 190)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	resized.connect(func(): queue_redraw())


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and not _active:
			_begin(event.position, event.index)
			accept_event()
		elif not event.pressed and event.index == _pointer:
			_end()
			accept_event()
	elif event is InputEventScreenDrag and event.index == _pointer:
		_update(event.position)
		accept_event()
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed and not _active:
				_begin(event.position, 0)
				accept_event()
			elif not event.pressed and _active and _pointer == 0:
				_end()
				accept_event()
	elif event is InputEventMouseMotion and _active and _pointer == 0:
		_update(event.position)
		accept_event()


func _begin(local_pos: Vector2, pointer_id: int) -> void:
	_pointer = pointer_id
	_active = true
	_centre = size * 0.5
	_radius = minf(size.x, size.y) * 0.34
	_update(local_pos)


func _update(local_pos: Vector2) -> void:
	var offset := local_pos - size * 0.5
	var limit := minf(size.x, size.y) * 0.36
	if offset.length() > limit:
		offset = offset.normalized() * limit
	var raw := offset / maxf(1.0, limit)
	if raw.length() < DEADZONE:
		raw = Vector2.ZERO
	value = raw
	moved.emit(value)
	queue_redraw()


func _end() -> void:
	_active = false
	_pointer = -1
	value = Vector2.ZERO
	moved.emit(value)
	released.emit()
	queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.44
	draw_circle(c, r, Color(0.06, 0.10, 0.17, 0.55))
	draw_arc(c, r, 0, TAU, 48, Color(1, 1, 1, 0.22), 3.0)
	draw_circle(c, r * 0.34, Color(1, 1, 1, 0.10))
	var knob := c + value * r * 0.72
	draw_circle(knob, r * 0.30, Palette.TEAL if _active else Palette.CARD_LIGHT)
	draw_circle(knob, r * 0.30, Color(1, 1, 1, 0.35), false, 3.0)
	draw_line(c + Vector2(-8, 0), c + Vector2(8, 0), Color(1, 1, 1, 0.25), 2.0)
	draw_line(c + Vector2(0, -8), c + Vector2(0, 8), Color(1, 1, 1, 0.25), 2.0)
