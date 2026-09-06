extends Node
## 跨场景音频管理器（autoload：AudioManager）。
## 启动时确保存在 BGM / SFX 两条音频总线，音量设置直接作用于对应总线，
## 供设置菜单与后续音效/音乐播放统一使用。

const BUS_BGM := &"BGM"
const BUS_SFX := &"SFX"


func _ready() -> void:
	# 暂停菜单打开时，音频不受场景树暂停影响，由各播放逻辑自行决定。
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_bus(BUS_BGM)
	_ensure_bus(BUS_SFX)


func _ensure_bus(bus_name: StringName) -> void:
	if AudioServer.get_bus_index(bus_name) != -1:
		return
	AudioServer.add_bus()
	var idx := AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, String(bus_name))


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
