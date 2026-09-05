extends StaticBody2D
## Test level wall. "Smooth" walls are spawned on layer 2 (bit 2 = wall_smooth)
## so flying glue reflects; rough walls live on layer 1.

var smooth := false


func _draw() -> void:
	var shape := get_node_or_null("Shape")
	if shape == null or shape.shape == null:
		return
	var rect := shape.shape as RectangleShape2D
	if rect == null:
		return
	var fill := Color(0.17, 0.22, 0.30, 1.0) if smooth else Color(0.25, 0.17, 0.20, 1.0)
	var edge := Color(0.42, 0.78, 0.86, 1.0) if smooth else Color(0.86, 0.42, 0.50, 1.0)
	draw_rect(Rect2(-rect.size * 0.5, rect.size), fill)
	draw_line(Vector2(-rect.size.x * 0.5, -rect.size.y * 0.5), Vector2(rect.size.x * 0.5, -rect.size.y * 0.5), edge, 2.0)
	draw_line(Vector2(-rect.size.x * 0.5, rect.size.y * 0.5), Vector2(rect.size.x * 0.5, rect.size.y * 0.5), edge, 2.0)
	if smooth:
		for x in range(int(-rect.size.x * 0.5 + 12.0), int(rect.size.x * 0.5), 18):
			draw_line(Vector2(x, -rect.size.y * 0.5), Vector2(x + 10, rect.size.y * 0.5), Color(0.55, 0.9, 0.95, 0.45), 1.0)


func _ready() -> void:
	collision_layer = 2 if smooth else 1
	collision_mask = 1 | 2 | 4 | 8 | 16
