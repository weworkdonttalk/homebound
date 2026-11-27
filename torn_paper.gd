extends Control

const PAPER_COLOR := Color("14130f", 0.96)
const EDGE_COLOR := Color("70634d", 0.42)
const TOP_TEAR := [1.0, -3.0, 4.5, -1.0, 7.0, -4.0, 2.0, 5.5, -3.5, 4.0, -1.0]
const RIGHT_TEAR := [-2.0, 4.5, -1.0, 7.0, -4.5, 2.0, -3.5, 5.0, -1.5]
const BOTTOM_TEAR := [2.0, -4.0, 5.5, -2.0, 3.0, -6.0, 1.0, 4.5, -3.0, 6.0, -1.0]
const LEFT_TEAR := [1.0, -4.0, 3.0, -2.0, 11.0, -5.0, 4.0, -3.0, 2.0]


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	queue_redraw()


func _draw() -> void:
	if size.x < 24.0 or size.y < 24.0:
		return
	var edge := _make_edge()
	var shadow := PackedVector2Array()
	for point in edge:
		shadow.append(point + Vector2(3.0, 4.0))
	draw_colored_polygon(shadow, Color(0.0, 0.0, 0.0, 0.58))
	draw_colored_polygon(edge, PAPER_COLOR)
	var outline := edge.duplicate()
	outline.append(edge[0])
	draw_polyline(outline, EDGE_COLOR, 0.9, true)
	_draw_paper_fibers()
	_draw_folded_corner()


func _make_edge() -> PackedVector2Array:
	var points := PackedVector2Array()
	var left := 12.0
	var right := size.x - 14.0
	var top := 8.0
	var bottom := size.y - 10.0
	for index in range(TOP_TEAR.size()):
		var x := lerpf(left, right, float(index) / float(TOP_TEAR.size() - 1))
		points.append(Vector2(x, top + TOP_TEAR[index]))
	for index in range(RIGHT_TEAR.size()):
		var y := lerpf(top, bottom, float(index + 1) / float(RIGHT_TEAR.size() + 1))
		points.append(Vector2(right + RIGHT_TEAR[index], y))
	for index in range(BOTTOM_TEAR.size() - 1, -1, -1):
		var x := lerpf(left, right, float(index) / float(BOTTOM_TEAR.size() - 1))
		points.append(Vector2(x, bottom + BOTTOM_TEAR[index]))
	for index in range(LEFT_TEAR.size() - 1, -1, -1):
		var y := lerpf(top, bottom, float(index) / float(LEFT_TEAR.size() - 1))
		var notch := 8.0 if index == 4 else 0.0
		points.append(Vector2(left + LEFT_TEAR[index] + notch, y))
	return points


func _draw_paper_fibers() -> void:
	var fiber_color := Color("a08b68", 0.14)
	draw_line(Vector2(size.x * 0.14, size.y * 0.29), Vector2(size.x * 0.31, size.y * 0.25), fiber_color, 1.0, true)
	draw_line(Vector2(size.x * 0.70, size.y * 0.72), Vector2(size.x * 0.87, size.y * 0.76), fiber_color, 1.0, true)
	draw_line(Vector2(size.x * 0.27, size.y * 0.82), Vector2(size.x * 0.40, size.y * 0.79), fiber_color, 1.0, true)
	draw_line(Vector2(size.x * 0.56, size.y * 0.18), Vector2(size.x * 0.67, size.y * 0.21), fiber_color, 1.0, true)


func _draw_folded_corner() -> void:
	var fold := PackedVector2Array([
		Vector2(size.x - 43.0, 8.0),
		Vector2(size.x - 14.0, 12.0),
		Vector2(size.x - 20.0, 34.0),
		Vector2(size.x - 31.0, 24.0),
	])
	draw_colored_polygon(fold, Color("29231a", 0.88))
	draw_polyline(fold, Color("70634d", 0.28), 0.8, true)
