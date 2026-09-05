extends CharacterBody2D
## Lumpy the glue core: movement + variable-height jump (coyote + jump buffer),
## spit/suck glue, body radius growth from carried glue, and the glue->jump
## height mapping. All tunables live on the GameTuning autoload.
##
## Collision layers (bit values):
##   1 = wall_rough, 2 = wall_smooth, 4 = glue_rest, 8 = glue_fly, 16 = player

signal glue_changed(count: int)

const LAYER_ROUGH := 1
const LAYER_SMOOTH := 2
const LAYER_GLUE_REST := 4
const LAYER_GLUE_FLY := 8
const LAYER_PLAYER := 16

@onready var _collision: CollisionShape2D = get_node_or_null("Collision") as CollisionShape2D
@onready var _blob: BlobBackdrop = get_node_or_null("VisualBlob") as BlobBackdrop
@onready var _camera: Camera2D = get_node_or_null("Camera2D") as Camera2D
@onready var _animated_sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D

var glue_count: int = 0
var facing := 1
var _aim_dir := Vector2.RIGHT

var _gravity_scale := 1.0
var _coyote_timer := 0.0
var _jump_buffer_timer := 0.0
var _jump_hold_timer := 0.0
var _was_airborne := true
var _spit_cooldown_timer := 0.0
var _suck_recast_timer := 0.0
var _time := 0.0
var _pending_suck: Array[Node] = []
var _action_animation_timer := 0.0


func get_glue() -> int:
	return glue_count


func get_facing() -> int:
	return facing


func get_current_radius() -> float:
	return _current_radius()


func _ready() -> void:
	collision_layer = LAYER_PLAYER
	collision_mask = LAYER_ROUGH | LAYER_SMOOTH | LAYER_GLUE_REST | LAYER_PLAYER
	glue_count = GameTuning.start_glue
	_update_body_radius()
	if _blob != null:
		_blob.set_bottom_anchor(GameTuning.player_collection_bottom_y)
		_blob.set_glue_count(glue_count)
		_blob.set_glue_color(GameTuning.player_body_color)
	if _camera != null:
		_camera.make_current()
	if _animated_sprite != null:
		_animated_sprite.play("idle")
	GameplayEvents.emit_glue_changed(glue_count, GameTuning.max_glue)


func set_glue_count(n: int) -> void:
	glue_count = clampi(n, 0, GameTuning.max_glue)
	_update_body_radius()
	if _blob != null:
		_blob.set_glue_count(glue_count)
	GameplayEvents.emit_glue_changed(glue_count, GameTuning.max_glue)


func add_glue_from_ball() -> void:
	set_glue_count(glue_count + 1)


func notify_ball_collected(ball: Node) -> void:
	_pending_suck.erase(ball)


func _physics_process(delta: float) -> void:
	_time += delta
	if _action_animation_timer > 0.0:
		_action_animation_timer -= delta
	_gravity_scale = 1.0

	if _spit_cooldown_timer > 0.0:
		_spit_cooldown_timer -= delta
	if _suck_recast_timer > 0.0:
		_suck_recast_timer -= delta

	var wish := Input.get_axis("move_left", "move_right")
	if wish != 0.0:
		facing = int(signf(wish))
		velocity.x = move_toward(velocity.x, wish * GameTuning.move_speed, GameTuning.accel * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, GameTuning.friction * delta)

	# Jump feel: gravity is reduced while the key is held in the early part of
	# the jump; releasing early cuts upward velocity (variable height).
	var g := GameTuning.gravity * _gravity_scale
	if _jump_hold_timer > 0.0 and Input.is_action_pressed("jump"):
		_jump_hold_timer -= delta
		g *= GameTuning.gravity_hold_ratio
	velocity.y += g * delta

	# Jump buffering + coyote time.
	if is_on_floor():
		_coyote_timer = GameTuning.coyote_time
		_jump_hold_timer = 0.0
	else:
		_coyote_timer = maxf(0.0, _coyote_timer - delta)
	if _jump_buffer_timer > 0.0:
		_jump_buffer_timer -= delta

	if Input.is_action_just_pressed("jump"):
		_jump_buffer_timer = GameTuning.jump_buffer_time
	if _jump_buffer_timer > 0.0 and (_coyote_timer > 0.0 or is_on_floor()):
		_do_jump()
		_jump_buffer_timer = 0.0

	if Input.is_action_just_released("jump") and velocity.y < GameTuning.jump_cut_velocity:
		velocity.y = GameTuning.jump_cut_velocity

	move_and_slide()

	if _was_airborne and is_on_floor():
		pass
	_was_airborne = not is_on_floor()

	if Input.is_action_just_pressed("restart_level"):
		get_tree().reload_current_scene()

	if Input.is_action_pressed("suck_glue") or Input.is_action_just_pressed("spit_glue"):
		var to_mouse := get_global_mouse_position() - global_position
		if to_mouse.length_squared() > 1.0:
			_aim_dir = to_mouse.normalized()
	if Input.is_action_just_pressed("spit_glue"):
		_spit()
	if Input.is_action_pressed("suck_glue"):
		_try_suck()
	if _animated_sprite != null:
		_animated_sprite.flip_h = facing < 0
	if _blob != null:
		_blob.set_velocity(velocity)
	_update_animation()

	queue_redraw()


