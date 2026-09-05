extends Control
## Floating inspector for the shader test scenes. Talks to one or two demo
## controllers (MetaballField / LiquidDemo) via a common apply(name, value).
## Press H to toggle visibility.

var _controllers: Array = []
var _sliders: Dictionary = {}
var _labels: Array = []

const WIDTH := 300.0
const ROW_H := 26.0
const PAD := 10.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_create_layout()
	visible = true
	queue_redraw()


func _draw() -> void:
	draw_style_box(_panel_style(), Rect2(Vector2.ZERO, size))


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.04, 0.07, 0.92)
	style.border_color = Color(0.46, 0.72, 0.84, 0.8)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	return style


func add_controller(c: Node) -> void:
	_controllers.append(c)


func _create_layout() -> void:
	custom_minimum_size = Vector2(WIDTH, 0)
	var vbox := VBoxContainer.new()
	vbox.name = "Rows"
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = PAD
	vbox.offset_right = -PAD
	vbox.offset_top = PAD
	vbox.offset_bottom = -PAD
	vbox.add_theme_constant_override("separation", 4)
	add_child(vbox)

	_add_slider(vbox, "blobs", "blobs", 1, 24, 7)
	_add_slider(vbox, "radius", "radius", 20, 200, 90)
	_add_slider(vbox, "surface", "surface", 0.05, 1.0, 0.5)
	_add_slider(vbox, "edge", "edge", 0.0, 0.5, 0.12)
	_add_slider(vbox, "wobble", "wobble", 0.0, 0.2, 0.05)
	_add_slider(vbox, "drift", "drift", 0.0, 200.0, 40.0)

	var row := HBoxContainer.new()
	var scatter := Button.new()
	scatter.text = "scatter"
	scatter.pressed.connect(_on_scatter)
	row.add_child(scatter)
	var hint := Label.new()
	hint.text = "H: toggle panel"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(hint)
	vbox.add_child(row)


func _add_slider(vbox: VBoxContainer, key: String, label_text: String, min_v: float, max_v: float, val: float) -> void:
	var row := HBoxContainer.new()
	var lab := Label.new()
	lab.text = label_text
	lab.custom_minimum_size = Vector2(64, 0)
	lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(lab)
	var hs := HSlider.new()
	hs.min_value = min_v
	hs.max_value = max_v
	hs.step = (max_v - min_v) / 200.0
	hs.value = val
	hs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hs.value_changed.connect(_on_value.bind(key))
	row.add_child(hs)
	var val_lab := Label.new()
	val_lab.text = str(val)
	val_lab.custom_minimum_size = Vector2(64, 0)
	val_lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val_lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(val_lab)
	vbox.add_child(row)
	_sliders[key] = [hs, val_lab]


func _on_value(v: float, key: String) -> void:
	var entry: Array = _sliders.get(key)
	if entry != null:
		(entry[1] as Label).text = "%.3f" % v
	for c in _controllers:
		if c != null and is_instance_valid(c):
			c.call("apply", key, v)


func _on_scatter() -> void:
	for c in _controllers:
		if c != null and is_instance_valid(c) and c.has_method("apply"):
			c.call("apply", "scatter", 0)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_H:
		visible = not visible
