extends Node
## 跨场景音频管理器（autoload：AudioManager）。
## 启动时确保 BGM / SFX 两条音频总线；持有 1 个 BGM 播放器（BGM 总线，循环整曲）
## 和 6 个轮换复用的 SFX 播放器（SFX 总线，最多并行 6 个音效）。
## 各音效的播放增益与 glueUP 音高范围都在 GameTuning 的 # Audio 段，方便试听调参。

const BUS_BGM := &"BGM"
const BUS_SFX := &"SFX"
const SFX_POOL_SIZE := 6
const GLUE_UP_COALESCE := 0.05  # s: glueUP 最小重触发间隔，防止大批吸球时叠到爆音

const STREAM_BGM := preload("res://Audio/Digital Lemonade.mp3")
const STREAM_JUMP := preload("res://Audio/jump.wav")
const STREAM_SHOOT := preload("res://Audio/shoot.wav")
const STREAM_GLUE_UP := preload("res://Audio/glueUP.ogg")

var _bgm_player: AudioStreamPlayer
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_next := 0
var _last_glue_up_time := -INF


func _ready() -> void:
	# 暂停菜单打开时，音频不受场景树暂停影响，由各播放逻辑自行决定。
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_bus(BUS_BGM)
	_ensure_bus(BUS_SFX)
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.bus = String(BUS_BGM)
	add_child(_bgm_player)
	for i in SFX_POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.bus = String(BUS_SFX)
		add_child(player)
		_sfx_players.append(player)
	play_bgm()


func _ensure_bus(bus_name: StringName) -> void:
	if AudioServer.get_bus_index(bus_name) != -1:
		return
	AudioServer.add_bus()
	var idx := AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, String(bus_name))


func play_bgm() -> void:
	if _bgm_player == null or STREAM_BGM == null:
		return
	# 全曲循环：导入参数里未开 loop，这里在运行时补上。
	if STREAM_BGM.get("loop") != null:
		STREAM_BGM.set("loop", true)
	_bgm_player.stream = STREAM_BGM
	_bgm_player.volume_db = GameTuning.bgm_gain_db
	_bgm_player.play()


func stop_bgm() -> void:
	if _bgm_player != null:
		_bgm_player.stop()


func play_sfx_jump() -> void:
	_play(_pick_slot(), STREAM_JUMP, GameTuning.sfx_jump_gain_db, 1.0)


func play_sfx_shoot() -> void:
	_play(_pick_slot(), STREAM_SHOOT, GameTuning.sfx_shoot_gain_db, 1.0)


## 收集到一颗胶球时播放一次；pitch 随角色当前胶量百分比升高
## （0% -> glue_up_pitch_min，100% -> glue_up_pitch_max，指数映射跨一个八度）。
func play_glue_up(percent: float) -> void:
	# 同一波吸球里多颗球几乎同时到达：过密时丢弃本次触发，只保留最新音高，
	# 让音效成为逐级升高的琶音而不是同一时刻叠十几层的爆音。
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_glue_up_time < GLUE_UP_COALESCE:
		return
	_last_glue_up_time = now
	_play(_pick_slot(), STREAM_GLUE_UP, GameTuning.sfx_glue_up_gain_db, glue_up_pitch(percent))


## 胶量百分比(0..1) -> pitch_scale：指数映射使听感上按等音程递升。
func glue_up_pitch(percent: float) -> float:
	var p := clampf(percent, 0.0, 1.0)
	var min_pitch: float = GameTuning.glue_up_pitch_min
	var max_pitch: float = GameTuning.glue_up_pitch_max
	return min_pitch * pow(max_pitch / min_pitch, p)


func _pick_slot() -> AudioStreamPlayer:
	var player := _sfx_players[_sfx_next]
	_sfx_next = (_sfx_next + 1) % SFX_POOL_SIZE
	return player


func _play(player: AudioStreamPlayer, stream: AudioStream, volume_db: float, pitch_scale: float) -> void:
	if player == null or stream == null:
		return
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch_scale
	player.play()


func get_sfx_volume() -> float:
	var idx := AudioServer.get_bus_index(BUS_SFX)
	return AudioServer.get_bus_volume_linear(idx) if idx != -1 else 1.0


func set_sfx_volume(value: float) -> void:
	var idx := AudioServer.get_bus_index(BUS_SFX)
	if idx != -1:
		AudioServer.set_bus_volume_linear(idx, clampf(value, 0.0, 1.0))


func get_bgm_volume() -> float:
	var idx := AudioServer.get_bus_index(BUS_BGM)
	return AudioServer.get_bus_volume_linear(idx) if idx != -1 else 1.0


func set_bgm_volume(value: float) -> void:
	var idx := AudioServer.get_bus_index(BUS_BGM)
	if idx != -1:
		AudioServer.set_bus_volume_linear(idx, clampf(value, 0.0, 1.0))
