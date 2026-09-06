extends Node2D
## Editor-placed resting glue particles. Drop this node into any level scene,
## position it where the pile should sit, and it asks GluePool to spawn
## `count` resting particles at _ready().
##
## Each particle is a normal pooled GlueBall (own circular collision body,
## swell behaviour, suckable as a resting ball) exactly like before. To keep
## level load snappy the pool does NOT create them in one frame: every spot
## enqueues its particles and GluePool materialises a small batch per frame,
## so even hundreds of particles finish appearing within the first second of
## gameplay instead of hitching the start.

@export_range(1, 24, 1) var count := 1
@export var spread := 10.0  # base radius of the deterministic placement disc

var _spawned: Array[Node] = []


func _ready() -> void:
	if get_tree() == null:
		return
	add_to_group("glue_spot")
	spawn_pile()


func _exit_tree() -> void:
	# Level swap/reload: hand back whatever materialised and cancel the rest so
	# particles of a dead level never linger or spawn into the new one.
	clear_pile()


func spawn_pile() -> void:
	clear_pile()
	var pool := _pool()
	if pool == null:
		return
	var origin := global_position
	for i in count:
		pool.call("request_pile_ball", self, origin + _pile_offset(i, count))


func clear_pile() -> void:
	var pool := _pool()
	if pool != null:
		pool.call("cancel_pile_requests", self)
		for ball in _spawned:
			if is_instance_valid(ball):
				pool.call("release_ball", ball)
	_spawned.clear()


func _pool() -> Node:
	return get_node_or_null("/root/GluePool")


func register_pile_ball(ball: Node) -> void:
	# Called by GluePool when a queued particle materialises.
	_spawned.append(ball)


func get_spawned_count() -> int:
	return _spawned.size()


func _pile_offset(i: int, n: int) -> Vector2:
	# Golden-angle disc layout, same feel as the player's burst.
	if i == 0 or n <= 1:
		return Vector2.ZERO
	var golden := float(i) * 2.39996
	var ring := spread * sqrt(float(i) / float(n - 1))
	return Vector2(cos(golden), sin(golden)) * ring
