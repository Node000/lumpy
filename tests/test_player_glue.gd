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
	_assert(load("res://shaders/liquid_blob.gdshader") != null, "single blob liquid shader loads")
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
	var player := level.get_node_or_null("Player")
	_assert(player != null, "player exists in player test")
	_assert(player.get("glue_count") == 30, "player starts with 30 glue particles")
	_assert(_tuning.glue_ball_radius == 6.0 and _tuning.glue_ball_collision_radius == 6.0, "glue particle radius equals collision size")
	_assert(_tuning.glue_jump_weight_max == 0.5, "jump weight cap is 50%")
	_assert(player.get("collision_layer") == 16, "player uses collision layer 16")
	var sprite := player.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	_assert(sprite != null and sprite.sprite_frames == character_frames, "player uses the character animation resource")
	var collection := player.get_node_or_null("VisualBlob") as BlobBackdrop
	_assert(collection != null, "player has a liquid collection visual")
	_assert(collection.color == _tuning.player_body_color, "player liquid collection matches player body color")
	_assert(collection.z_index > sprite.z_index, "player liquid collection renders above player sprite")
	_assert(_tuning.suck_cone_angle_deg == 30.0, "suck cone angle is tuned to 30 degrees")
	var collection_sprite := collection.get_node_or_null("LiquidCollection") as Sprite2D
	_assert(collection_sprite != null and collection_sprite.material is ShaderMaterial, "player collection uses a local liquid shader")
	_assert((collection_sprite.material as ShaderMaterial).shader == load("res://shaders/liquid_collection.gdshader"), "player collection uses the collection shader")
	_assert(is_equal_approx(collection.get_collection_bottom_y(), _tuning.player_collection_bottom_y), "player liquid collection bottom starts anchored")
	var start_bottom := collection.get_collection_bottom_y()
	player.set_glue_count(90)
	await _wait_physics_frames(20)
	_assert(is_equal_approx(collection.get_collection_bottom_y(), start_bottom), "player liquid collection bottom stays anchored while growing")
	_assert(collection.position.y < 0.0, "player liquid collection center moves upward while growing")
	_assert(collection.get("_glue_count") == 64, "player collection clamps at 64 tracked particles")
	var collision := player.get_node_or_null("Collision") as CollisionShape2D
	var collision_bottom := collision.position.y + (collision.shape as CircleShape2D).radius
	_assert(is_equal_approx(collision_bottom, _tuning.body_collision_bottom_offset), "collision shape bottom stays anchored at feet while growing")
	_assert((collision.shape as CircleShape2D).radius <= _tuning.body_collision_max_radius, "collision radius respects max cap")
	var ball_scene := load("res://scenes/gameplay/glue_ball.tscn") as PackedScene
	var ball := ball_scene.instantiate()
	root.add_child(ball)
	await _wait_physics_frames(1)
	var ball_blob := ball.get_node_or_null("Visual/GlueBody") as BlobSprite
	var ball_collision := ball.get_node_or_null("Collision") as CollisionShape2D
	_assert(ball_blob != null and is_equal_approx(ball_blob.base_radius, _tuning.glue_ball_radius), "free glue ball uses tuned visual radius")
	_assert(ball_collision != null and is_equal_approx((ball_collision.shape as CircleShape2D).radius, _tuning.glue_ball_collision_radius), "free glue ball uses tuned collision radius")
	_assert(_tuning.glue_swell_collision_factor == 3.0, "swelled collision size is 3x")
	ball.free()
	await _wait_physics_frames(20)
	_assert(sprite.animation == &"idle", "player settles into idle animation")

	var paint_scene := load("res://scenes/levels/paint_lab.tscn") as PackedScene
	var paint_level := paint_scene.instantiate()
	root.add_child(paint_level)
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
	_assert(spot.call("get_spawned_count") == 4, "glue spot spawns configured resting particles")
	paint_level.free()
	await _wait_physics_frames(2)

	Input.action_press("move_right")
	await _wait_physics_frames(8)
	_assert(sprite.animation == &"move", "horizontal input activates move animation")
	Input.action_release("move_right")
	await _wait_physics_frames(8)
	_assert(sprite.animation == &"idle", "released movement returns to idle animation")

	Input.action_press("jump")
	await _wait_until_animation(sprite, &"jump", 8)
	_assert(sprite.animation == &"jump", "jump input activates jump animation")
	Input.action_release("jump")
	await _wait_physics_frames(24)

	Input.action_press("spit_glue")
	await _wait_until_animation(sprite, &"spit", 8)
	_assert(sprite.animation == &"spit", "spit input activates spit animation")
	var busy_after_spit: int = _glue_pool.get_busy_count()
	_assert(busy_after_spit >= 10, "one spit expels 10 glue particles")
	_assert(player.get("glue_count") == 80, "one spit spends 10 particles from 90")
	Input.action_release("spit_glue")
	await _wait_physics_frames(20)

	Input.action_press("suck_glue")
	await _wait_physics_frames(1)
	_assert(sprite.animation == &"suck", "suck input activates suck animation")
	Input.action_release("suck_glue")
	await _wait_physics_frames(1)

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


func _wait_until_animation(sprite: AnimatedSprite2D, expected: StringName, max_frames: int) -> void:
	for _frame in max_frames:
		await physics_frame
		if sprite.animation == expected:
			return
