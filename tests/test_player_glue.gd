extends SceneTree

## Headless smoke test for the two requested test scenes and the core glue
## contracts. Run with:
##   godot --headless --path . --script res://tests/test_player_glue.gd

var _failed := false
var _tuning: Node
var _glue_pool: Node
var _gameplay_events: Node


func _initialize() -> void:
	_tuning = root.get_node_or_null("GameTuning")
	_glue_pool = root.get_node_or_null("GluePool")
	_gameplay_events = root.get_node_or_null("GameplayEvents")
	_assert(_tuning != null, "game tuning autoload exists")
	_assert(_glue_pool != null, "glue pool autoload exists")
	_assert(load("res://scenes/gameplay/glue_ball.tscn") != null, "glue ball scene loads")
	_assert(load("res://scenes/levels/player_test.tscn") != null, "player test scene loads")
	_assert(load("res://scenes/levels/paint_lab.tscn") != null, "paint lab scene loads")
	_assert(load("res://scripts/gameplay/paint_wall.gd") != null, "paint wall script loads")
	_assert(load("res://scripts/gameplay/glue_spot.gd") != null, "glue spot script loads")
	_assert(load("res://scenes/levels/shader_test.tscn") != null, "shader test scene loads")
	_assert(load("res://shaders/liquid_ball.gdshader") != null, "liquid shader loads")
	_assert(load("res://shaders/liquid_collection.gdshader") != null, "player collection liquid shader loads")
	_assert(load("res://shaders/metaball_blob.gdshader") != null, "metaball shader loads")
	var character_frames := load("res://assets/character/lumpy_animations.tres") as SpriteFrames
	_assert(character_frames != null, "character animation resource loads")
	_assert(character_frames.has_animation("idle") and character_frames.get_frame_count("idle") == 1, "idle animation uses frame 1")
	_assert(character_frames.has_animation("move") and character_frames.get_frame_count("move") == 8, "move animation uses frames 1 through 8")
	_assert(character_frames.has_animation("jump") and character_frames.get_frame_count("jump") == 5, "jump animation uses frames 9 through 13")
	_assert(character_frames.has_animation("spit") and character_frames.get_frame_count("spit") == 3, "spit animation uses frames 14 through 16")
	_assert(character_frames.has_animation("suck") and character_frames.get_frame_count("suck") == 4, "suck animation uses frames 17 through 20")
	var shader_scene := load("res://scenes/levels/shader_test.tscn") as PackedScene
	var shader_level := shader_scene.instantiate()
	root.add_child(shader_level)
	await process_frame
	var metaball := shader_level.get_node_or_null("MetaballDemo")
	var liquid := shader_level.get_node_or_null("LiquidDemo")
	_assert(metaball != null and metaball.has_method("get_active_blob_count"), "metaball demo controller exists")
	_assert(metaball.get_active_blob_count() == 7, "metaball demo starts with seven blobs")
	_assert(liquid != null and liquid.has_method("is_shader_ready") and liquid.is_shader_ready(), "single liquid material is ready")
	shader_level.free()

	var player_scene := load("res://scenes/levels/player_test.tscn") as PackedScene
	var level := player_scene.instantiate()
	root.add_child(level)
	await process_frame
	# The level starts with hundreds of editor-placed glue spots. Their balls
	# materialise gradually over the first second, so clear every spot right
	# away (releasing whatever already spawned and cancelling the queued rest)
	# to keep the scripted movement/jump corridor clear.
	for spot in get_nodes_in_group("glue_spot"):
		spot.call("clear_pile")
	await _wait_physics_frames(30)
	_assert(_glue_pool.get_pending_pile_count() == 0, "clearing glue spots cancels their queued spawns")
	var player := level.get_node_or_null("Player")
	_assert(player != null, "player exists in player test")
	var grow_to := clampi(_tuning.start_glue * 3, _tuning.start_glue + 1, _tuning.max_glue)
	_assert(player.get("glue_count") == _tuning.start_glue, "player starts with %d glue particles" % _tuning.start_glue)
	_assert(_tuning.glue_ball_collision_radius < _tuning.glue_ball_radius, "glue particle collision radius is reduced below its visual radius")
	_assert(_tuning.glue_jump_weight_max == 0.5, "jump weight cap is 50%")
	_assert(player.get("collision_layer") == 16, "player uses collision layer 16")
	var sprite := player.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	_assert(sprite != null and sprite.sprite_frames == character_frames, "player uses the character animation resource")
	var body_frames := sprite.sprite_frames
	var face_sprite := player.get_node_or_null("FaceSprite") as AnimatedSprite2D
	var collection := player.get_node_or_null("VisualBlob") as BlobBackdrop
	_assert(collection != null, "player has a liquid collection visual")
	_assert(collection.color == _tuning.player_body_color, "player liquid collection matches player body color")
	_assert(collection.z_index > sprite.z_index, "player liquid collection renders above player sprite")
	_assert(_tuning.suck_cone_angle_deg == 30.0 and _tuning.suck_range == 430.0, "suck cone angle and radius are tunable")
	_assert(_tuning.show_suck_range, "suck range display is enabled by tuning")
	_assert(collection.get_particle_count() == _tuning.start_glue, "player collection has one visual per glue particle")
	_assert(collection.get_visible_particle_count() == _tuning.start_glue, "player collection exposes all start particles")
	_assert(is_equal_approx(collection.get_collection_bottom_y(), _tuning.player_collection_bottom_y), "player liquid collection bottom starts anchored")
	var start_bottom := collection.get_collection_bottom_y()
	player.set_glue_count(grow_to)
	await _wait_physics_frames(20)
	_assert(is_equal_approx(collection.get_collection_bottom_y(), start_bottom), "player liquid collection bottom stays anchored while growing")
	_assert(collection.position.y < 0.0, "player liquid collection center moves upward while growing")
	_assert(collection.get("_glue_count") == grow_to, "player collection tracks all configured particles")
	_assert(collection.get_particle_count() == grow_to, "player collection grows one visual per new particle")
	_assert(player.get_active_particle_collision_count() == grow_to, "player uses one compound collider per visible particle")
	var layout: Dictionary = collection.get_particle_layout()
	var positions: PackedVector2Array = layout["positions"]
	var radii: PackedFloat32Array = layout["radii"]
	var matched_particles := 0
	for i in positions.size():
		var particle := collection.get_node("Particle%03d" % i) as BlobSprite
		var collider: CollisionShape2D = player.get_node("ParticleCollision%03d" % (i + 1))
		var collider_shape := collider.shape as CircleShape2D
		_assert(particle != null and collider_shape != null, "particle visual and collider exist at index %d" % i)
		if particle != null and collider_shape != null:
			matched_particles += 1
			_assert(particle.position.distance_to(positions[i]) < 0.001, "particle visual position matches layout at index %d" % i)
			_assert(collider.position.distance_to(collection.position + positions[i]) < 0.001, "particle collider position matches visual at index %d" % i)
			_assert(is_equal_approx(particle.base_radius, radii[i]) and is_equal_approx(collider_shape.radius, radii[i]), "particle visual and collider radius match at index %d" % i)
	_assert(matched_particles == grow_to, "every visible particle has a matched visual and collider")
	var collision_bottom := -INF
	var active_collisions := 0
	for child in player.get_children():
		if child is CollisionShape2D and not child.disabled:
			var shape := child.shape as CircleShape2D
			if shape != null:
				active_collisions += 1
				collision_bottom = maxf(collision_bottom, child.position.y + shape.radius)
	_assert(active_collisions == grow_to + 1, "all particle colliders plus fixed body collider are direct Player children")
	_assert(is_equal_approx(collision_bottom, _tuning.player_collection_bottom_y), "compound collision bottom stays anchored at feet while growing")
	_assert(is_equal_approx((player.get_node("Collision").shape as CircleShape2D).radius, _tuning.body_radius_base), "fixed body collider radius is body_radius_base")
	var ball_scene := load("res://scenes/gameplay/glue_ball.tscn") as PackedScene
	var ball := ball_scene.instantiate()
	root.add_child(ball)
	await _wait_physics_frames(1)
	var ball_blob := ball.get_node_or_null("Visual/GlueBody") as BlobSprite
	var ball_collision := ball.get_node_or_null("Collision") as CollisionShape2D
	_assert(ball_blob != null and is_equal_approx(ball_blob.base_radius, _tuning.glue_ball_radius), "free glue ball uses tuned visual radius")
	_assert(ball_collision != null and is_equal_approx((ball_collision.shape as CircleShape2D).radius, _tuning.glue_ball_collision_radius), "free glue ball uses the reduced collision radius")
	_assert(ball_blob.get_child_count() == 0, "free glue ball uses a static non-liquid visual")
	ball.call("place_at_rest")
	await _wait_physics_frames(3)
	_assert(is_equal_approx(ball_blob.base_radius, _tuning.glue_ball_radius), "resting glue ball keeps its visual radius")
	_assert(is_equal_approx((ball_collision.shape as CircleShape2D).radius, _tuning.glue_ball_collision_radius) and not ball_collision.disabled, "resting glue ball keeps its enabled reduced collision")
	var wall := StaticBody2D.new()
	wall.collision_layer = 1
	var wall_shape := CollisionShape2D.new()
	var wall_rect := RectangleShape2D.new()
	wall_rect.size = Vector2(8.0, 120.0)
	wall_shape.shape = wall_rect
	wall.position = Vector2(10040.0, 10000.0)
	wall.add_child(wall_shape)
	root.add_child(wall)
	var impact_ball := ball_scene.instantiate()
	root.add_child(impact_ball)
	await _wait_physics_frames(1)
	impact_ball.call("begin_fly", Vector2(10000.0, 10000.0), Vector2.RIGHT, 600.0)
	await _wait_physics_frames(12)
	var impact_collision := impact_ball.get_node_or_null("Collision") as CollisionShape2D
	_assert(impact_ball.get("state") == 1, "wall impact changes glue ball to resting state")
	_assert(impact_collision != null and not impact_collision.disabled and impact_ball.collision_layer == 4, "wall-stopped glue ball remains collidable")
	var probe := PhysicsShapeQueryParameters2D.new()
	var probe_shape := CircleShape2D.new()
	probe_shape.radius = 1.0
	probe.shape = probe_shape
	probe.transform = Transform2D(0.0, impact_ball.global_position)
	probe.collision_mask = 4
	probe.collide_with_bodies = true
	var probe_hits: Array[Dictionary] = impact_ball.get_world_2d().direct_space_state.intersect_shape(probe, 16)
	var found_impact_ball := false
	for hit in probe_hits:
		if hit.get("collider") == impact_ball:
			found_impact_ball = true
	_assert(found_impact_ball, "wall-stopped glue ball is visible to glue-rest collision queries")
	impact_ball.free()
	wall.free()
	var swell_scale := float(_tuning.glue_swell_scale)
	var swell_target: Vector2 = Vector2.ONE * swell_scale
	var swell_target_radius := float(_tuning.glue_ball_collision_radius) * swell_scale
	var swelled := false
	for _i in 240:
		if is_equal_approx(ball_blob.scale.x, swell_target.x) and is_equal_approx((ball_collision.shape as CircleShape2D).radius, swell_target_radius):
			swelled = true
			break
		await _wait_physics_frames(1)
	_assert(swelled and is_equal_approx(ball_blob.scale.x, swell_scale) and is_equal_approx(ball_blob.scale.y, swell_scale), "resting glue ball elastically swells to the tuned visual size")
	_assert(is_equal_approx((ball_collision.shape as CircleShape2D).radius, swell_target_radius), "swelled glue ball collision grows with the visual")
	await _wait_physics_frames(170)
	_assert(is_equal_approx(ball_blob.scale.x, swell_scale) and is_equal_approx(ball_blob.scale.y, swell_scale), "swelled glue ball keeps its final size after the animation")
	_assert(is_equal_approx((ball_collision.shape as CircleShape2D).radius, swell_target_radius), "swelled glue ball collision stays at its final size")
	ball.free()
	await _wait_physics_frames(20)
	_assert(sprite.animation == &"idle", "player settles into idle animation")

	var paint_scene := load("res://scenes/levels/paint_lab.tscn") as PackedScene
	var paint_level := paint_scene.instantiate()
	root.add_child(paint_level)
	var busy_before_paint: int = _glue_pool.get_busy_count()
	await process_frame
	var shelf := paint_level.get_node_or_null("ShelfSmooth")
	var block := paint_level.get_node_or_null("BlockRough")
	_assert(shelf != null and shelf.get("smooth") == true and shelf.collision_layer == 2, "paint lab smooth wall uses layer 2")
	_assert(block != null and block.get("smooth") == false and block.collision_layer == 1, "paint lab rough wall uses layer 1")
	var shelf_collision := shelf.get_node_or_null("Collision") as CollisionShape2D
	_assert(shelf_collision != null and shelf_collision.shape is RectangleShape2D, "paint lab wall has rectangle collision")
	var shelf_size: Vector2 = shelf.call("get_wall_size")
	_assert(is_equal_approx(shelf_size.x, 1.8) and is_equal_approx(shelf_size.y, 0.24), "paint lab wall size derives from size_px")
	var spot := paint_level.get_node_or_null("GlueSpot")
	if spot == null:
		spot = Node2D.new()
		spot.name = "GlueSpot"
		spot.set_script(load("res://scripts/gameplay/glue_spot.gd"))
		spot.count = 4
		paint_level.add_child(spot)
	await process_frame
	var spot_ready := false
	for _i in 150:
		if spot.call("get_spawned_count") == 4:
			spot_ready = true
			break
		await _wait_physics_frames(1)
	_assert(spot_ready, "glue spot spawns its configured resting particles within the first second")
	_assert(_glue_pool.get_busy_count() == busy_before_paint + 4, "glue spot particles are real pooled resting balls")
	var pile_balls_ok := true
	var pile_ball_count := 0
	for n in get_nodes_in_group("glue_ball"):
		if n.get("state") == 1 and is_instance_valid(n) and _glue_pool.get_busy_list().has(n):
			pile_ball_count += 1
			var pile_col := n.get_node_or_null("Collision") as CollisionShape2D
			if pile_col == null or pile_col.disabled or n.get("collision_layer") != 4:
				pile_balls_ok = false
	_assert(pile_ball_count == 4 and pile_balls_ok, "every glue spot particle keeps its own enabled resting collision")
	spot.call("clear_pile")
	await _wait_physics_frames(2)
	_assert(spot.call("get_spawned_count") == 0 and _glue_pool.get_busy_count() == busy_before_paint, "clearing a glue spot releases its particles back to the pool")
	paint_level.free()
	await _wait_physics_frames(2)
	# The spawn pocket has a low ceiling that wedges the grown player in place,
	# so relocate the input probes to the open strip at x = 2000.
	player.global_position = Vector2(2000.0, 300.0)
	player.velocity = Vector2.ZERO
	for _frame in 45:
		await physics_frame
		if player.is_on_floor():
			break

	Input.action_press("move_right")
	await _wait_physics_frames(8)
	_assert(sprite.animation == &"move", "horizontal input activates move animation")
	Input.action_release("move_right")
	await _wait_physics_frames(8)
	_assert(sprite.animation == &"idle", "released movement returns to idle animation")

	Input.action_press("jump")
	await _wait_until_animation(sprite, &"jump", 8)
	_assert(sprite.animation == &"jump", "jump input activates jump animation")
	await _wait_physics_frames(28)
	var jump_last := body_frames.get_frame_count("jump") - 1
	_assert(not player.is_on_floor() and sprite.animation == &"jump" and not sprite.is_playing() and sprite.frame == jump_last, "jump animation plays once and holds its last frame in the air")
	if face_sprite != null:
		_assert(face_sprite.animation == &"jump" and not face_sprite.is_playing() and face_sprite.frame == jump_last, "face jump animation holds its last frame in the air")
	Input.action_release("jump")
	await _wait_physics_frames(50)

	var busy_before_spit: int = _glue_pool.get_busy_count()
	Input.action_press("spit_glue")
	await _wait_physics_frames(1)
	_assert(sprite.animation == &"spit", "spit input activates spit animation")
	var busy_after_spit: int = _glue_pool.get_busy_count()
	_assert(busy_after_spit == busy_before_spit + 1, "one spit emits one glue ball")
	_assert(player.get("glue_count") == grow_to - 1, "one spit spends one glue particle")
	await _wait_physics_frames(10)
	_assert(_glue_pool.get_busy_count() >= busy_after_spit + 1, "holding spit emits additional single glue balls")
	_assert(player.get("glue_count") <= grow_to - 2, "continuous spit spends one particle per interval")
	await _wait_physics_frames(18)
	var spit_last := body_frames.get_frame_count("spit") - 1
	_assert(sprite.animation == &"spit" and not sprite.is_playing() and sprite.frame == spit_last, "spit animation plays once and holds its last frame while held")
	if face_sprite != null:
		_assert(face_sprite.animation == &"spit" and not face_sprite.is_playing() and face_sprite.frame == spit_last, "face spit animation plays once and holds its last frame while held")
	Input.action_release("spit_glue")
	await _wait_physics_frames(20)
	_assert(sprite.animation == &"idle", "released spit returns the player to idle animation")

	var suck_ball: Node = _glue_pool.take_ball()
	_assert(suck_ball != null, "suck test can take a glue ball from the pool")
	if suck_ball != null:
		var glue_before_suck: int = player.get("glue_count")
		player.set("_aim_dir", Vector2.RIGHT)
		suck_ball.global_position = player.global_position + Vector2(80.0, 0.0)
		suck_ball.call("place_at_rest")
		await _wait_physics_frames(1)
		suck_ball.call("begin_suck", player)
		await _wait_physics_frames(1)
		var suck_collision := suck_ball.get_node_or_null("Collision") as CollisionShape2D
		_assert(suck_ball.get("state") == 2, "sucked glue ball enters suck state")
		_assert(suck_ball.collision_layer == 0 and suck_ball.collision_mask == 0, "sucked glue ball ignores all collision layers")
		_assert(suck_collision != null and suck_collision.disabled, "sucked glue ball collision shape is disabled")
		await _wait_physics_frames(8)
		_assert(not _glue_pool.get_busy_list().has(suck_ball) and player.get("glue_count") == glue_before_suck + 1, "sucked glue ball reaches and is collected by player")

	var trio: Array[Node] = []
	# Give the player exactly three free slots so the fill-up behaviour can be
	# asserted precisely, and clear every leftover resting ball first so the
	# trio are the only candidates in the cone.
	player.set_glue_count(_tuning.max_glue - 3)
	_release_resting_pool_balls()
	await _wait_physics_frames(2)
	# Pre-press for one frame so the player re-aims at the mouse; balls are then
	# placed along that aim so the cone always covers them.
	player.set("_aim_dir", Vector2.RIGHT)
	Input.action_press("suck_glue")
	await _wait_physics_frames(1)
	Input.action_release("suck_glue")
	var aim_dir: Vector2 = player.get("_aim_dir")
	for i in 3:
		var b: Node = _glue_pool.take_ball()
		if b == null:
			break
		trio.append(b)
		b.global_position = player.global_position + aim_dir * (70.0 + i * 90.0)
		b.call("place_at_rest")
	await _wait_physics_frames(2)
	if trio.size() == 3:
		Input.action_press("suck_glue")
		await _wait_physics_frames(2)
		Input.action_release("suck_glue")
		var all_grabbed := true
		for b in trio:
			all_grabbed = all_grabbed and b.get("state") == 2
		_assert(all_grabbed, "every in-range glue ball is grabbed while slots are free")
		await _wait_physics_frames(28)
		var all_collected := true
		for b in trio:
			all_collected = all_collected and not _glue_pool.get_busy_list().has(b)
		_assert(all_collected, "grabbed glue balls fly straight to the player and get collected")
		_assert(player.get("glue_count") == _tuning.max_glue, "glue balls fill the player exactly up to max")

	# Waste-prevention regression: with only one free slot and several balls in
	# range, only the nearest ball is locked; the rest stay resting and are
	# never pulled in afterwards, because the committed total (on-body glue +
	# flying balls), not the on-body count alone, decides when to stop.
	player.set_glue_count(_tuning.max_glue - 1)
	_release_resting_pool_balls()
	await _wait_physics_frames(2)
	player.set("_aim_dir", Vector2.RIGHT)
	Input.action_press("suck_glue")
	await _wait_physics_frames(1)
	Input.action_release("suck_glue")
	await _wait_physics_frames(1)
	var waste_aim: Vector2 = player.get("_aim_dir")
	var rest_balls: Array[Node] = []
	for i in 4:
		var b: Node = _glue_pool.take_ball()
		if b == null:
			break
		rest_balls.append(b)
		b.global_position = player.global_position + waste_aim * (70.0 + i * 60.0)
		b.call("place_at_rest")
	await _wait_physics_frames(2)
	if rest_balls.size() == 4:
		Input.action_press("suck_glue")
		await _wait_physics_frames(3)
		Input.action_release("suck_glue")
		var locked := 0
		for b in rest_balls:
			if b.get("state") == 2:
				locked += 1
		_assert(locked == 1, "with one free slot only the nearest glue ball is locked")
		await _wait_physics_frames(30)
		var leftovers := 0
		for b in rest_balls:
			if b.get("state") == 1 and _glue_pool.get_busy_list().has(b):
				leftovers += 1
		_assert(leftovers == 3, "locked ball is collected and the rest are never sucked")
		_assert(player.get("glue_count") == _tuning.max_glue, "player reaches max without wasting in-flight glue balls")

	player.set("_aim_dir", Vector2.RIGHT)
	Input.action_press("suck_glue")
	await _wait_physics_frames(1)
	Input.action_release("suck_glue")
	await _wait_physics_frames(1)

	var obstacle_wall := StaticBody2D.new()
	obstacle_wall.collision_layer = 1
	var obstacle_shape := CollisionShape2D.new()
	var obstacle_rect := RectangleShape2D.new()
	obstacle_rect.size = Vector2(8.0, 120.0)
	obstacle_shape.shape = obstacle_rect
	var obstacle_aim: Vector2 = player.get("_aim_dir")
	obstacle_wall.position = player.global_position + obstacle_aim * 150.0
	obstacle_wall.rotation = obstacle_aim.angle()
	obstacle_wall.add_child(obstacle_shape)
	level.add_child(obstacle_wall)
	var blocker_ball: Node = _glue_pool.take_ball()
	var wall_ball: Node = _glue_pool.take_ball()
	var original_max_suck_glue: int = _tuning.max_suck_glue
	if blocker_ball != null and wall_ball != null:
		# Keep the collar below max so the full-cap check doesn't swallow this
		# obstacle scenario (continuous sucking above fills the player).
		player.set_glue_count(4)
		await _wait_physics_frames(2)
		blocker_ball.global_position = player.global_position + obstacle_aim * 205.0
		wall_ball.global_position = player.global_position + obstacle_aim * 300.0
		blocker_ball.call("place_at_rest")
		wall_ball.call("place_at_rest")
		await _wait_physics_frames(2)
		# Earlier spit probes leave resting balls in the scene. Give this isolated
		# obstacle check enough scan capacity to reach both target balls.
		_tuning.max_suck_glue = 200
		Input.action_press("suck_glue")
		await _wait_physics_frames(2)
		Input.action_release("suck_glue")
		_assert(blocker_ball.get("state") == 2 and wall_ball.get("state") == 2, "suck locks both a blocking ball and a ball behind a wall")
		var blocker_collision := blocker_ball.get_node_or_null("Collision") as CollisionShape2D
		var wall_ball_collision := wall_ball.get_node_or_null("Collision") as CollisionShape2D
		_assert(blocker_ball.collision_layer == 0 and blocker_ball.collision_mask == 0 and wall_ball.collision_layer == 0 and wall_ball.collision_mask == 0, "sucked balls ignore collision even when obstacles are between them and the player")
		_assert(blocker_collision != null and blocker_collision.disabled and wall_ball_collision != null and wall_ball_collision.disabled, "sucked balls disable their shapes while flying through obstacles")
		await _wait_physics_frames(30)
		_assert(not _glue_pool.get_busy_list().has(blocker_ball) and not _glue_pool.get_busy_list().has(wall_ball), "balls behind collision obstacles still reach and get collected")
	_tuning.max_suck_glue = original_max_suck_glue
	obstacle_wall.free()

	# Room to observe the suck animation: drain below max first.
	if player.get("glue_count") >= _tuning.max_glue:
		player.set_glue_count(maxi(_tuning.max_glue - 2, 0))
		await _wait_physics_frames(2)
	Input.action_press("suck_glue")
	await _wait_physics_frames(1)
	_assert(sprite.animation == &"suck", "suck input activates suck animation")
	await _wait_physics_frames(26)
	var suck_last := body_frames.get_frame_count("suck") - 1
	_assert(sprite.animation == &"suck" and not sprite.is_playing() and sprite.frame == suck_last, "suck animation plays once and holds its last frame while held")
	if face_sprite != null:
		_assert(face_sprite.animation == &"suck" and not face_sprite.is_playing() and face_sprite.frame == suck_last, "face suck animation plays once and holds its last frame while held")
	Input.action_release("suck_glue")
	await _wait_physics_frames(1)

	# At max glue sucking is fully inert: no ball enters SUCK, no glow, and the
	# suck animation never starts.
	player.set_glue_count(_tuning.max_glue)
	await _wait_physics_frames(10)
	var full_ball: Node = _glue_pool.take_ball()
	if full_ball != null:
		full_ball.global_position = player.global_position + Vector2(120.0, 0.0)
		full_ball.call("place_at_rest")
		await _wait_physics_frames(2)
		player.set("_aim_dir", Vector2.RIGHT)
		Input.action_press("suck_glue")
		await _wait_physics_frames(3)
		_assert(full_ball.get("state") != 2, "full player cannot start sucking a resting ball")
		_assert(full_ball.collision_layer != 0, "full player leaves resting balls untouched")
		_assert(sprite.animation != &"suck", "full player does not play the suck animation")
		_assert(player.get("glue_count") == _tuning.max_glue, "full player glue count stays at max")
		Input.action_release("suck_glue")
		await _wait_physics_frames(1)
		_glue_pool.release_ball(full_ball)
	player.set_glue_count(clampi(_tuning.start_glue, 0, _tuning.max_glue))
	await _wait_physics_frames(10)

	_assert(level.get_node_or_null("LevelLogic") == null, "player test no longer auto-spawns glue")
	_assert(load("res://scripts/gameplay/glue_spot.gd") != null, "manual glue spot component stays available")

	level.free()
	if _failed:
		print("ASSERT FAIL: one or more core checks failed")
		quit(1)
	else:
		print("ASSERT PASS: player, glue ball and shader test resources are valid")
		quit(0)


func _assert(condition: bool, label: String) -> void:
	if condition:
		print("ASSERT PASS: " + label)
	else:
		print("ASSERT FAIL: " + label)
		_failed = true


func _wait_physics_frames(count: int) -> void:
	for _frame in count:
		await physics_frame


func _release_resting_pool_balls() -> void:
	var busy: Array[Node] = _glue_pool.get_busy_list()
	for n in get_nodes_in_group("glue_ball"):
		if is_instance_valid(n) and n.get("state") == 1 and busy.has(n):
			_glue_pool.release_ball(n)


func _wait_until_animation(sprite: AnimatedSprite2D, expected: StringName, max_frames: int) -> void:
	for _frame in max_frames:
		await physics_frame
		if sprite.animation == expected:
			return
