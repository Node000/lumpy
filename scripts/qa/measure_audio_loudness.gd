extends SceneTree
## Loudness probe for the Audio/ folder: plays each file through an
## AudioEffectCapture bus and reports duration / RMS / peak, plus the volume_db
## needed to reach a target RMS. Run windowed or headless:
##   godot --path . --script res://scripts/qa/measure_audio_loudness.gd
## (A real audio driver must mix; if the headless run reports 0 samples, run
##  without --headless.)

const TARGET_RMS_DB := -22.5  # dBFS, must match GameTuning.sfx_target_loudness_db
const BGM_TARGET_RMS_DB := -23.0  # dBFS baseline the BGM slot is mixed at
const BGM_CAPTURE_CAP := 30.0  # seconds of music to capture before stopping
const BUS_NAME := &"MeasureBus"

var _files: Array[Dictionary] = [
	{"name": "jump.wav", "path": "res://Audio/jump.wav", "bgm": false},
	{"name": "glueUP.ogg", "path": "res://Audio/glueUP.ogg", "bgm": false},
	{"name": "shoot.wav", "path": "res://Audio/shoot.wav", "bgm": false},
	{"name": "Digital Lemonade.mp3", "path": "res://Audio/Digital Lemonade.mp3", "bgm": true},
]
var _idx := 0
var _player: AudioStreamPlayer = null
var _samples: Array[float] = []
var _elapsed := 0.0
var _done := false


func _initialize() -> void:
	_ensure_capture_bus()
	_run_next.call_deferred()


func _ensure_capture_bus() -> void:
	var idx := AudioServer.get_bus_index(BUS_NAME)
	if idx == -1:
		AudioServer.add_bus()
		idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, String(BUS_NAME))
	AudioServer.set_bus_volume_db(idx, 0.0)
	if AudioServer.get_bus_effect_count(idx) == 0:
		var capture := AudioEffectCapture.new()
		capture.buffer_length = 2.0
		AudioServer.add_bus_effect(idx, capture)


func _drain() -> void:
	var idx := AudioServer.get_bus_index(BUS_NAME)
	var effect := AudioServer.get_bus_effect(idx, 0) as AudioEffectCapture
	while effect.get_frames_available() > 0:
		for frame in effect.get_buffer(512):
			_samples.append((frame.x + frame.y) * 0.5)


func _run_next() -> void:
	_done = false
	_elapsed = 0.0
	_samples.clear()
	var entry: Dictionary = _files[_idx]
	_player = AudioStreamPlayer.new()
	_player.stream = load(entry["path"])
	_player.bus = String(BUS_NAME)
	_player.volume_db = 0.0
	root.add_child(_player)
	_player.play()
	print("Measuring %s (%.2f s)..."
			% [entry["name"], _player.stream.get_length()])


func _process(delta: float) -> bool:
	if _player == null:
		return false
	_drain()
	_elapsed += delta
	var cap := BGM_CAPTURE_CAP if _files[_idx]["bgm"] else _player.stream.get_length() + 1.0
	if not _done and (_player.playing == false or _elapsed >= cap):
		_done = true
		_player.stop()
		_player.queue_free()
		_player = null
		_report.call_deferred()
	return false


func _report() -> void:
	_drain()
	var entry: Dictionary = _files[_idx]
	var name: String = entry["name"]
	var db := func(x: float) -> float: return 20.0 * log(x) / log(10.0) if x > 0.0 else -120.0
	var n := _samples.size()
	var duration := 0.0
	var rms := 0.0
	var peak := 0.0
	if n > 0:
		var total := 0.0
		for s in _samples:
			total += s * s
			var a := absf(s)
			if a > peak:
				peak = a
		rms = sqrt(total / float(n))
		duration = float(n) / float(AudioServer.get_mix_rate())
	var target := BGM_TARGET_RMS_DB if entry["bgm"] else TARGET_RMS_DB
	print("%-22s dur=%7.2fs samples=%6d rms=%6.1f peak=%6.1f  gain_to_%+.0fdB=%+6.1f"
			% [name, duration, n, db.call(rms), db.call(peak), target, target - db.call(rms)])
	_idx += 1
	if _idx >= _files.size():
		print("MEASURE DONE")
		quit(0)
	else:
		_run_next()
