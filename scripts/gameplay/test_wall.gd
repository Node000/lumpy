extends StaticBody2D
## Test level wall. "Smooth" walls are spawned on layer 2 (bit 2 = wall_smooth)
## so flying glue reflects; rough walls live on layer 1.

var smooth := false


func _draw() -> void:
	var shape_node := get_node_or_null("Shape")
	if shape_node == null or shape_node.shape == null:
		return
	var rect := shape_node.shape as RectangleShape2D
	if rect == null:
		return
	# Draw the wall exactly where its collision actually is: use the Shape
	# child's local transform (position/rotation) in this node's space. The
	# node's own scale is applied by the canvas transform as usual, matching
	# the collision body's world-space footprint.
	var tf: Transform2D = shape_node.transform
	var half := rect.size * 0.5
	var corners := PackedVector2Array([
		tf * Vector2(-half.x, -half.y),
		tf * Vector2(half.x, -half.y),
		tf * Vector2(half.x, half.y),
		tf * Vector2(-half.x, half.y),
	])
	var fill := Color(0.17, 0.22, 0.30, 1.0) if smooth else Color(0.25, 0.17, 0.20, 1.0)
	var edge := Color(0.42, 0.78, 0.86, 1.0) if smooth else Color(0.86, 0.42, 0.50, 1.0)
	draw_colored_polygon(corners, fill)
	draw_polyline(PackedVector2Array([corners[0], corners[1], corners[2], corners[3], corners[0]]), edge, 2.0, true)
	if smooth:
		var along := corners[1] - corners[0]
		var down := (corners[3] - corners[0]) * 0.85
		var steps := maxi(3, int(along.length() / 18.0))
		for i in steps + 1:
			var base := corners[0] + along * (float(i) / steps)
			draw_line(base, base + down, Color(0.55, 0.9, 0.95, 0.45), 1.0)


func _ready() -> void:
	collision_layer = 2 if smooth else 1
	collision_mask = 1 | 2 | 4 | 8 | 16
