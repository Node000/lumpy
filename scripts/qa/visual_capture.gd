extends SceneTree

## Runs a selected scene and captures it after a short delay. Intended for
## windowed visual QA: do not add --headless to the Godot invocation.

var _scene_path := "res://scenes/levels/player_test.tscn"
var _output := "user://lumpy_qa.png"
var _started_msec := 0
var _captured := false


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--scene="):
			_scene_path = arg.trim_prefix("--scene=")
		elif arg.begins_with("--output="):
			_output = arg.trim_prefix("--output=")
	var packed := load(_scene_path) as PackedScene
	if packed == null:
		push_error("QA scene missing: " + _scene_path)
		quit(1)
		return
	root.add_child(packed.instantiate())
	_started_msec = Time.get_ticks_msec()


func _process(_delta: float) -> bool:
	if _captured or Time.get_ticks_msec() - _started_msec < 2000:
		return false
	_captured = true
	var image := root.get_viewport().get_texture().get_image()
	if image == null:
		push_error("QA capture did not produce an image")
		quit(1)
		return true
	var err := image.save_png(_output)
	if err != OK:
		push_error("QA capture failed: %s" % err)
		quit(1)
		return true
	print("QA_CAPTURED: %s (%s)" % [_output, image.get_size()])
	quit(0)
	return true
