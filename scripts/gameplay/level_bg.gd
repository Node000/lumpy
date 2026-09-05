extends Node2D
## Non-physical floor/background drawn under the test level. Provides
## contrast and a rough sense of "solid ground" purely visually.

var _time := 0.0


func _ready() -> void:
	z_index = -10
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(-2000, 500, 6000, 1600), Color(0.10, 0.10, 0.14))
	draw_rect(Rect2(-2000, 492, 6000, 8), Color(0.32, 0.32, 0.38))
	for i in range(60):
		var x := -1900 + i * 100.0
		var y := 500.0 + ((i * 37) % 900)
		draw_circle(Vector2(x, y + sin(_time + i) * 4.0), 1.6, Color(0.22, 0.22, 0.28))
