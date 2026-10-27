class_name GameIcon
extends Control

## Small vector pictograms for the interface. Drawing the glyphs instead of
## relying on an emoji font keeps them identical on every platform and lets the
## first worlds use pictures as the primary language, with text only as support.
##
## The icon is authored on a 24×24 grid and scaled to the control size. Set
## `icon`, `tint` and `weight`, then call `queue_redraw()` (or use `set_icon`).

var icon := "forward"
var tint: Color = Color("#fff8e7")
var weight := 2.2


func _init(p_icon := "forward", p_size := 32.0, p_tint: Color = Color("#fff8e7")) -> void:
	icon = p_icon
	tint = p_tint
	custom_minimum_size = Vector2(p_size, p_size)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	resized.connect(queue_redraw)


func set_icon(p_icon: String, p_tint: Color = tint) -> void:
	icon = p_icon
	tint = p_tint
	queue_redraw()


func _draw() -> void:
	var side := minf(size.x, size.y)
	if side <= 0.0:
		return
	var k := side / 24.0
	var origin := (size - Vector2(24, 24) * k) * 0.5
	match icon:
		"forward":
			_line(origin, k, 12, 20, 12, 6)
			_head(origin, k, 12, 4, 0, -1)
		"right":
			_polyline(origin, k, [Vector2(8, 20), Vector2(8, 11), Vector2(17, 11)])
			_head(origin, k, 20, 11, 1, 0)
		"left":
			_polyline(origin, k, [Vector2(16, 20), Vector2(16, 11), Vector2(7, 11)])
			_head(origin, k, 4, 11, -1, 0)
		"collect":
			_star(origin, k, Vector2(12, 12), 8.4, 3.6, 5)
		"prendi":
			_polyline(origin, k, [Vector2(5, 12), Vector2(5, 19), Vector2(19, 19), Vector2(19, 12)])
			_line(origin, k, 12, 4, 12, 13)
			_head(origin, k, 12, 15, 0, 1)
		"deposita":
			_polyline(origin, k, [Vector2(5, 12), Vector2(5, 19), Vector2(19, 19), Vector2(19, 12)])
			_line(origin, k, 12, 15, 12, 7)
			_head(origin, k, 12, 5, 0, -1)
		"tocca":
			_circle(origin, k, Vector2(12, 9), 2.6, true)
			_arc(origin, k, Vector2(12, 11), 6.0, PI * 0.18, PI * 0.82)
			_arc(origin, k, Vector2(12, 11), 9.0, PI * 0.24, PI * 0.76)
		"attiva":
			_arc(origin, k, Vector2(12, 12), 7.0, -PI * 0.34, PI * 1.34)
			_line(origin, k, 12, 4, 12, 12)
		"accendi", "hint":
			_circle(origin, k, Vector2(12, 9), 5.4, false)
			_line(origin, k, 9.2, 16, 14.8, 16)
			_line(origin, k, 10.2, 19, 13.8, 19)
			_line(origin, k, 12, 1.6, 12, 3.4)
			_line(origin, k, 3.6, 5.6, 5.0, 7.0)
			_line(origin, k, 20.4, 5.6, 19.0, 7.0)
		"apri":
			_rect(origin, k, Rect2(7, 4, 10, 16), false)
			_circle(origin, k, Vector2(14, 12), 1.3, true)
		"foto":
			_rect(origin, k, Rect2(3, 7, 18, 12), false)
			_rect(origin, k, Rect2(9, 4.5, 6, 3), false)
			_circle(origin, k, Vector2(12, 13), 3.8, false)
		"suona":
			_line(origin, k, 14, 5, 14, 17)
			_circle(origin, k, Vector2(11, 17.4), 2.6, true)
			_polyline(origin, k, [Vector2(14, 5), Vector2(19, 7), Vector2(18, 11)])
		"pausa":
			_rect(origin, k, Rect2(7.5, 5, 3.4, 14), true)
			_rect(origin, k, Rect2(13.1, 5, 3.4, 14), true)
		"ripeti":
			_arc(origin, k, Vector2(12, 12), 7.2, -PI * 0.35, PI * 1.15)
			_head(origin, k, 12 + cos(PI * 1.15) * 7.2, 12 + sin(PI * 1.15) * 7.2, -sin(PI * 1.15), cos(PI * 1.15))
		"reset":
			_arc(origin, k, Vector2(12, 12), 7.2, -PI * 0.35, PI * 1.15)
			_head(origin, k, 12 + cos(-PI * 0.35) * 7.2, 12 + sin(-PI * 0.35) * 7.2, sin(-PI * 0.35), -cos(-PI * 0.35))
		"play":
			_fill(origin, k, [Vector2(8, 5), Vector2(19, 12), Vector2(8, 19)])
		"step":
			_fill(origin, k, [Vector2(6, 5), Vector2(16, 12), Vector2(6, 19)])
			_rect(origin, k, Rect2(18, 5, 3, 14), true)
		"view":
			_polyline(origin, k, [Vector2(3, 12), Vector2(8, 7), Vector2(16, 7), Vector2(21, 12), Vector2(16, 17), Vector2(8, 17), Vector2(3, 12)])
			_circle(origin, k, Vector2(12, 12), 3.2, false)
		"zoom_in":
			_circle(origin, k, Vector2(10, 10), 6.2, false)
			_line(origin, k, 14.6, 14.6, 20.5, 20.5)
			_line(origin, k, 7, 10, 13, 10)
			_line(origin, k, 10, 7, 10, 13)
		"zoom_out":
			_circle(origin, k, Vector2(10, 10), 6.2, false)
			_line(origin, k, 14.6, 14.6, 20.5, 20.5)
			_line(origin, k, 7, 10, 13, 10)
		"voice":
			_fill(origin, k, [Vector2(3, 9), Vector2(7, 9), Vector2(11, 5), Vector2(11, 19), Vector2(7, 15), Vector2(3, 15)])
			_arc(origin, k, Vector2(12, 12), 5.0, -PI * 0.3, PI * 0.3)
			_arc(origin, k, Vector2(12, 12), 8.2, -PI * 0.28, PI * 0.28)
		"target":
			_circle(origin, k, Vector2(12, 12), 8.0, false)
			_circle(origin, k, Vector2(12, 12), 4.6, false)
			_circle(origin, k, Vector2(12, 12), 1.7, true)
		"chevron_left":
			_polyline(origin, k, [Vector2(15, 5), Vector2(8, 12), Vector2(15, 19)])
		"chevron_right":
			_polyline(origin, k, [Vector2(9, 5), Vector2(16, 12), Vector2(9, 19)])
		"chevron_up":
			_polyline(origin, k, [Vector2(5, 15), Vector2(12, 8), Vector2(19, 15)])
		"chevron_down":
			_polyline(origin, k, [Vector2(5, 9), Vector2(12, 16), Vector2(19, 9)])
		"close", "cross":
			_line(origin, k, 6, 6, 18, 18)
			_line(origin, k, 18, 6, 6, 18)
		"check":
			_polyline(origin, k, [Vector2(5, 12), Vector2(10, 17), Vector2(19, 7)])
		"plus":
			_line(origin, k, 12, 5, 12, 19)
			_line(origin, k, 5, 12, 19, 12)
		"minus":
			_line(origin, k, 5, 12, 19, 12)
		"trash":
			_line(origin, k, 5, 7, 19, 7)
			_line(origin, k, 9, 4, 15, 4)
			_polyline(origin, k, [Vector2(7, 7), Vector2(8, 20), Vector2(16, 20), Vector2(17, 7)])
			_line(origin, k, 10.5, 10, 10.5, 17)
			_line(origin, k, 13.5, 10, 13.5, 17)
		"code":
			_polyline(origin, k, [Vector2(8, 7), Vector2(3, 12), Vector2(8, 17)])
			_polyline(origin, k, [Vector2(16, 7), Vector2(21, 12), Vector2(16, 17)])
		"menu":
			_line(origin, k, 4, 7, 20, 7)
			_line(origin, k, 4, 12, 20, 12)
			_line(origin, k, 4, 17, 20, 17)
		_:
			_circle(origin, k, Vector2(12, 12), 2.4, true)