func _do_jump() -> void:
	# Heavy glue lowers jump height: at the weight cap the jump keeps only
	# (1 - glue_jump_weight_max) of its base height.
	var weight := clampf(float(glue_count) / float(GameTuning.glue_effect_cap), 0.0, 1.0)
	var vy := GameTuning.jump_velocity * (1.0 - GameTuning.glue_jump_weight_max * weight)
	velocity.y = vy
	_jump_hold_timer = GameTuning.jump_hold_time
	GameplayEvents.emit_glue_changed(glue_count, GameTuning.max_glue)  # no-op keeps signal warm


func _update_body_radius() -> void:
	var r := minf(GameTuning.body_radius_base + GameTuning.body_radius_per_glue * float(glue_count), GameTuning.body_collision_max_radius)
	if _collision != null and _collision.shape is CircleShape2D:
		(_collision.shape as CircleShape2D).radius = r
		# Anchor the collision bottom at the feet: as the radius grows the
		# shape slides upward instead of pushing the player up off the ground.
		_collision.position.y = GameTuning.body_collision_bottom_offset - r
	if _blob != null:
		var collection_radius := GameTuning.player_collection_radius_base + GameTuning.player_collection_radius_per_glue * float(glue_count)
		_blob.set_collection_radius(minf(collection_radius, GameTuning.player_collection_max_radius))


func _spit() -> void:
	if _spit_cooldown_timer > 0.0:
		return
	if glue_count < GameTuning.glue_particles_per_unit:
		return
	_spit_cooldown_timer = GameTuning.spit_cooldown
	_play_action_animation("spit", 0.30)
	set_glue_count(glue_count - GameTuning.glue_particles_per_unit)
	var dir := _aim_dir
	var r: float = _current_radius()
	var muzzle := global_position + dir * (r + GameTuning.glue_ball_radius + 3.0)
	var n := GameTuning.glue_particles_per_unit
	# One spit fires one burst. Members keep INDEPENDENT physics (separate
	# flight, separate landing) but share a burst id so they never shove each
	# other apart mid-air or at impact. The layout is a disc PERPENDICULAR to
	# the aim direction, so every ball has the same flight depth: the whole
	# burst reaches the wall on the same frame and lands as one bump.
	var bid := 1 + int(Time.get_ticks_usec() % 1000000000)
	var fired := 0
	for i in n:
		var ball: Node = GluePool.take_ball()
		if ball == null:
			continue
		ball.set("burst_id", bid)
		var offset := _burst_offset(i, n, dir)
		var drift := 1.0 + (fposmod(float(i) * 0.618, 1.0) - 0.5) * 0.016
		ball.call("begin_fly", muzzle + offset, dir, GameTuning.spit_speed * drift)
		fired += 1
	if fired == 0:
		set_glue_count(glue_count + GameTuning.glue_particles_per_unit)


