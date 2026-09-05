class_name FacingVertex
extends CanvasItem
## Tiny CanvasItem that publishes where an octopus blob should look at, and
## how its two feet are planted. Kept transparent so builds stay self-contained.

var look_position := Vector2.ZERO
var foot_left := Vector2.ZERO
var foot_right := Vector2.ZERO
var is_wobbling := false


func set_params(_color: Color) -> void:
	pass


func _draw() -> void:
	pass
