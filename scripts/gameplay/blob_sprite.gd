class_name BlobSprite
extends Node2D
## Static, solid visual for a pooled glue ball.

var color := Color(1, 1, 1, 1)
var base_radius := 6.0


func _ready() -> void:
	z_index = 0
	queue_redraw()


func set_tint(c: Color) -> void:
	color = c
	queue_redraw()


func set_radius(value: float) -> void:
	base_radius = maxf(value, 0.1)
	queue_redraw()


func _draw() -> void:
	draw_circle(Vector2.ZERO, base_radius, color)
