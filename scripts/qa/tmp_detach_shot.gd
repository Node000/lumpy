extends SceneTree

## TEMP: closeup at full glue (max) to inspect the detachment between the
## particle cluster and the character. Two captures: baseline glue (10) and
## max glue (30), home camera, no room overlay.
## run: godot --path . --resolution 1920x1080 --script res://scripts/qa/tmp_detach_shot.gd

var _frame := 0
var _level: Node
var _player: Node2D = null
var _cam: Camera2D = null
var _cam_ready := false
var _shot := 0


func _initialize() -> void:
	var packed := load("res://scenes/levels/player_test.tscn") as PackedScene
	_level = packed.instantiate()
	root.add_child(_level)
	_player = _level.get_node_or_null("Player")


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame == 2 and not _cam_ready:
		_cam_ready = true
		var rc = _level.get_node_or_null("RoomCamera")
		if rc != null:
			rc.process_mode = Node.PROCESS_MODE_DISABLED
			var old = rc.get_node_or_null("Camera2D")
			if old != null:
				old.enabled = false
		_cam = Camera2D.new()
		_cam.zoom = Vector2(2.0, 2.0)
		root.add_child(_cam)
		_cam.make_current()
		return false
	if _frame < 90:
		return false
	_cam.global_position = _player.global_position
	if _shot == 0 and _frame == 120:
		_shot = 1
		var err := root.get_viewport().get_texture().get_image().save_png("C:/Users/SOP_O/AppData/Local/Temp/lumpy_detach_start.png")
		print("saved start: ", "ok" if err == OK else err)
	if _frame == 160:
		_player.call("set_glue_count", _level.get_node("GameTuning") if false else 30)
		if _level.has_node("Player") and _player != null:
			var g = root.get_node_or_null("GameTuning")
			if g != null:
				_player.call("set_glue_count", g.max_glue)
	if _shot == 1 and _frame == 220:
		var err := root.get_viewport().get_texture().get_image().save_png("C:/Users/SOP_O/AppData/Local/Temp/lumpy_detach_max.png")
		print("saved max: ", "ok" if err == OK else err)
		quit(0)
		return true
	return false
