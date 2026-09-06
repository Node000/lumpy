extends SceneTree

## Headless smoke test for the AudioManager playback pool: pool size, event
## play calls, bus routing, and the glue-UP pitch mapping. Run with:
##   godot --headless --path . --script res://tests/test_audio_sfx.gd

var _failed := false
var _audio_manager: Node


func _initialize() -> void:
	_audio_manager = root.get_node_or_null("AudioManager")
	await _run()
	if _failed:
		print("ASSERT FAIL: one or more audio playback checks failed")
		quit(1)
	else:
		print("ASSERT PASS: audio playback pool and glue pitch behave correctly")
		quit(0)


func _run() -> void:
	await _settle()
	_assert(_audio_manager != null, "audio manager autoload exists")
	_assert(AudioServer.get_bus_index(&"BGM") != -1, "BGM bus exists")
	_assert(AudioServer.get_bus_index(&"SFX") != -1, "SFX bus exists")

	var pool: Array = _audio_manager.get("_sfx_players")
	_assert(pool.size() == 6, "sfx pool holds 6 players (design cap)")
	for player in pool:
		_assert(player.bus == "SFX", "every sfx player routes to the SFX bus")
	_assert(_audio_manager.get("_bgm_player").bus == "BGM", "bgm player routes to the BGM bus")

	var bgm_stream: AudioStream = _audio_manager.get("_bgm_player").stream
	_assert(bgm_stream != null, "bgm stream assigned")
	_assert(bgm_stream.get("loop") == true, "bgm stream loops")

	_audio_manager.call("play_sfx_jump")
	_audio_manager.call("play_sfx_shoot")
	_audio_manager.call("play_glue_up", 0.33)
	await _settle()
	_assert(_pool_has_playing(_audio_manager), "sfx pool is playing after event calls")

	_assert(_approx(_audio_manager.call("glue_up_pitch", 0.0), 0.9), "glue pitch floor 0.9 at 0%")
	_assert(_approx(_audio_manager.call("glue_up_pitch", 1.0), 1.8), "glue pitch cap 1.8 at 100%")
	var mid: float = _audio_manager.call("glue_up_pitch", 0.5)
	_assert(_approx(mid, 0.9 * sqrt(2.0)), "glue pitch midpoint is one octave halfway")
	_assert(_approx(_audio_manager.call("glue_up_pitch", -1.0), 0.9), "glue pitch clamps below 0%")
	_assert(_approx(_audio_manager.call("glue_up_pitch", 2.0), 1.8), "glue pitch clamps above 100%")

	_audio_manager.call("play_glue_up", 0.9)
	var gain: float = _audio_manager.get("_bgm_player").volume_db
	_assert(gain < 0.0, "bgm gain pulls the loud mp3 down (currently %.1f db)" % gain)


func _pool_has_playing(manager: Node) -> bool:
	for player in manager.get("_sfx_players"):
		if player.playing:
			return true
	return false


func _settle() -> void:
	for _i in 3:
		await process_frame


func _approx(a: float, b: float) -> bool:
	return absf(a - b) < 0.0001


func _assert(condition: bool, label: String) -> void:
	if condition:
		print("ASSERT PASS: " + label)
	else:
		print("ASSERT FAIL: " + label)
		_failed = true
