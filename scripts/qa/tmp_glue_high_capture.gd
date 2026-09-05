extends SceneTree

var _started_msec := 0
var _step := 0


func _initialize() -> void:
	var packed := load("res://scenes/levels/player_test.tscn") as PackedScene
	if packed == null:
		push_error("missing scene")
		quit(1)
		return
	var level := packed.instantiate()
	root.add_child(level)
	_started_msec = Time.get_ticks_msec()


func _process(_delta: float) -> bool:
	var elapsed := Time.get_ticks_msec() - _started_msec
	if _step == 0 and elapsed > 300:
		_step = 1
		var player := root.get_node_or_null("PlayerTest/Player")
		if player == null:
			player = root.get_node_or_null("PlayerTest/Player")
		if player != null:
			player.call("set_glue_count", 120)
		else:
			push_error("no player")
			quit(1)
			return true
	if _step == 1 and elapsed > 2600:
		var image := root.get_viewport().get_texture().get_image()
		if image == null:
			push_error("no image")
			quit(1)
			return true
		var err := image.save_png("user://tmp_glue_high.png")
		if err != OK:
			push_error("save failed")
			quit(1)
			return true
		print("TMP_CAPTURED")
		quit(0)
		return true
	return false
