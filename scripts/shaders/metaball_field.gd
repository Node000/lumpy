class_name MetaballField
extends ColorRect
## A full-rect shader quad showing a drifting metaball blob field.
## Self-contained controller: spawns blobs, wobbles them, uploads uniforms.
## The test panel drives it through apply().

const MAX_BLOBS := 24

var count := 7
var blob_radius := 90.0
var surface := 0.5
var edge := 0.12
var drift_speed := 40.0
var tint := Color(1, 1, 1, 1)

var _material: ShaderMaterial
var _time := 0.0
var _centers: Array = []
var _base_centers: Array = []


func _ready() -> void:
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/metaball_blob.gdshader")
	material = sm
	_material = material as ShaderMaterial
	# Use viewport pixel coordinates in the shader; keep the quad at a fixed
	# prototype resolution so the parameter panel can be tested consistently.
	custom_minimum_size = Vector2(1280, 720)
	size = Vector2(1280, 720)
	_material.set_shader_parameter("u_surface", surface)
	_material.set_shader_parameter("u_edge", edge)
	_material.set_shader_parameter("u_radius", blob_radius)
	_centers.resize(MAX_BLOBS)
	_base_centers.resize(MAX_BLOBS)
	scatter()


func scatter() -> void:
	for i in MAX_BLOBS:
		_base_centers[i] = Vector2(randf_range(160, 1120), randf_range(120, 560))
		_centers[i] = _base_centers[i]
	_upload_all()


func apply(name: String, v: Variant) -> void:
	match name:
		"blobs":
			count = clampi(int(v), 0, MAX_BLOBS)
			_upload_all()
		"radius":
			blob_radius = float(v)
			_setf("u_radius", blob_radius)
		"surface":
			surface = float(v)
			_setf("u_surface", surface)
		"edge":
			edge = float(v)
			_setf("u_edge", edge)
		"drift":
			drift_speed = float(v)
		"scatter":
			scatter()


func _setf(param: String, value: float) -> void:
	if _material != null:
		_material.set_shader_parameter(param, value)


func _upload_all() -> void:
	if _material == null:
		return
	var n := clampi(count, 0, MAX_BLOBS)
	_material.set_shader_parameter("u_count", n)
	var arr := PackedVector2Array()
	for i in n:
		arr.append(_centers[i])
	_material.set_shader_parameter("u_pos", arr)


func _process(delta: float) -> void:
	_time += delta
	var n := clampi(count, 0, MAX_BLOBS)
	for i in n:
		var base: Vector2 = _base_centers[i]
		_centers[i] = base + Vector2(sin(_time * 0.8 + i * 1.7), cos(_time * 0.6 + i * 0.9)) * 24.0
	_upload_all()


func get_active_blob_count() -> int:
	return clampi(count, 0, MAX_BLOBS)
