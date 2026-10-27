extends Control

## Application shell: owns the shared 3D viewport, the UI layer, the screen
## router and global services (settings, profiles, narration).

const SCREEN_SCRIPTS := {
	"menu": preload("res://scripts/ui/menu_screen.gd"),
	"worlds": preload("res://scripts/ui/world_select_screen.gd"),
	"hub": preload("res://scripts/ui/hub_screen.gd"),
	"mission": preload("res://scripts/ui/mission_screen.gd"),
	"lab": preload("res://scripts/ui/lab_screen.gd"),
	"settings": preload("res://scripts/ui/settings_screen.gd"),
	"teacher": preload("res://scripts/ui/teacher_screen.gd"),
	"credits": preload("res://scripts/ui/credits_screen.gd"),
}

var viewport: SubViewport
var stage_container: SubViewportContainer
var ui_layer: Control
var screen_layer: Control
var overlay_layer: Control
var current: AppScreen
var current_name := ""
var screen_history: Array = []

var _toast: PanelContainer
var _toast_label: Label
var _toast_tween: Tween
var _fade: ColorRect
var _contrast: ColorRect


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	MissionRepository.load_all()
	_build_shell()
	_apply_theme()
	GameState.settings_changed.connect(_on_settings_changed)
	show_screen("menu")


func _build_shell() -> void:
	stage_container = SubViewportContainer.new()
	stage_container.name = "Stage"
	stage_container.stretch = true
	stage_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stage_container)

	viewport = SubViewport.new()
	viewport.name = "StageViewport"
	viewport.own_world_3d = true
	viewport.transparent_bg = false
	viewport.handle_input_locally = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.size = Vector2i(1600, 900)
	viewport.msaa_3d = Viewport.MSAA_2X
	viewport.msaa_2d = Viewport.MSAA_2X
	viewport.positional_shadow_atlas_size = 2048
	stage_container.add_child(viewport)

	ui_layer = Control.new()
	ui_layer.name = "UI"
	ui_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ui_layer)

	screen_layer = Control.new()
	screen_layer.name = "Screens"
	screen_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(screen_layer)

	overlay_layer = Control.new()
	overlay_layer.name = "Overlay"
	overlay_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(overlay_layer)

	_contrast = ColorRect.new()
	_contrast.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_contrast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_contrast.visible = false
	var shader := Shader.new()
	shader.code = """shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
void fragment() {
	vec3 c = texture(screen_texture, SCREEN_UV).rgb;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(l), c, 1.25);
	c = clamp((c - 0.5) * 1.22 + 0.5, 0.0, 1.0);
	COLOR = vec4(c, 1.0);
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	_contrast.material = mat
	overlay_layer.add_child(_contrast)

	_fade = ColorRect.new()
	_fade.color = Color(Palette.BG.r, Palette.BG.g, Palette.BG.b, 0.0)
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay_layer.add_child(_fade)

	_build_toast()


func _build_toast() -> void:
	_toast = PanelContainer.new()
	_toast.add_theme_stylebox_override("panel", Palette.style(Color("#102033"), 16, Palette.YELLOW, 2))
	_toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_toast.offset_left = -320
	_toast.offset_right = 320
	_toast.offset_top = 92
	_toast.custom_minimum_size = Vector2(0, 54)
	_toast.modulate.a = 0.0
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay_layer.add_child(_toast)
	_toast_label = Palette.label("", 19, Palette.CREAM)
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_toast.add_child(_toast_label)


func set_stage(node: Node3D) -> void:
	if viewport == null:
		return
	for c in viewport.get_children():
		c.queue_free()
	if node != null:
		viewport.add_child(node)


func clear_stage() -> void:
	set_stage(null)


func show_screen(screen_name: String, p_args: Dictionary = {}) -> void:
	if not SCREEN_SCRIPTS.has(screen_name):
		push_error("Schermata sconosciuta: " + screen_name)
		return
	if current != null:
		current.leave()
		screen_history.append(current_name)
		current.queue_free()
		current = null
	clear_stage()
	await _fade_out()
	current_name = screen_name
	var script: Script = SCREEN_SCRIPTS[screen_name]
	var screen: AppScreen = script.new()
	screen.name = "Screen_" + screen_name
	screen.attach(self, p_args)
	screen.navigate.connect(_on_navigate)
	screen_layer.add_child(screen)
	current = screen
	screen.build()
	screen.enter()
	_fade_in()


func go_back(fallback := "menu") -> void:
	var target := fallback
	if not screen_history.is_empty():
		target = screen_history.pop_back()
	show_screen(target)


func _on_navigate(screen_name: String, p_args: Dictionary) -> void:
	show_screen(screen_name, p_args)


func show_toast(message: String, seconds := 3.2, tint: Color = Palette.CREAM) -> void:
	if _toast == null:
		return
	_toast_label.text = message
	_toast_label.add_theme_color_override("font_color", tint)
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast.modulate.a = 1.0
	_toast_tween = create_tween()
	_toast_tween.tween_interval(maxf(1.0, seconds))
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.35)


func _fade_out() -> void:
	if _fade == null:
		return
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, 0.12)
	await tw.finished


func _fade_in() -> void:
	if _fade == null:
		return
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 0.0, 0.20)
	tw.tween_callback(func(): _fade.mouse_filter = Control.MOUSE_FILTER_IGNORE)


func _apply_theme() -> void:
	var theme := Theme.new()
	theme.default_font_size = 22 if bool(GameState.get_setting("large_controls", true)) else 18
	ui_layer.theme = theme
	if _contrast != null:
		_contrast.visible = bool(GameState.get_setting("high_contrast", false))


func _on_settings_changed() -> void:
	_apply_theme()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F11:
			var mode := DisplayServer.window_get_mode()
			if mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			else:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
			get_viewport().set_input_as_handled()
