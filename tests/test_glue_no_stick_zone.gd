extends SceneTree
## Run: godot --headless --path . --script res://tests/test_glue_no_stick_zone.gd
## Uses real move_and_collide queries with deterministic single flight steps.
## Does not assume the user's starting glue count or particle-size defaults.

const ZoneScript = preload("res://scripts/gameplay/glue_no_stick_zone.gd")
const ZONE_SCENE = preload("res://scenes/gameplay/glue_no_stick_zone.tscn")
const ORIGIN := Vector2(10000.0, 10000.0)

var _ball_scene: PackedScene

var _failed := false
var _checks := 0
var _fixture: Node2D
var _wall: StaticBody2D
var _zone: ZoneScript


func _initialize() -> void:
	_watchdog.call_deferred()
	_run.call_deferred()


func _watchdog() -> void:
	await create_timer(10.0).timeout
	print("NO-STICK ZONE: FAIL (test did not complete)")
	quit(2)


func _run() -> void:
	# Load after autoload initialization; preloading this scene would compile
	# glue_ball.gd before the GameTuning singleton identifier is registered.
	_ball_scene = load("res://scenes/gameplay/glue_ball.tscn") as PackedScene
	_fixture = Node2D.new()
	_fixture.position = ORIGIN
	root.add_child(_fixture)
	_wall = StaticBody2D.new()
	_wall.position = Vector2(100.0, 0.0)
	_wall.collision_layer = 1
	_wall.collision_mask = 31
	var shape_node := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(20.0, 200.0)  # Left wall surface is at local x = 90.
	shape_node.shape = shape
	_wall.add_child(shape_node)
	_fixture.add_child(_wall)

	var ball := await _shoot()
	_assert(ball.get("state") == 1 and ball.collision_layer == 4,
		"rough walls still stop glue without a zone")
	ball.free()

	_zone = ZONE_SCENE.instantiate() as ZoneScript
	_fixture.add_child(_zone)
	_assert(_zone != null and _zone.get_script().is_tool(), "zone scene uses an editor tool script")
	_assert(_zone.enabled and _zone.region_size == Vector2(256.0, 256.0),
		"zone has enabled, editable rectangle defaults")
	_assert(_zone.is_in_group(ZoneScript.GROUP_NAME), "zone registers on entering the runtime tree")
	_zone.position = Vector2(90.0, 0.0)
	_zone.region_size = Vector2(2.0, 80.0)  # Contains the wall surface, not the glue centre.
	_assert(_zone.contains_wall_contact(ORIGIN + Vector2(89.0, -40.0))
		and _zone.contains_wall_contact(ORIGIN + Vector2(91.0, 40.0)),
		"all rectangle edges are included")
	_assert(not _zone.contains_wall_contact(ORIGIN + Vector2(91.1, 0.0)),
		"points outside the rectangle are excluded")

	ball = await _shoot()
	_assert_reflected(ball, "covered rough-wall contact reflects")
	_assert(not _zone.contains_wall_contact(ball.global_position),
		"coverage uses the wall contact, not the glue centre")
	_assert(_wall.collision_layer == 1 and _wall.collision_mask == 31,
		"zone leaves the wall's collision layers unchanged")
	var before_suck := ball.global_position
	ball.call("begin_suck", _fixture)
	ball.call("_physics_suck", 0.01)
	_assert(ball.get("state") == 2 and ball.collision_layer == 0 and ball.collision_mask == 0,
		"reflected glue can still enter the normal suck state")
	_assert(ball.global_position.distance_to(ORIGIN) < before_suck.distance_to(ORIGIN),
		"sucked glue still travels toward its owner")
	ball.free()

	ball = await _shoot(60.0)
	_assert(ball.get("state") == 1, "uncovered part of the same wall remains sticky")
	ball.free()

	_zone.enabled = false
	ball = await _shoot()
	_assert(ball.get("state") == 1, "disabled zone does not block adhesion")
	ball.free()

	var overlapping := ZONE_SCENE.instantiate() as ZoneScript
	overlapping.position = _zone.position
	overlapping.region_size = _zone.region_size
	_fixture.add_child(overlapping)
	ball = await _shoot()
	_assert_reflected(ball, "enabled overlapping zone wins over a disabled zone")
	ball.free()
	overlapping.free()
	_assert(not ZoneScript.blocks_wall_contact(_fixture, ORIGIN + Vector2(90.0, 0.0)),
		"freed zones leave no stale coverage")

	_zone.enabled = true
	_zone.region_size = Vector2(80.0, 2.0)
	_zone.rotation = PI * 0.5
	ball = await _shoot()
	_assert_reflected(ball, "rotated rectangle covers the matching wall surface")
	ball.free()

	_zone.rotation = 0.0
	_zone.region_size = Vector2(10.0, 20.0)
	_zone.scale = Vector2(0.5, 2.0)
	ball = await _shoot(15.0)
	_assert_reflected(ball, "non-uniform scale is applied to coverage")
	ball.free()
	ball = await _shoot(25.0)
	_assert(ball.get("state") == 1, "scaled rectangle still has bounded coverage")
	ball.free()

	_zone.scale = Vector2.ONE
	_zone.region_size = Vector2(2.0, 140.0)
	ball = await _shoot(60.0)
	_assert_reflected(ball, "resizing an existing zone updates collision coverage")
	ball.free()

	_zone.region_size = Vector2(300.0, 400.0)
	ball = await _shoot(140.0)
	_assert(ball.get("state") == 0 and (ball.get("fly_velocity") as Vector2).x > 0.0,
		"zone volume does not collide with glue passing through empty space")
	ball.free()

	_wall.collision_layer = 0
	var resting_ball := _new_ball()
	resting_ball.position = Vector2(100.0, 0.0)
	resting_ball.call("place_at_rest")
	ball = await _shoot()
	_assert(ball.get("state") == 1, "zone does not change glue-to-glue stacking")
	ball.free()
	_assert(resting_ball.get("state") == 1, "zone does not remove existing resting glue")
	resting_ball.free()

	_zone.enabled = false
	_wall.collision_layer = 2
	ball = await _shoot()
	_assert_reflected(ball, "smooth walls still reflect without zone coverage")
	ball.free()

	_zone.free()
	_wall.collision_layer = 1
	var viewport := SubViewport.new()
	viewport.size = Vector2i(64, 64)
	viewport.world_2d = World2D.new()
	root.add_child(viewport)
	var other_world_zone := ZONE_SCENE.instantiate() as ZoneScript
	other_world_zone.position = ORIGIN + Vector2(90.0, 0.0)
	viewport.add_child(other_world_zone)
	_assert(other_world_zone.get_world_2d() != _fixture.get_world_2d(),
		"isolation test uses a separate physics world")
	ball = await _shoot()
	_assert(ball.get("state") == 1, "zones in another World2D cannot affect this wall")
	ball.free()
	viewport.free()

	var transformed_parent := Node2D.new()
	transformed_parent.position = Vector2(260.0, -30.0)
	transformed_parent.rotation = 0.4
	transformed_parent.scale = Vector2(2.0, 0.7)
	_fixture.add_child(transformed_parent)
	var child_zone := ZONE_SCENE.instantiate() as ZoneScript
	child_zone.position = Vector2(30.0, 15.0)
	child_zone.region_size = Vector2(80.0, 40.0)
	transformed_parent.add_child(child_zone)
	_assert(child_zone.contains_wall_contact(child_zone.to_global(Vector2(39.0, 19.0))),
		"parent transforms are included in the point test")
	_assert(not child_zone.contains_wall_contact(child_zone.to_global(Vector2(41.0, 19.0))),
		"parent transforms do not expand the local bounds")
	child_zone.region_size = Vector2(-10.0, 0.0)
	_assert(child_zone.region_size == Vector2.ONE, "invalid rectangle dimensions clamp to positive sizes")
	transformed_parent.free()

	_assert(get_nodes_in_group(ZoneScript.GROUP_NAME).is_empty(), "all zone registrations clean up with their scenes")
	_fixture.free()
	await process_frame
	print("NO-STICK ZONE: %d checks, %s" % [_checks, "FAIL" if _failed else "PASS"])
	quit(1 if _failed else 0)


func _new_ball() -> CharacterBody2D:
	var ball := _ball_scene.instantiate() as CharacterBody2D
	ball.set_physics_process(false)
	_fixture.add_child(ball)
	ball.set_physics_process(false)
	return ball


func _shoot(y := 0.0) -> CharacterBody2D:
	var ball := _new_ball()
	ball.call("begin_fly", ORIGIN + Vector2(0.0, y), Vector2.RIGHT, 600.0)
	# Flush shape, layer and deferred collision-enable changes before moving.
	await physics_frame
	await physics_frame
	ball.call("_physics_fly", 0.25)
	return ball


func _assert_reflected(ball: CharacterBody2D, label: String) -> void:
	var flight: Vector2 = ball.get("fly_velocity")
	_assert(ball.get("state") == 0 and flight.x < 0.0, label)
	_assert(ball.collision_layer == 8 and is_equal_approx(flight.length(), 600.0),
		label + " (flight layer and speed preserved)")


func _assert(condition: bool, label: String) -> void:
	_checks += 1
	print("ASSERT %s: %s" % ["PASS" if condition else "FAIL", label])
	if not condition:
		_failed = true
