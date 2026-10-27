class_name TouchControls
extends Control

## Touch HUD: analog stick on the left, camera actions on the right.
## Every control is at least 56 px tall and labelled in Italian, so the HUD
## remains usable on a classroom touch screen without a keyboard.

signal move(direction: Vector2)
signal camera_cycle
signal recenter

var joystick: TouchJoystick
var camera_button: Button
var recenter_button: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	joystick = TouchJoystick.new()
	joystick.name = "Joystick"
	joystick.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	joystick.offset_left = 26
	joystick.offset_top = -216
	joystick.offset_right = 216
	joystick.offset_bottom = -26
	joystick.moved.connect(func(v: Vector2): move.emit(v))
	add_child(joystick)

	var column := Palette.vbox(10)
	column.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	column.offset_left = -250
	column.offset_top = -206
	column.offset_right = -26
	column.offset_bottom = -26
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)

	camera_button = Palette.button("VISTA 3D", Palette.PURPLE, 18)
	camera_button.custom_minimum_size = Vector2(224, 58)
	camera_button.pressed.connect(func(): camera_cycle.emit())
	column.add_child(camera_button)

	recenter_button = Palette.ghost_button("CENTRA", 18)
	recenter_button.custom_minimum_size = Vector2(224, 58)
	recenter_button.pressed.connect(func(): recenter.emit())
	column.add_child(recenter_button)


func set_camera_name(text: String) -> void:
	camera_button.text = text
