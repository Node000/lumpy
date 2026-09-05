extends Node
## Pool of GlueBall scene instances. Autoload singleton "GluePool".
## Players pull balls with take_ball(), give them back with release_ball().

const BALL_SCENE := "res://scenes/gameplay/glue_ball.tscn"
const POOL_LIMIT := 200

var _available: Array[Node] = []
var _busy: Array[Node] = []
var _ball_scene: PackedScene


func _ready() -> void:
	_ball_scene = load(BALL_SCENE)
	if _ball_scene == null:
		push_error("GluePool: missing glue_ball scene at " + BALL_SCENE)
		return
	for i in POOL_LIMIT:
		_spawn_ball()


func _spawn_ball() -> Node:
	if _ball_scene == null:
		return null
	var ball := _ball_scene.instantiate()
	ball.name = "PooledGlue"
	ball.visible = false
	ball.set_process(false)
	ball.set_physics_process(false)
	add_child(ball)
	ball.call("set_pool_active", false)
	_available.append(ball)
	return ball


func take_ball() -> Node:
	if _available.is_empty():
		var spawned := _spawn_ball()
		if spawned == null:
			return null
	var ball: Node = _available.pop_back()
	ball.visible = true
	ball.set_process(true)
	ball.set_physics_process(true)
	ball.call("set_pool_active", true)
	_busy.append(ball)
	return ball


func release_ball(ball: Node) -> void:
	if not _busy.has(ball):
		return
	_busy.erase(ball)
	ball.visible = false
	ball.set_process(false)
	ball.set_physics_process(false)
	ball.call("set_pool_active", false)
	ball.call("reset_ball")
	_available.append(ball)


func get_busy_count() -> int:
	return _busy.size()


func get_busy_list() -> Array[Node]:
	return _busy.duplicate()