# ---------------------------------------------------------------------------
# Drawing helpers (icon coordinates are 0..24, y down)
# ---------------------------------------------------------------------------
func _pt(origin: Vector2, k: float, x: float, y: float) -> Vector2:
	return origin + Vector2(x, y) * k


func _line(origin: Vector2, k: float, ax: float, ay: float, bx: float, by: float) -> void:
	draw_line(_pt(origin, k, ax, ay), _pt(origin, k, bx, by), tint, weight * k, true)


func _polyline(origin: Vector2, k: float, points: Array) -> void:
	var packed := PackedVector2Array()
	for p in points:
		packed.append(_pt(origin, k, p.x, p.y))
	draw_polyline(packed, tint, weight * k, true)


func _fill(origin: Vector2, k: float, points: Array) -> void:
	var packed := PackedVector2Array()
	for p in points:
		packed.append(_pt(origin, k, p.x, p.y))
	draw_colored_polygon(packed, tint)


func _circle(origin: Vector2, k: float, center: Vector2, radius: float, filled: bool) -> void:
	if filled:
		draw_circle(_pt(origin, k, center.x, center.y), radius * k, tint)
	else:
		draw_arc(_pt(origin, k, center.x, center.y), radius * k, 0.0, TAU, 32, tint, weight * k, true)


func _arc(origin: Vector2, k: float, center: Vector2, radius: float, from: float, to: float) -> void:
	draw_arc(_pt(origin, k, center.x, center.y), radius * k, from, to, 28, tint, weight * k, true)


func _rect(origin: Vector2, k: float, r: Rect2, filled: bool) -> void:
	draw_rect(Rect2(_pt(origin, k, r.position.x, r.position.y), r.size * k), tint, filled, -1.0 if filled else weight * k)


func _head(origin: Vector2, k: float, tip_x: float, tip_y: float, dir_x: float, dir_y: float) -> void:
	var dir := Vector2(dir_x, dir_y).normalized()
	var normal := Vector2(-dir.y, dir.x)
	var tip := Vector2(tip_x, tip_y)
	var base := tip - dir * 4.8
	var points := PackedVector2Array([
		_pt(origin, k, tip.x, tip.y),
		_pt(origin, k, base.x + normal.x * 3.1, base.y + normal.y * 3.1),
		_pt(origin, k, base.x - normal.x * 3.1, base.y - normal.y * 3.1),
	])
	draw_colored_polygon(points, tint)


func _star(origin: Vector2, k: float, center: Vector2, outer: float, inner: float, points: int) -> void:
	var packed := PackedVector2Array()
	for i in range(points * 2):
		var radius := outer if i % 2 == 0 else inner
		var angle := -PI * 0.5 + PI * float(i) / float(points)
		packed.append(_pt(origin, k, center.x + cos(angle) * radius, center.y + sin(angle) * radius))
	draw_colored_polygon(packed, tint)
