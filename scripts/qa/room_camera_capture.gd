extends SceneTree

## Windowed QA capture for the room-camera feature. Renders the big map,
## snaps onto the start room, then teleports the player east to Level12 so the
## pan settles, and writes two PNGs proving "one screen per room".
## NOT headless: run windowed so the viewport actually renders.
##
##   Godot_v4.7.1-stable_win64_console.exe --path . --resolution 1920x1080 \
##     --script res://scripts/qa/room_camera_capture.gd

var _started_msec := 0
var _step := 0
var _player: Node2D = null
var _cam: Camera2D = null


func _initialize() -> void:
	var packed := load("res://scenes/levels/player_test.tscn") as PackedScene
	if packed == null:
		push_error("missing scene")
		quit(1)
		return
	root.add_child(packed.instantiate())


func _process(_delta: float) -> bool:
	var elapsed := Time.get_ticks_msec() - _started_msec
	var level := root.get_node_or_null("PlayerTest")
	if level == null:
		return false
	if _step == 0:
		_step = 1
		_started_msec = Time.get_ticks_msec()
		_player = level.get_node_or_null("Player")
		var rc := level.get_node_or_null("RoomCamera")
		_cam = rc.get_node_or_null("Camera2D") as Camera2D
		return false
	if _step == 1 and elapsed > 400:
		_step = 2
		_started_msec = Time.get_ticks_msec()
		var err := root.get_viewport().get_texture().get_image().save_png("res://qa/room_start_level11.png")
		print("QA_ROOM_START: %s zoom=%s cam=%s" % ["ok" if err == OK else err, _cam.zoom, _cam.global_position])
		_player.global_position = Vector2(2609, 240)
		return false
	if _step == 2 and elapsed > 1200:
		_step = 3
		var err := root.get_viewport().get_texture().get_image().save_png("res://qa/room_level12.png")
		print("QA_ROOM_LEVEL12: %s cam=%s" % ["ok" if err == OK else err, _cam.global_position])
		quit(0)
		return true
	return false
