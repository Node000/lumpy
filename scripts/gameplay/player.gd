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
@onready var _animated_sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
@onready var _face_sprite: AnimatedSprite2D = get_node_or_null("FaceSprite") as AnimatedSprite2D

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
var _action_anim := &""
var _spit_was_down := false
var _suck_was_down := false


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
	if _blob != null:
		_blob.layout_changed.connect(_on_blob_layout_changed)
	_update_body_radius()
	if _blob != null:
		_blob.set_bottom_anchor(GameTuning.player_collection_bottom_y)
		_blob.set_glue_count(glue_count)
		_blob.set_glue_color(GameTuning.player_body_color)
	_sync_particle_collisions()
	_play_body_animation(&"idle")
	GameplayEvents.emit_glue_changed(glue_count, GameTuning.max_glue)


func set_glue_count(n: int) -> void:
	glue_count = clampi(n, 0, GameTuning.max_glue)
	_update_body_radius()
	if _blob != null:
		_blob.set_glue_count(glue_count)
	_sync_particle_collisions()
	GameplayEvents.emit_glue_changed(glue_count, GameTuning.max_glue)


func add_glue_from_ball() -> void:
	set_glue_count(glue_count + 1)


func notify_ball_collected(ball: Node) -> void:
	_pending_suck.erase(ball)


func _physics_process(delta: float) -> void:
	_time += delta
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

	var spit_down := Input.is_action_pressed("spit_glue")
	var suck_down := Input.is_action_pressed("suck_glue")
	if spit_down or suck_down:
		var to_mouse := get_global_mouse_position() - global_position
		if to_mouse.length_squared() > 1.0:
			_aim_dir = to_mouse.normalized()
	if spit_down and not _spit_was_down:
		_start_action_animation(&"spit")
	if spit_down:
		_spit()
	if suck_down and not _suck_was_down:
		_start_action_animation(&"suck")
	if suck_down:
		_try_suck()
	if _spit_was_down and not spit_down and _action_anim == &"spit":
		_action_anim = &""
	if _suck_was_down and not suck_down and _action_anim == &"suck":
		_action_anim = &""
	_spit_was_down = spit_down
	_suck_was_down = suck_down
	if _animated_sprite != null:
		_animated_sprite.flip_h = facing < 0
	if _face_sprite != null:
		_face_sprite.flip_h = facing < 0
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
	if _blob != null:
		var collection_radius := GameTuning.player_collection_radius_base + GameTuning.player_collection_radius_per_glue * float(glue_count)
		_blob.set_collection_radius(minf(collection_radius, GameTuning.player_collection_max_radius))


func _on_blob_layout_changed(_positions: PackedVector2Array, _radii: PackedFloat32Array) -> void:
	_sync_particle_collisions()


func _sync_particle_collisions() -> void:
	if _blob == null:
		return
	# Fixed body collider: keeps the player grounded even at zero glue.
	if _collision == null:
		_collision = CollisionShape2D.new()
		_collision.name = "Collision"
		add_child(_collision)
	_collision.position = _blob.position
	var body_circle := _collision.shape as CircleShape2D
	if body_circle == null:
		body_circle = CircleShape2D.new()
		_collision.shape = body_circle
	body_circle.radius = GameTuning.body_radius_base
	_collision.set_deferred("disabled", false)
	var layout: Dictionary = _blob.get_particle_layout()
	var positions: PackedVector2Array = layout["positions"]
	var radii: PackedFloat32Array = layout["radii"]
	for i in positions.size():
		var shape_node := _get_or_create_particle_collision(i)
		shape_node.position = _blob.position + positions[i]
		var circle := shape_node.shape as CircleShape2D
		circle.radius = radii[i]
		shape_node.set_deferred("disabled", false)
	for i in range(positions.size(), _collision_count()):
		var extra := get_node_or_null("ParticleCollision%03d" % (i + 1)) as CollisionShape2D
		if extra != null:
			extra.set_deferred("disabled", true)


func get_active_particle_collision_count() -> int:
	if _blob == null:
		return 0
	return _blob.get_particle_count()


func _get_or_create_particle_collision(index: int) -> CollisionShape2D:
	var node_name := "ParticleCollision%03d" % (index + 1)
	var shape_node := get_node_or_null(node_name) as CollisionShape2D
	if shape_node == null:
		shape_node = CollisionShape2D.new()
		shape_node.name = node_name
		add_child(shape_node)
	if shape_node.shape == null or not shape_node.shape is CircleShape2D:
		shape_node.shape = CircleShape2D.new()
	return shape_node


func _collision_count() -> int:
	var count := 0
	for child in get_children():
		if child is CollisionShape2D and child != _collision:
			count += 1
	return count


func _spit() -> void:
	if _spit_cooldown_timer > 0.0:
		return
	if glue_count <= 0:
		return
	var ball: Node = GluePool.take_ball()
	if ball == null:
		return
	_spit_cooldown_timer = GameTuning.spit_interval
	var r: float = _current_radius()
	set_glue_count(glue_count - 1)
	var half_spread := deg_to_rad(GameTuning.spit_spread_deg * 0.5)
	var dir := _aim_dir.rotated(randf_range(-half_spread, half_spread))
	var muzzle := global_position + dir * (r + GameTuning.glue_ball_radius + 3.0)
	ball.call("begin_fly", muzzle, dir, GameTuning.spit_speed)


func _current_radius() -> float:
	var collection_radius := GameTuning.player_collection_radius_base + GameTuning.player_collection_radius_per_glue * float(glue_count)
	return minf(collection_radius, GameTuning.player_collection_max_radius)


func _try_suck() -> void:
	if _suck_recast_timer > 0.0:
		return
	_suck_recast_timer = GameTuning.suck_recast_time
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
		owned.append(ball)
		if owned.size() >= GameTuning.max_suck_glue:
			break
	for b in owned:
		b.begin_suck(self)
		_pending_suck.append(b)

func _draw() -> void:
	if GameTuning.show_suck_range and Input.is_action_pressed("suck_glue"):
		_draw_suck_cone()


func _start_action_animation(animation_name: StringName) -> void:
	# Action animations (spit/suck) are one-shot: they start once on the press
	# edge and hold their last frame until the button is released.
	_action_anim = animation_name
	_play_body_animation(animation_name)


func _update_animation() -> void:
	if _animated_sprite == null or _action_anim != &"":
		return
	# Locomotion animations are one-shot too: jump plays once per takeoff and
	# keeps its last frame until landing, then move/idle take over. Calling
	# play() again while the same animation already shows would restart it, so
	# every play is guarded.
	if not is_on_floor():
		_play_body_animation(&"jump")
	elif absf(velocity.x) > 30.0:
		_play_body_animation(&"move")
	else:
		_play_body_animation(&"idle")


func _play_body_animation(animation_name: StringName) -> void:
	if _animated_sprite == null or _animated_sprite.sprite_frames == null:
		return
	if _animated_sprite.animation == animation_name and _animated_sprite.is_playing():
		return
	_animated_sprite.play(animation_name)
	_play_on_face(animation_name)


func _play_on_face(animation_name: StringName) -> void:
	if _face_sprite == null or _face_sprite.sprite_frames == null:
		return
	if _face_sprite.animation == animation_name and _face_sprite.is_playing():
		return
	_face_sprite.play(animation_name)


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
