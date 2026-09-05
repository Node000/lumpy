class_name BlobSprite
extends Node2D
## Local shader-driven liquid ball. The Sprite2D is created here so the pooled
## scene keeps one small reusable visual component instead of a full-screen
## metaball canvas.

var color := Color(1, 1, 1, 1)
var base_radius := 6.0
var target_scale := 1.0
var wobble := 0.07
var motion_active := true
var _scale := 1.0
var _time := 0.0
var _velocity := Vector2.ZERO
var _sprite: Sprite2D
var _material: ShaderMaterial

const TEXTURE_SIZE := 128


func _ready() -> void:
	z_index = 0
	_sprite = Sprite2D.new()
	_sprite.name = "LiquidSprite"
	_sprite.centered = true
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var texture := GradientTexture2D.new()
	texture.width = TEXTURE_SIZE
	texture.height = TEXTURE_SIZE
	texture.fill = GradientTexture2D.FILL_SQUARE
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color.WHITE, Color.WHITE])
	texture.gradient = gradient
	_sprite.texture = texture
	_material = ShaderMaterial.new()
	_material.shader = load("res://shaders/liquid_blob.gdshader")
	_sprite.material = _material
	add_child(_sprite)
	# Static surface: no time-driven wobble/flow animation on the ball.
	_material.set_shader_parameter("time", 0.0)
	_material.set_shader_parameter("flow_speed", 0.0)
	_material.set_shader_parameter("distortion", 0.0)
	_material.set_shader_parameter("edge_softness", _tuning_float("glue_visual_edge_softness", 0.055))
	_material.set_shader_parameter("velocity", Vector2.ZERO)
	_material.set_shader_parameter("color", Color(color, 1.0))
	_update_sprite_scale()


func set_wobble_active(active: bool) -> void:
	pass  # animation is disabled entirely; kept as a no-op compatibility hook


func _process(delta: float) -> void:
	_scale = lerpf(_scale, target_scale, minf(delta * 20.0, 1.0))
	_update_sprite_scale()
	queue_redraw()


func set_tint(c: Color) -> void:
	color = c
	if _material != null:
		_material.set_shader_parameter("color", Color(color, 1.0))
	queue_redraw()


func set_velocity(v: Vector2) -> void:
	_velocity = v


func _draw() -> void:
	pass


func _update_sprite_scale() -> void:
	if _sprite != null:
		_sprite.scale = Vector2.ONE * (base_radius * 2.0 / float(TEXTURE_SIZE) * _scale)


func _tuning_float(property_name: String, fallback: float) -> float:
	var tuning := get_node_or_null("/root/GameTuning")
	if tuning != null:
		return float(tuning.get(property_name))
	return fallback
