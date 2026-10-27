class_name Palette
extends RefCounted

## Shared visual language for ElephantCoding. High contrast, large targets,
## colour + shape + text (never colour alone).

const BG := Color("#0f1b2d")
const BG_2 := Color("#16263d")
const CARD := Color("#1e3350")
const CARD_LIGHT := Color("#274468")
const CREAM := Color("#fff8e7")
const INK := Color("#102033")
const MUTED := Color("#a9bdd6")
const CORAL := Color("#ff6b57")
const TEAL := Color("#2ec4b6")
const YELLOW := Color("#ffd166")
const PURPLE := Color("#8d7bf6")
const GREEN := Color("#8ac926")
const BLUE := Color("#4cc9f0")
const RED := Color("#ef476f")
const WHITE := Color("#ffffff")


static func style(bg: Color, radius := 18, border: Color = Color.TRANSPARENT, border_width := 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.corner_radius_top_left = radius
	s.corner_radius_top_right = radius
	s.corner_radius_bottom_left = radius
	s.corner_radius_bottom_right = radius
	if border_width > 0:
		s.border_width_left = border_width
		s.border_width_top = border_width
		s.border_width_right = border_width
		s.border_width_bottom = border_width
		s.border_color = border
	s.content_margin_left = 22
	s.content_margin_right = 22
	s.content_margin_top = 16
	s.content_margin_bottom = 16
	s.shadow_color = Color(0, 0, 0, 0.25)
	s.shadow_size = 10
	s.shadow_offset = Vector2(0, 5)
	return s


static func panel(bg: Color = CARD, radius := 18, border: Color = Color.TRANSPARENT, bw := 0) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", style(bg, radius, border, bw))
	return p


static func label(text: String, size := 20, color: Color = CREAM, wrap := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF
	return l


static func title(text: String, size := 46) -> Label:
	var l := label(text, size, CREAM)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.35))
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", 2)
	return l


static func button(text: String, bg: Color = CORAL, size := 20, min_width := 0) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	b.custom_minimum_size = Vector2(min_width, 56 if size >= 20 else 48)
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_color_override("font_color", INK if bg.get_luminance() > 0.55 else WHITE)
	b.add_theme_color_override("font_hover_color", INK if bg.get_luminance() > 0.55 else WHITE)
	b.add_theme_color_override("font_pressed_color", INK if bg.get_luminance() > 0.55 else WHITE)
	b.add_theme_color_override("font_focus_color", CREAM)
	b.add_theme_stylebox_override("normal", style(bg, 14))
	b.add_theme_stylebox_override("hover", style(bg.lightened(0.08), 14, CREAM, 2))
	b.add_theme_stylebox_override("pressed", style(bg.darkened(0.12), 14))
	b.add_theme_stylebox_override("focus", style(bg, 14, YELLOW, 3))
	b.add_theme_stylebox_override("disabled", style(Color("#41536b"), 14))
	return b


static func ghost_button(text: String, size := 18) -> Button:
	var b := button(text, CARD_LIGHT, size)
	b.add_theme_color_override("font_color", CREAM)
	b.add_theme_stylebox_override("normal", style(CARD_LIGHT, 14, Color(1, 1, 1, 0.14), 1))
	return b


static func chip(text: String, bg: Color = CARD_LIGHT, color: Color = CREAM) -> PanelContainer:
	var p := PanelContainer.new()
	var s := style(bg, 999)
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	s.shadow_size = 0
	p.add_theme_stylebox_override("panel", s)
	var l := label(text, 15, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	p.add_child(l)
	return p


static func progress_bar(value: float, tint: Color = TEAL) -> ProgressBar:
	var p := ProgressBar.new()
	p.custom_minimum_size = Vector2(120, 12)
	p.max_value = 1.0
	p.value = clampf(value, 0, 1)
	p.show_percentage = false
	p.add_theme_stylebox_override("background", style(Color(1, 1, 1, 0.12), 999))
	p.add_theme_stylebox_override("fill", style(tint, 999))
	return p


static func scroll() -> ScrollContainer:
	var s := ScrollContainer.new()
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return s


static func spacer(h := 12.0) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c


static func vbox(separation := 12) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", separation)
	return v


static func hbox(separation := 12) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", separation)
	return h
