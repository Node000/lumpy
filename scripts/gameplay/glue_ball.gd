extends CharacterBody2D
## A glue ball. State machine on top of a CharacterBody2D so a resting ball is
## just a non-moving body the player can stand on. Flying balls move
## manually with move_and_collide and read the collided body's layer:
##   wall_smooth -> reflect along the surface and keep flying
##   anything else (rough wall or another glue ball) -> come to rest
## A resting ball elastically swells (visual + collision) after a short delay
## unless it is being collected.
## SUCK state disables every collision and pulls the ball directly toward the
## player who owns it.

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
var _pool_active := true
var _stuck_time := 0.0
var _swelling := false
var _swell_anim_t := 0.0
var _has_swelled := false


func _ready() -> void:
	add_to_group("glue_ball")
	collision_layer = LAYER_GLUE_FLY
	_apply_state_mask(State.FLY)
	if not is_in_group("glue_ball"):
		add_to_group("glue_ball")
	# The scene's CircleShape2D is shared across instances, so every ball
	# duplicates it: per-ball radius changes (swell, reset) must never leak
	# into other balls that reuse the same packed scene resource.
	_shape = _colshape.shape.duplicate()
	_colshape.shape = _shape
	_blob.set_radius(GameTuning.glue_ball_radius)
	_blob.set_tint(Color(1, 1, 1, 0.95))
	if _shape != null:
		_shape.radius = GameTuning.glue_ball_collision_radius


func set_pool_active(active: bool) -> void:
	_pool_active = active
	if _colshape == null:
		return
	if not active:
		collision_layer = 0
		collision_mask = 0
		_set_collision_disabled(true)
	else:
		_apply_state_mask(state)


func _apply_state_mask(s: int) -> void:
	match s:
		State.FLY:
			collision_layer = LAYER_GLUE_FLY
			collision_mask = LAYER_ROUGH | LAYER_SMOOTH | LAYER_GLUE_REST
		State.STUCK:
			collision_layer = LAYER_GLUE_REST
			collision_mask = LAYER_PLAYER | LAYER_GLUE_REST | LAYER_GLUE_FLY
		State.SUCK:
			collision_layer = 0
			collision_mask = 0
	_set_collision_disabled(not _pool_active or s == State.SUCK)


func _set_collision_disabled(disabled: bool) -> void:
	if _colshape != null:
		_colshape.set_deferred("disabled", disabled)


func reset_ball() -> void:
	state = State.FLY
	fly_velocity = Vector2.ZERO
	owner_player = null
	_fly_time = 0.0
	_stuck_time = 0.0
	_swelling = false
	_swell_anim_t = 0.0
	_has_swelled = false
	_blob.modulate = Color(1, 1, 1, 1)
	_blob.scale = Vector2.ONE
	if _shape != null:
		_shape.radius = GameTuning.glue_ball_collision_radius
	if _pool_active:
		_apply_state_mask(State.FLY)
	else:
		collision_layer = 0
		collision_mask = 0
		_set_collision_disabled(true)


func begin_fly(from: Vector2, dir: Vector2, speed: float) -> void:
	global_position = from
	fly_velocity = dir * speed
	state = State.FLY
	_fly_time = 0.0
	_stuck_time = 0.0
	_swelling = false
	_swell_anim_t = 0.0
	_has_swelled = false
	_blob.modulate = Color(1, 1, 1, 1)
	_blob.scale = Vector2.ONE
	if _shape != null:
		_shape.radius = GameTuning.glue_ball_collision_radius
	_apply_state_mask(State.FLY)


func begin_suck(target_player: Node2D) -> void:
	state = State.SUCK
	owner_player = target_player
	_apply_state_mask(State.SUCK)


func place_at_rest() -> void:
	state = State.STUCK
	_stuck_time = 0.0
	_swelling = false
	_swell_anim_t = 0.0
	_has_swelled = false
	_apply_state_mask(State.STUCK)
	_blob.modulate = Color(1, 1, 1, 1)
	_blob.scale = Vector2.ONE
	if _shape != null:
		_shape.radius = GameTuning.glue_ball_collision_radius


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
	var col := move_and_collide(motion)
	if col:
		var collider := col.get_collider()
		if collider is CollisionObject2D and (collider.collision_layer & LAYER_SMOOTH) != 0:
			# Smooth wall: reflect the velocity and keep going (with a small push-out)
			fly_velocity = fly_velocity.bounce(col.get_normal())
			global_position += col.get_normal() * 0.5
		else:
			# Independent landing: stop exactly at its own contact point with a
			# small settle-off. No scatter, no sidestep.
			var normal := col.get_normal()
			global_position += normal * (GameTuning.glue_ball_collision_radius * 0.5)
			_go_stuck()


func _go_stuck() -> void:
	state = State.STUCK
	_stuck_time = 0.0
	_swelling = false
	_swell_anim_t = 0.0
	_has_swelled = false
	_apply_state_mask(State.STUCK)
	_blob.modulate = Color(1, 1, 1, 1)
	_blob.scale = Vector2.ONE
	if _shape != null:
		_shape.radius = GameTuning.glue_ball_collision_radius


func _physics_stuck(delta: float) -> void:
	_stuck_time += delta
	if not _swelling and not _has_swelled and _stuck_time >= GameTuning.glue_swell_delay:
		_swelling = true
		_swell_anim_t = 0.0
	if _swelling:
		_swell_anim_t += delta
		# Elastic swell: overshoot the target then bounce back, exactly once.
		# After it completes the ball keeps its final size and never starts
		# another swell (no lingering bounce).
		var eased := _elastic_out(clampf(_swell_anim_t / GameTuning.glue_swell_anim_time, 0.0, 1.0))
		var factor := lerpf(1.0, GameTuning.glue_swell_scale, eased)
		if _blob != null:
			_blob.scale = Vector2.ONE * factor
		if _shape != null:
			_shape.radius = GameTuning.glue_ball_collision_radius * factor
		if _swell_anim_t >= GameTuning.glue_swell_anim_time:
			_swelling = false
			_has_swelled = true
			if _blob != null:
				_blob.scale = Vector2.ONE * GameTuning.glue_swell_scale
			if _shape != null:
				_shape.radius = GameTuning.glue_ball_collision_radius * GameTuning.glue_swell_scale


func _elastic_out(t: float) -> float:
	# t=0 -> 0, t=1 -> 1, with one overshoot past 1 and a settle-back.
	var c4 := 2.0 * PI / 3.0
	if t == 0.0:
		return 0.0
	if t == 1.0:
		return 1.0
	return pow(2.0, -10.0 * t) * sin((t * 10.0 - 0.75) * c4) + 1.0


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
