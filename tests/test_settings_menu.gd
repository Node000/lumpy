extends SceneTree

## Headless smoke test for AudioManager buses/volume and the SettingsMenu
## Esc pause toggle. Run with:
##   godot --headless --path . --script res://tests/test_settings_menu.gd

var _failed := false
var _audio_manager: Node
var _settings_menu: Node


func _initialize() -> void:
	_audio_manager = root.get_node_or_null("AudioManager")
	_settings_menu = root.get_node_or_null("SettingsMenu")
	await _run()
	if _failed:
		print("ASSERT FAIL: one or more settings/audio checks failed")
		quit(1)
	else:
		print("ASSERT PASS: audio buses and settings menu behave correctly")
		quit(0)


func _run() -> void:
	await _settle()
	_assert(_audio_manager != null, "audio manager autoload exists")
	_assert(_settings_menu != null, "settings menu autoload exists")
	_assert(AudioServer.get_bus_index(&"BGM") != -1, "BGM bus exists")
	_assert(AudioServer.get_bus_index(&"SFX") != -1, "SFX bus exists")

	_audio_manager.call("set_sfx_volume", 0.4)
	_assert(is_equal_approx(_audio_manager.call("get_sfx_volume"), 0.4), "sfx volume setter updates bus")
	_audio_manager.call("set_bgm_volume", 0.25)
	_assert(is_equal_approx(_audio_manager.call("get_bgm_volume"), 0.25), "bgm volume setter updates bus")
	_audio_manager.call("set_sfx_volume", 1.0)
	_audio_manager.call("set_bgm_volume", 1.0)

	_assert(not _settings_menu.visible and not paused, "settings menu starts closed and unpaused")

	await _press_toggle()
	_assert(_settings_menu.visible, "esc press opens settings menu")
	_assert(paused, "settings menu pauses the game")
	var sfx_slider: HSlider = _settings_menu.get("_sfx_slider")
	_assert(is_equal_approx(sfx_slider.value, 1.0), "sfx slider synced from bus")

	await _settle()
	var bgm_slider: HSlider = _settings_menu.get("_bgm_slider")
	var resume_button: Button = _settings_menu.get("_resume_button")
	_assert(sfx_slider.size.x > 0.0 and bgm_slider.size.x > 0.0, "volume sliders laid out with width")
	_assert(resume_button.visible and resume_button.size.y > 0.0, "resume button laid out")
	_assert(_settings_menu.get("_sfx_value").text == "100%", "sfx value label formatted")

	sfx_slider.value = 0.6
	await process_frame
	_assert(is_equal_approx(_audio_manager.call("get_sfx_volume"), 0.6), "sfx slider drag updates bus volume")
	_audio_manager.call("set_sfx_volume", 1.0)

	await _press_toggle()
	_assert(not _settings_menu.visible and not paused, "esc press again closes menu and resumes")


func _settle() -> void:
	for _i in 3:
		await process_frame


func _press_toggle() -> void:
	Input.action_press("toggle_settings")
	await process_frame
	await process_frame
	Input.action_release("toggle_settings")
	await process_frame


func _assert(condition: bool, label: String) -> void:
	if condition:
		print("ASSERT PASS: " + label)
	else:
		print("ASSERT FAIL: " + label)
		_failed = true
