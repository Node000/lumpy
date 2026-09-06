extends Node
## Pool of GlueBall scene instances. Autoload singleton "GluePool".
## Players pull balls with take_ball(), give them back with release_ball().
##
## Editor-placed glue spots (glue_spot.gd) do not materialise their particles
## all at once on level load: they enqueue them here and _process() turns a
## small batch per frame into real resting balls, so a level with hundreds of
## placed glue particles finishes spawning within roughly the first second
## instead of hitching the first frames.

const BALL_SCENE := "res://scenes/gameplay/glue_ball.tscn"
const POOL_LIMIT := 200
const PILE_SPAWNS_PER_FRAME := 24  # ~1440 particles/second at 60 fps

var _available: Array[Node] = []
var _busy: Array[Node] = []
var _ball_scene: PackedScene
var _pending_piles: Array = []  # each entry: [spot: Node, world_pos: Vector2]


func _ready() -> void:
	_ball_scene = load(BALL_SCENE)
	if _ball_scene == null:
		push_error("GluePool: missing glue_ball scene at " + BALL_SCENE)
		return
	for i in POOL_LIMIT:
		_spawn_ball()


func _process(_delta: float) -> void:
	if _pending_piles.is_empty():
		return
	var batch := mini(PILE_SPAWNS_PER_FRAME, _pending_piles.size())
	for i in batch:
		_spawn_one_pile_ball()


func request_pile_ball(spot: Node, world_pos: Vector2) -> void:
	_pending_piles.append([spot, world_pos])


func cancel_pile_requests(spot: Node) -> void:
	for i in range(_pending_piles.size() - 1, -1, -1):
		if _pending_piles[i][0] == spot:
			_pending_piles.remove_at(i)


func get_pending_pile_count() -> int:
	return _pending_piles.size()


func _spawn_one_pile_ball() -> void:
	var entry: Array = _pending_piles.pop_front()
	var spot: Node = entry[0]
	if not is_instance_valid(spot):
		return
	var ball := take_ball()
	if ball == null:
		return
	ball.global_position = entry[1]
	ball.call("place_at_rest")
	spot.call("register_pile_ball", ball)


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
