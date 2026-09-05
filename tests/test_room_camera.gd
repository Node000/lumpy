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
	_assert(regions.size() == 11, "level exposes 11 RoomRegion markers (got %d)" % regions.size())

	var player := level.get_node_or_null("Player") as Node2D
	_assert(player != null, "player exists")
	# Player starts at (180,400) which lies inside the Level11 tile (center 688,240).
	var start_room: Node = room_camera.call("current_room")
	_assert(start_room != null, "camera locked onto a room at start")
	_assert(start_room.get("room_name") == "Level11", "start room is Level11 (got %s)" % str(start_room.get("room_name")))

	# Zoom should have been computed from the widest room and viewport.
	var z: Vector2 = cam.zoom
	_assert(z.x > 0.0 and is_equal_approx(z.x, z.y), "zoom is positive and uniform (%s)" % str(z))
	_assert(cam.global_position.is_equal_approx(Vector2(688, 240)), "camera snapped to start room focus (got %s)" % str(cam.global_position))

	# Cross east into Level12 (center 2609, 240): the camera should pan toward it.
	player.global_position = Vector2(2609, 240)
	await _physics(6)
	var room_b: Node = room_camera.call("current_room")
	_assert(room_b != null and room_b.get("room_name") == "Level12", "entering Level12 changes tracked room (got %s)" % str(room_b.get("room_name") if room_b != null else null))
	var during: Vector2 = cam.global_position
	_assert(during.x > 688.0 and during.x < 2609.0 and absf(during.y - 240.0) < 40.0, "camera pans horizontally between rooms (x=%s)" % str(during))

	await _physics(40)
	var after: Vector2 = cam.global_position
	_assert(after.is_equal_approx(Vector2(2609, 240)), "camera settles on Level12 focus (got %s)" % str(after))

	# Move within the same room: camera stays put.
	player.global_position = Vector2(2400, 300)
	await _physics(10)
	var locked: Vector2 = cam.global_position
	_assert(locked.is_equal_approx(Vector2(2609, 240)), "in-room movement keeps camera locked")

	# Cross south into Level9 (center 2610, -841): vertical pan.
	player.global_position = Vector2(2610, -841)
	await _physics(6)
	var room_c: Node = room_camera.call("current_room")
	_assert(room_c != null and room_c.get("room_name") == "Level9", "entering Level9 changes tracked room (got %s)" % str(room_c.get("room_name") if room_c != null else null))
	await _physics(40)
	_assert(cam.global_position.is_equal_approx(Vector2(2610, -841)), "camera settles on Level9 focus (got %s)" % str(cam.global_position))

	# Jump straight to a far room (teleport): pan still ends on the right focus.
	# Freeze the player so gravity can't drag it out of the room mid-pan.
	player.set_physics_process(false)
	player.global_position = Vector2(4530, -1921)
	await _physics(60)
	var room_d: Node = room_camera.call("current_room")
	_assert(room_d != null and room_d.get("room_name") == "Level7", "far teleport lands on Level7 (got %s)" % str(room_d.get("room_name") if room_d != null else null))
	_assert(cam.global_position.is_equal_approx(Vector2(4538, -1921)), "camera settles on Level7 focus (got %s)" % str(cam.global_position))
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
