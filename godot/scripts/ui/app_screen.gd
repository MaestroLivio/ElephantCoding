class_name AppScreen
extends Control

## Base class for every full-screen view. Screens own their UI and may push a
## single Node3D stage into the shared SubViewport owned by Main.

signal navigate(screen_name: String, args: Dictionary)

var app: Node
var args: Dictionary = {}
var stage_root: Node3D


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func attach(p_app: Node, p_args: Dictionary) -> void:
	app = p_app
	args = p_args


func build() -> void:
	pass


func enter() -> void:
	pass


func leave() -> void:
	pass


func go(screen_name: String, p_args: Dictionary = {}) -> void:
	navigate.emit(screen_name, p_args)


func use_stage(node: Node3D) -> void:
	stage_root = node
	if app != null:
		app.set_stage(node)


func toast(message: String, seconds := 3.2, tint: Color = Palette.CREAM) -> void:
	if app != null and app.has_method("show_toast"):
		app.show_toast(message, seconds, tint)