func _burst_offset(i: int, n: int, _dir: Vector2) -> Vector2:
	# Full golden-angle disc. Slight depth spread is fine: same-burst members
	# pass through each other in flight (burst_id probe) and reach the wall
	# themselves, so the clump reads as one big ball mid-air and lands as a
	# pile where later balls settle on/behind earlier ones -- never a line.
	if i == 0:
		return Vector2.ZERO
	var golden := float(i) * 2.39996
	var ring := 12.0 * sqrt(float(i) / float(n - 1))
	return Vector2(cos(golden), sin(golden)) * ring


func _current_radius() -> float:
	return GameTuning.body_radius_base + GameTuning.body_radius_per_glue * float(glue_count)


func _try_suck() -> void:
	if _suck_recast_timer > 0.0:
		return
	_suck_recast_timer = GameTuning.suck_recast_time
	_play_action_animation("suck", 0.34)
	var space := get_world_2d().direct_space_state
	var q := PhysicsShapeQueryParameters2D.new()
	var circ := CircleShape2D.new()
	circ.radius = GameTuning.suck_range
	q.shape = circ
	q.transform = Transform2D(0.0, global_position)
	q.collision_mask = LAYER_GLUE_REST | LAYER_GLUE_FLY
	q.collide_with_bodies = true
	q.collide_with_areas = false
	var results := space.intersect_shape(q, 48)
	var owned: Array = []
	for res in results:
		var ball = res.get("collider")
		if ball == null or not is_instance_valid(ball):
			continue
		if not ball.is_in_group("glue_ball") and not (ball is CharacterBody2D and ball.has_method("begin_suck")):
			continue
		if ball.get("state") == 2 and ball.get("owner_player") == self:
			continue
		var rel: Vector2 = ball.global_position - global_position
		if rel.length() > GameTuning.suck_range + GameTuning.glue_ball_radius:
			continue
		var dot: float = rel.normalized().dot(_aim_dir)
		var half := cos(deg_to_rad(GameTuning.suck_cone_angle_deg * 0.5))
		if dot < half:
			continue
		if not _los_clear(ball):
			continue
		owned.append(ball)
		if owned.size() >= GameTuning.max_suck_glue:
			break
	for b in owned:
		b.begin_suck(self)
		_pending_suck.append(b)


func _los_clear(ball: Node) -> bool:
	var space := get_world_2d().direct_space_state
	var r: float = _current_radius()
	var from := global_position + _aim_dir * (r - 2.0)
	var ray := PhysicsRayQueryParameters2D.create(from, ball.global_position, LAYER_ROUGH | LAYER_SMOOTH | LAYER_GLUE_REST)
	ray.exclude = [get_rid(), ball.get_rid()]
	var hit := space.intersect_ray(ray)
	return hit.is_empty()


func _draw() -> void:
	# suck cone visual aid while holding
	if Input.is_action_pressed("suck_glue"):
		_draw_suck_cone()


func _play_action_animation(animation_name: String, duration: float) -> void:
	if _animated_sprite == null or _animated_sprite.sprite_frames == null:
		return
	_action_animation_timer = duration
	_animated_sprite.play(animation_name)


func _update_animation() -> void:
	if _animated_sprite == null or _action_animation_timer > 0.0:
		return
	if not is_on_floor():
		_animated_sprite.play("jump")
	elif absf(velocity.x) > 30.0:
		_animated_sprite.play("move")
	else:
		_animated_sprite.play("idle")


func _draw_suck_cone() -> void:
	var half_a := deg_to_rad(GameTuning.suck_cone_angle_deg * 0.5)
	var a0 := _aim_dir.angle() - half_a
	var a1 := _aim_dir.angle() + half_a
	var steps := 14
	var fan := PackedVector2Array()
	fan.push_back(Vector2.ZERO)
	for i in steps + 1:
		var a := lerpf(a0, a1, float(i) / steps)
		fan.push_back(Vector2.from_angle(a) * GameTuning.suck_range)
	var col := Color(1, 1, 1, 0.06)
	draw_colored_polygon(fan, col)
	draw_arc(Vector2.ZERO, GameTuning.suck_range, a0, a1, steps, Color(1, 1, 1, 0.10), 1.0, true)
