class_name BlobBackdrop
extends Node2D
## Player glue collection rendered by one local metaball field.
## The field is deliberately separate from pooled GlueBall nodes: collected
## balls disappear back into the pool, while this visual is rebuilt from count.

const MAX_BLOBS := 64
const FIELD_TEXTURE_SIZE := 128.0

var radius := 15.0
var radius_target := 15.0
var color := Color(0.98, 0.965, 0.953, 1.0)

var _time := 0.0
var _bottom_y := 14.0
var _velocity := Vector2.ZERO
var _glue_count := 0
var _impact_pulse := 0.0
var _sprite: Sprite2D
var _material: ShaderMaterial


func _ready() -> void:
	z_index = 3
	_sprite = Sprite2D.new()
	_sprite.name = "LiquidCollection"
	_sprite.centered = true
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_sprite.texture = _make_field_texture()
	_material = ShaderMaterial.new()
	_material.shader = load("res://shaders/liquid_collection.gdshader")
	_sprite.material = _material
	add_child(_sprite)
	_sprite.scale = Vector2.ONE * (radius * 2.0 / FIELD_TEXTURE_SIZE)
	_update_material()


func _process(delta: float) -> void:
	_time += delta
	radius = lerpf(radius, radius_target, minf(delta * 12.0, 1.0))
	_impact_pulse = move_toward(_impact_pulse, 0.0, delta * 2.6)
	# Keep the lower edge anchored while the upper surface grows upward.
	position.y = _bottom_y - radius
	_update_material()


func set_body_radius(_ignored: float) -> void:
	# Kept as a narrow compatibility entry point for older scene builders.
	set_collection_radius(radius_target)


func set_collection_radius(value: float) -> void:
	radius_target = clampf(value, 1.0, _tuning_float("player_collection_max_radius", 54.0))


func set_glue_count(count: int) -> void:
	_glue_count = clampi(count, 0, MAX_BLOBS)
	_impact_pulse = 1.0
	_update_material()


func set_bottom_anchor(value: float) -> void:
	_bottom_y = value
	position.y = _bottom_y - radius


func set_velocity(value: Vector2) -> void:
	_velocity = value


func set_glue_color(value: Color) -> void:
	color = value


func get_collection_bottom_y() -> float:
	return position.y + radius


func _make_field_texture() -> GradientTexture2D:
	var texture := GradientTexture2D.new()
	texture.width = int(FIELD_TEXTURE_SIZE)
	texture.height = int(FIELD_TEXTURE_SIZE)
	texture.fill = GradientTexture2D.FILL_SQUARE
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color.WHITE, Color.WHITE])
	texture.gradient = gradient
	return texture


func _update_material() -> void:
	if _material == null:
		return
	var positions := PackedVector2Array()
	var radii := PackedFloat32Array()
	var display_scale := maxf(radius * 2.0 / FIELD_TEXTURE_SIZE, 0.001)
	var count := clampi(_glue_count, 1, MAX_BLOBS)
	var center := Vector2(FIELD_TEXTURE_SIZE * 0.5, FIELD_TEXTURE_SIZE * 0.5)
	# Shift the whole cluster down toward the lower body so the collection
	# center sits low instead of at the player's chest.
	center += Vector2(0.0, 8.0 / display_scale)
	# One source per particle: body-placed by golden angle with tiny per-ball
	# vibration, so the player reads as a dense ball of small granules.
	for i in count:
		var source := _granule_offset(i)
		positions.append(center + source / display_scale)
		var granule_r := _tuning_float("collection_bubble_radius", 6.0) * (1.0 + sin(float(i) * 2.7 + _time) * 0.10)
		radii.append(granule_r / display_scale)
	_material.set_shader_parameter("blob_count", count)
	_material.set_shader_parameter("blob_positions", positions)
	_material.set_shader_parameter("blob_radii", radii)
	_material.set_shader_parameter("time", _time)
	_material.set_shader_parameter("surface", _tuning_float("collection_bubble_surface", 1.2))
	_material.set_shader_parameter("flow_speed", _tuning_float("glue_visual_flow_speed", 1.35))
	_material.set_shader_parameter("distortion", _tuning_float("glue_visual_distortion", 0.075) + _impact_pulse * 0.025)
	_material.set_shader_parameter("velocity", _velocity)
	_material.set_shader_parameter("color", Color(color, 1.0))
	if _sprite != null:
		_sprite.scale = Vector2.ONE * (radius * 2.0 / FIELD_TEXTURE_SIZE)


func _granule_offset(index: int) -> Vector2:
	# Golden-angle spheres-in-body placement: each granule sits inside the
	# collection disc at a deterministic spot, with a small independent
	# vibration so the mass reads as living particles rather than a skin.
	var t := _time
	var golden := float(index) * 2.39996
	# Radial height inside the disc: sqrt offsets bias toward the rim so the
	# granules look packed instead of clumped at the centre.
	var radial := sqrt(fposmod(golden * 0.381966, 1.0)) * radius * 0.80
	var phase := golden + t * (0.25 + fposmod(float(index) * 0.414214, 1.0) * 0.5)
	var wobble := 1.0 + 0.10 * sin(t * 2.1 + float(index) * 1.7)
	var pos := Vector2(cos(phase), sin(phase)) * radial * wobble
	# Squash vertically so the cluster hugs the lower body.
	pos.y *= 0.72
	pos.y += -sin(t * 1.1 + float(index) * 1.3) * 1.6
	return pos


func _source_radius(index: int) -> float:
	var count_scale := clampf(float(_glue_count) / 6.0, 0.0, 1.0)
	return lerpf(8.0, 11.0, count_scale) * (1.0 + sin(float(index) * 2.7) * 0.04)


func _tuning_float(property_name: String, fallback: float) -> float:
	var tuning := get_node_or_null("/root/GameTuning")
	if tuning != null:
		return float(tuning.get(property_name))
	return fallback
