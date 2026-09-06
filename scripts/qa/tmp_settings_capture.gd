extends SceneTree

## Temporary visual QA: capture the settings menu overlay while paused.
## Windowed run only (no --headless). Not part of the normal test suite.

var _started_msec := 0
var _menu_opened := false
var _captured := false


func _initialize() -> void:
	var packed := load("res://scenes/levels/player_test.tscn") as PackedScene
	root.add_child(packed.instantiate())
	_started_msec = Time.get_ticks_msec()


func _process(_delta: float) -> bool:
	if not _menu_opened and Time.get_ticks_msec() - _started_msec > 500:
		_menu_opened = true
		var menu := root.get_node_or_null("SettingsMenu")
		if menu != null:
			menu.call("open_menu")
	if _captured or Time.get_ticks_msec() - _started_msec < 2500:
		return false
	_captured = true
	var image := root.get_viewport().get_texture().get_image()
	if image == null:
		push_error("QA capture did not produce an image")
		quit(1)
		return true
	var err := image.save_png("res://qa/settings_menu.png")
	if err != OK:
		push_error("QA capture failed: %s" % err)
		quit(1)
		return true
	print("QA_CAPTURED: %s (%s)" % ["res://qa/settings_menu.png", image.get_size()])
	quit(0)
	return true
