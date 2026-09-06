extends CanvasLayer
## 跨场景设置菜单（autoload：SettingsMenu）。
## Esc 打开/关闭；打开时暂停游戏。菜单自身以 ALWAYS 运行，
## 暂停期间仍然可以拖动滑块、点击按钮。
## 音量条直接控制 AudioManager 的 BGM / SFX 总线音量。

const TOGGLE_ACTION := &"toggle_settings"

var _open := false
var _sfx_slider: HSlider
var _bgm_slider: HSlider
var _sfx_value: Label
var _bgm_value: Label
var _resume_button: Button


func _ready() -> void:
	# 需要同时处理暂停前（打开菜单）与暂停后（关闭菜单）的 Esc，用 ALWAYS。
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	_build_ui()
	visible = false


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed(TOGGLE_ACTION):
		if _open:
			close_menu()
		else:
			open_menu()


func open_menu() -> void:
	_open = true
	_sync_sliders()
	visible = true
	get_tree().paused = true
	_resume_button.grab_focus()


func close_menu() -> void:
	_open = false
	visible = false
	get_tree().paused = false


func _sync_sliders() -> void:
	_sfx_slider.set_value_no_signal(AudioManager.get_sfx_volume())
	_bgm_slider.set_value_no_signal(AudioManager.get_bgm_volume())
	_update_value_labels()


func _update_value_labels() -> void:
	_sfx_value.text = _format_percent(_sfx_slider.value)
	_bgm_value.text = _format_percent(_bgm_slider.value)


func _format_percent(value: float) -> String:
	return "%d%%" % int(round(value * 100.0))


func _build_ui() -> void:
	var root := Control.new()
	root.name = "SettingsRoot"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)

	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0.0, 0.0, 0.0, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style())
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	margin.add_child(box)

	var title := Label.new()
	title.text = "设置"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	box.add_child(title)

	var sfx_controls: Array = _build_slider_row("音效音量")
	_sfx_slider = sfx_controls[0]
	_sfx_value = sfx_controls[1]
	_sfx_slider.value_changed.connect(_on_volume_changed.bind(AudioManager.set_sfx_volume))
	box.add_child(sfx_controls[2])

	var bgm_controls: Array = _build_slider_row("音乐音量")
	_bgm_slider = bgm_controls[0]
	_bgm_value = bgm_controls[1]
	_bgm_slider.value_changed.connect(_on_volume_changed.bind(AudioManager.set_bgm_volume))
	box.add_child(bgm_controls[2])

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 6)
	box.add_child(spacer)

	_resume_button = Button.new()
	_resume_button.text = "返回游戏"
	_resume_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_resume_button.pressed.connect(close_menu)
	box.add_child(_resume_button)

	var quit_button := Button.new()
	quit_button.text = "退出游戏"
	quit_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	quit_button.pressed.connect(_on_quit_pressed)
	box.add_child(quit_button)

	var hint := Label.new()
	hint.text = "Esc：打开 / 关闭设置"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", Color(0.75, 0.78, 0.88, 1))
	hint.add_theme_font_size_override("font_size", 13)
	box.add_child(hint)


func _build_slider_row(title_text: String) -> Array:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	var label := Label.new()
	label.text = title_text
	label.custom_minimum_size = Vector2(90, 0)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)

	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.value = 1.0
	slider.custom_minimum_size = Vector2(200, 0)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(slider)

	var value_label := Label.new()
	value_label.text = "100%"
	value_label.custom_minimum_size = Vector2(52, 0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value_label.add_theme_font_size_override("font_size", 14)
	row.add_child(value_label)

	return [slider, value_label, row]


func _on_volume_changed(value: float, on_changed: Callable) -> void:
	on_changed.call(value)
	_update_value_labels()


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.06, 0.10, 0.96)
	style.border_color = Color(0.46, 0.72, 0.84, 0.8)
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	return style


func _on_quit_pressed() -> void:
	get_tree().quit()
