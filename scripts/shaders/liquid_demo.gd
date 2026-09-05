class_name LiquidDemo
extends Node2D
## Single wobbling liquid ball for the shader test scene, driven by the
## liquid_ball shader on its LiquidSprite child. The test panel drives it
## through apply().

var radius := 60.0
var drift_speed := 40.0
var wobble := 0.05
var tint := Color(0.95, 0.95, 1.0, 1.0)

var _time := 0.0
var _base := Vector2.ZERO


func _ready() -> void:
	_base = position


func _process(delta: float) -> void:
	_time += delta
	position = _base + Vector2(sin(_time * 0.9) * 20.0, cos(_time * 0.7) * 14.0)
	var mat := _get_material()
	if mat != null:
		mat.set_shader_parameter("time", _time)


func _get_material() -> ShaderMaterial:
	var spr := get_node_or_null("LiquidSprite")
	if spr == null:
		return null
	return spr.material as ShaderMaterial


func apply(name: String, v: Variant) -> void:
	var mat := _get_material()
	if mat == null:
		return
	match name:
		"radius":
			radius = float(v)
			var spr := get_node_or_null("LiquidSprite")
			if spr != null:
				spr.scale = Vector2.ONE * (radius / 60.0)
		"wobble":
			wobble = float(v)
			mat.set_shader_parameter("wobble", wobble)
		"drift":
			drift_speed = float(v)
		"scatter":
			scatter()


func scatter() -> void:
	_base = Vector2(randf_range(260, 980), randf_range(140, 460))
	position = _base


func is_shader_ready() -> bool:
	return _get_material() != null and _get_material().shader != null
