extends SceneTree

## Headless behavioral test for RoomCamera: startup snap, room containment
## lookup, pan on crossing into a neighbouring room, and in-room lock.
## Run with:
##   godot --headless --path . --script res://tests/test_room_camera.gd

var _failed := false


func _initialize() -> void:
	await _run()
	if _failed:
		print("ASSERT FAIL: one or more room-camera checks failed")
		quit(1)
	else:
		print("ASSERT PASS: all room-camera checks passed")
		quit(0)


func _run() -> void:
	var scene := load("res://scenes/levels/player_test.tscn") as PackedScene
	_assert(scene != null, "player test scene loads")
	var level := scene.instantiate()
	root.add_child(level)
	await process_frame
	await _physics(3)

	var room_camera := level.get_node_or_null("RoomCamera")
	_assert(room_camera != null, "room camera node exists")
	_assert(room_camera.has_method("current_room"), "room camera has room tracking API")

	var cam := room_camera.get_node_or_null("Camera2D") as Camera2D
	_assert(cam != null, "room camera created its Camera2D child")
	_assert(cam.is_current(), "room camera camera is current")

	var regions: Array = level.find_children("*", "RoomRegion", true, false)
	_assert(regions.size() >= 2, "level exposes at least two RoomRegion markers (got %d)" % regions.size())

	var player := level.get_node_or_null("Player") as Node2D
	_assert(player != null, "player exists")
	var start_room: Node = room_camera.call("current_room")
	_assert(start_room != null, "camera locked onto a room at start")
	var start_focus: Vector2 = start_room.call("get_focus_world")
	var start_name: String = start_room.get("room_name")
	_assert(start_room.call("contains_global", player.global_position), "player starts inside the tracked room (%s)" % start_name)

	# Zoom should have been computed from the widest room and viewport.
	var z: Vector2 = cam.zoom
	_assert(z.x > 0.0 and is_equal_approx(z.x, z.y), "zoom is positive and uniform (%s)" % str(z))
	_assert(cam.global_position.is_equal_approx(start_focus), "camera snapped to start room focus (got %s)" % str(cam.global_position))

	# Pick a target room to pan into: prefer a neighbour roughly on the same
	# horizontal band and east of the start room, else any other room.
	var target_room: Node2D = null
	var best_gap := INF
	for marker in regions:
		var region := marker as Node2D
		if region == null or region == start_room:
			continue
		var focus: Vector2 = region.call("get_focus_world")
		var band_ok := focus.y > start_focus.y - 240.0 and focus.y < start_focus.y + 240.0
		var gap := focus.x - start_focus.x
		if band_ok and gap > 0.0 and gap < best_gap:
			best_gap = gap
			target_room = region
	if target_room == null:
		var farthest := -INF
		for marker in regions:
			var region := marker as Node2D
			if region == null or region == start_room:
				continue
			var d: float = start_focus.distance_squared_to(region.call("get_focus_world"))
			if d > farthest:
				farthest = d
				target_room = region
	_assert(target_room != null, "level has another room to pan into")
	var target_focus: Vector2 = target_room.call("get_focus_world")
	var target_name: String = target_room.get("room_name")

	# Freeze the player so gravity can't drag it out of the room mid-pan.
	player.set_physics_process(false)
	player.global_position = target_focus
	await _physics(8)
	var room_b: Node = room_camera.call("current_room")
	_assert(room_b != null and room_b.get("room_name") == target_name, "entering %s changes tracked room (got %s)" % [target_name, str(room_b.get("room_name") if room_b != null else null)])
	var during: Vector2 = cam.global_position
	var heading := target_focus - start_focus
	_assert(heading.dot(during - start_focus) > 0.0 and during.distance_to(target_focus) < start_focus.distance_to(target_focus), "camera pans toward the entered room (cam=%s target=%s)" % [str(during), str(target_focus)])

	await _physics(80)
	_assert(cam.global_position.is_equal_approx(target_focus), "camera settles on %s focus (got %s)" % [target_name, str(cam.global_position)])
	var settled: Vector2 = cam.global_position

	# Move within the same room: camera stays put.
	player.global_position = player.global_position + Vector2(60.0, -60.0)
	await _physics(10)
	_assert(cam.global_position.is_equal_approx(settled), "in-room movement keeps camera locked")

	# Jump straight to a far room (teleport): pan still ends on the right focus.
	var far_room: Node2D = null
	var far_dist := -INF
	for marker in regions:
		var region := marker as Node2D
		if region == null or region == target_room:
			continue
		var d: float = target_focus.distance_squared_to(region.call("get_focus_world"))
		if d > far_dist:
			far_dist = d
			far_room = region
	var far_focus: Vector2 = far_room.call("get_focus_world")
	var far_name: String = far_room.get("room_name")
	player.global_position = far_focus
	await _physics(3)
	var room_d: Node = room_camera.call("current_room")
	_assert(room_d != null and room_d.get("room_name") == far_name, "far teleport lands on %s (got %s)" % [far_name, str(room_d.get("room_name") if room_d != null else null)])
	await _physics(90)
	_assert(cam.global_position.is_equal_approx(far_focus), "camera settles on %s focus (got %s)" % [far_name, str(cam.global_position)])
	player.set_physics_process(true)

	level.free()


func _assert(condition: bool, label: String) -> void:
	if condition:
		print("ASSERT PASS: " + label)
	else:
		print("ASSERT FAIL: " + label)
		_failed = true


func _physics(count: int) -> void:
	for _i in count:
		await physics_frame
