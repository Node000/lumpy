extends Node2D
## Player test level controller. Spawns a few free glue balls resting on the
## floor so right-click suck has something to grab without spitting first.

var player: Node2D = null


func set_player(value: Node2D) -> void:
	player = value


func _ready() -> void:
	if player == null:
		player = get_parent().get_node_or_null("Player")
	# The level owns the preallocated pool balls for this test session.
	_spawn_free_glue()


func _spawn_free_glue() -> void:
	var x := 320.0
	for i in 4:
		var ball: Node = GluePool.take_ball()
		if ball == null:
			continue
		ball.global_position = Vector2(x, 462.0)
		ball.call("place_at_rest")
		x += 60.0


func clear_free_glue() -> void:
	for ball in GluePool.get_busy_list():
		GluePool.release_ball(ball)
