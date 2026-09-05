extends Node2D
## Editor-placed resting glue particles. Drop this into any level scene,
## position it where the pile should sit, and it spawns `count` resting
## particles from the pool at _ready() so the player can suck them up.
## Pure placement: particles go to State.STUCK immediately (no flight).

@export_range(1, 24, 1) var count := 1
@export var spread := 10.0  # base radius of the deterministic placement disc

var _spawned: Array[Node] = []


func _ready() -> void:
	if get_tree() != null:
		spawn_pile.call_deferred()


func spawn_pile() -> void:
	_clear_pile()
	for i in count:
		var ball: Node = GluePool.take_ball()
		if ball == null:
			break
		ball.global_position = global_position + _pile_offset(i, count)
		ball.call("place_at_rest")
		_spawned.append(ball)


func clear_pile() -> void:
	_clear_pile()


func _clear_pile() -> void:
	for ball in _spawned:
		if is_instance_valid(ball):
			GluePool.release_ball(ball)
	_spawned.clear()


func get_spawned_count() -> int:
	return _spawned.size()


func _pile_offset(i: int, n: int) -> Vector2:
	# Golden-angle disc layout, same feel as the player's burst.
	if i == 0 or n <= 1:
		return Vector2.ZERO
	var golden := float(i) * 2.39996
	var ring := spread * sqrt(float(i) / float(n - 1))
	return Vector2(cos(golden), sin(golden)) * ring
