extends CharacterBody2D
## A glue ball. State machine on top of a CharacterBody2D so a resting ball is
## just a non-moving body the player can stand on. Flying balls move
## manually with move_and_collide and read the collided body's layer:
##   wall_smooth -> reflect along the surface and keep flying
##   anything else (rough wall or another glue ball) -> come to rest
## After glue_swell_delay seconds a resting ball swells its visuals (and
## collision grows a little) unless it is being collected.
## SUCK state pulls the ball toward the player who owns it.

enum State { FLY, STUCK, SUCK }

const LAYER_ROUGH := 1
const LAYER_SMOOTH := 2
const LAYER_GLUE_REST := 4
const LAYER_GLUE_FLY := 8
const LAYER_PLAYER := 16

@onready var _blob: BlobSprite = $Visual/GlueBody
@onready var _colshape: CollisionShape2D = $Collision
@onready var _shape: CircleShape2D = _colshape.shape
@onready var _visual: Node2D = $Visual

var state: int = State.FLY
var owner_player: Node2D = null
var fly_velocity := Vector2.ZERO

var _fly_time := 0.0
var _stuck_time := 0.0
var _swelling := false
var _swell_anim_t := 0.0


func _ready() -> void:
	add_to_group("glue_ball")
	collision_layer = LAYER_GLUE_FLY
	_apply_state_mask(State.FLY)
	if not is_in_group("glue_ball"):
		add_to_group("glue_ball")
	_blob.base_radius = GameTuning.glue_ball_radius
	_blob.ring_pulse = false
	_blob.color = Color(1, 1, 1, 0.95)
	if _shape != null:
		_shape.radius = GameTuning.glue_ball_collision_radius


func set_pool_active(active: bool) -> void:
	if _colshape == null:
		return
	_colshape.set_deferred("disabled", not active)
	if not active:
		collision_layer = 0
		collision_mask = 0
	else:
		_apply_state_mask(state)


func _apply_state_mask(s: int) -> void:
	match s:
		State.FLY:
			collision_layer = LAYER_GLUE_FLY
			collision_mask = LAYER_ROUGH | LAYER_SMOOTH | LAYER_GLUE_REST | LAYER_GLUE_FLY
		State.STUCK:
			collision_layer = LAYER_GLUE_REST
			collision_mask = LAYER_PLAYER | LAYER_GLUE_REST | LAYER_GLUE_FLY
		State.SUCK:
			collision_layer = LAYER_GLUE_FLY
			collision_mask = 0


func reset_ball() -> void:
	state = State.FLY
	fly_velocity = Vector2.ZERO
	owner_player = null
	_fly_time = 0.0
	_stuck_time = 0.0
	_swelling = false
	_swell_anim_t = 0.0
	_blob.ring_pulse = false
	_blob.target_scale = 1.0
	_blob.set_velocity(Vector2.ZERO)
	_blob.modulate = Color(1, 1, 1, 1)
	_apply_state_mask(State.FLY)


func begin_fly(from: Vector2, dir: Vector2, speed: float) -> void:
	global_position = from
	fly_velocity = dir * speed
	state = State.FLY
	_fly_time = 0.0
	_blob.target_scale = 1.0
	_blob.set_velocity(fly_velocity)
	_blob.modulate = Color(1, 1, 1, 1)
	_apply_state_mask(State.FLY)


func begin_suck(target_player: Node2D) -> void:
	state = State.SUCK
	owner_player = target_player
	_blob.ring_pulse = false
	_blob.set_velocity(Vector2.ZERO)
	# A sucked ball still needs to stop if the player moves behind a wall.
	# We perform the wall segment test explicitly below so the ball itself does
	# not push the player or get caught by the player's collision shape.
	_apply_state_mask(State.SUCK)


func place_at_rest() -> void:
	state = State.STUCK
	_stuck_time = 0.0
	_swell_anim_t = 0.0
	_swelling = false
	_apply_state_mask(State.STUCK)
	_blob.ring_pulse = false
	_blob.modulate = Color(1, 1, 1, 1)
	_blob.target_scale = 1.0
	_blob.set_velocity(Vector2.ZERO)


func _physics_process(delta: float) -> void:
	match state:
		State.FLY:
			_physics_fly(delta)
		State.STUCK:
			_physics_stuck(delta)
		State.SUCK:
			_physics_suck(delta)


func _physics_fly(delta: float) -> void:
	_fly_time += delta
	if _fly_time > GameTuning.glue_fly_timeout:
		_go_stuck()
		return
	var motion := fly_velocity * delta
	if _blob != null:
		_blob.set_velocity(fly_velocity)
	var col := move_and_collide(motion)
	if col:
		var collider := col.get_collider()
		if collider is CollisionObject2D and (collider.collision_layer & LAYER_SMOOTH) != 0:
			# Smooth wall: reflect the velocity and keep going (with a small push-out)
			fly_velocity = fly_velocity.bounce(col.get_normal())
			global_position += col.get_normal() * 0.5
		else:
			_go_stuck()
			return


func _go_stuck() -> void:
	state = State.STUCK
	_stuck_time = 0.0
	_swell_anim_t = 0.0
	_swelling = false
	_apply_state_mask(State.STUCK)
	_blob.ring_pulse = true
	_blob.modulate = Color(1, 1, 1, 1)


func _physics_stuck(_delta: float) -> void:
	_stuck_time += _delta
	if not _swelling and _stuck_time >= GameTuning.glue_swell_delay:
		_swelling = true
		_swell_anim_t = 0.0
	if _swelling:
		_swell_anim_t += _delta
		var t := clampf(_swell_anim_t / GameTuning.glue_swell_anim_time, 0.0, 1.0)
		var eased := 1.0 - pow(1.0 - t, 3.0)
		if _blob != null:
			_blob.target_scale = lerpf(1.0, GameTuning.glue_swell_scale, eased)
		if _shape != null:
			_shape.radius = GameTuning.glue_ball_collision_radius * lerpf(1.0, GameTuning.glue_swell_collision_factor, eased)
		if t >= 1.0:
			_swelling = false
			_blob.ring_pulse = false
	queue_redraw()


func _physics_suck(delta: float) -> void:
	if not is_instance_valid(owner_player):
		_go_stuck()
		return
	var to := owner_player.global_position
	var diff := to - global_position
	if diff.length_squared() < 4.0:
		_collect()
		return
	var step := diff.normalized() * minf(GameTuning.suck_speed * delta, diff.length())
	_blob.set_velocity(step / maxf(delta, 0.0001))
	var ray := PhysicsRayQueryParameters2D.create(global_position, global_position + step, LAYER_ROUGH | LAYER_SMOOTH)
	ray.exclude = [get_rid(), owner_player.get_rid()]
	var hit := get_world_2d().direct_space_state.intersect_ray(ray)
	if not hit.is_empty():
		# Suction cannot pull through a wall. The ball becomes a new resting ball
		# at the first blocked point instead of teleporting through the obstacle.
		global_position = hit.get("position", global_position)
		_go_stuck()
		return
	global_position += step
	if global_position.distance_to(to) < 3.0:
		_collect()


func _collect() -> void:
	var player := owner_player
	if is_instance_valid(player) and player.has_method("notify_ball_collected"):
		player.call("notify_ball_collected", self)
	GluePool.release_ball(self)
	if is_instance_valid(player):
		player.call("add_glue_from_ball")


func set_glue_color(c: Color) -> void:
	if _blob != null:
		_blob.set_tint(c)

