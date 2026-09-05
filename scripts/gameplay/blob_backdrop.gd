class_name BlobBackdrop
extends Node2D
## Player glue collection made from independent, deterministic granules.
## The layout is shared with Player so every visible granule has an identical
## CollisionShape2D at the same local position and radius.

signal layout_changed(positions: PackedVector2Array, radii: PackedFloat32Array)

const GOLDEN_ANGLE := 2.39996

var radius := 15.0
var radius_target := 15.0
var color := Color(0.98, 0.965, 0.953, 1.0)

var _bottom_y := 14.0
var _glue_count := 0
var _particle_nodes: Array[BlobSprite] = []
var _layout_positions := PackedVector2Array()
var _layout_radii := PackedFloat32Array()
var _layout_dirty := true
var _is_ready := false


func _ready() -> void:
	z_index = 3
	_is_ready = true
	_rebuild_particles()


func _process(delta: float) -> void:
	var previous_radius := radius
	radius = lerpf(radius, radius_target, minf(delta * 12.0, 1.0))
	position.y = _bottom_y - radius
	if not is_equal_approx(previous_radius, radius):
		_layout_dirty = true
	if _layout_dirty:
		_rebuild_particles()


func set_collection_radius(value: float) -> void:
	radius_target = clampf(value, 1.0, _tuning_float("player_collection_max_radius", 46.0))
	_layout_dirty = true
	if _is_ready and is_equal_approx(radius, radius_target):
		_rebuild_particles()


func set_glue_count(count: int) -> void:
	_glue_count = clampi(count, 0, _tuning_int("max_glue", 120))
	_layout_dirty = true
	if _is_ready:
		_rebuild_particles()


func set_bottom_anchor(value: float) -> void:
	_bottom_y = value
	position.y = _bottom_y - radius
	if _is_ready:
		_emit_layout()


func set_glue_color(value: Color) -> void:
	color = value
	for i in _particle_nodes.size():
		_particle_nodes[i].set_tint(_particle_color(i))


func get_collection_bottom_y() -> float:
	return position.y + radius


func get_particle_layout() -> Dictionary:
	return {
		"positions": _layout_positions,
		"radii": _layout_radii,
	}


func get_particle_count() -> int:
	return _layout_positions.size()


func get_visible_particle_count() -> int:
	return _layout_positions.size()


func _rebuild_particles() -> void:
	var layout := _build_layout()
	_layout_positions = layout["positions"]
	_layout_radii = layout["radii"]
	_ensure_particle_nodes(_layout_positions.size())
	for i in _particle_nodes.size():
		var active := i < _layout_positions.size()
		_particle_nodes[i].visible = active
		if active:
			_particle_nodes[i].position = _layout_positions[i]
			_particle_nodes[i].set_radius(_layout_radii[i])
			_particle_nodes[i].set_tint(_particle_color(i))
	_layout_dirty = false
	if _is_ready:
		_emit_layout()


func _build_layout() -> Dictionary:
	var positions := PackedVector2Array()
	var radii := PackedFloat32Array()
	var collection_radius := maxf(radius, 1.0)

	var glue_radius := _tuning_float("collection_bubble_radius", 6.0)
	var glue_extent := maxf(collection_radius - glue_radius, 0.0)
	for i in _glue_count:
		var offset := Vector2.ZERO
		if i == 0:
			# This granule is the foot anchor. Its bottom is exactly the collection
			# baseline, independent of how many other particles are carried.
			offset = Vector2.DOWN * glue_extent
		else:
			var sample_count := maxi(_glue_count - 1, 1)
			var radial := sqrt(float(i) / float(sample_count)) * glue_extent
			var angle := float(i - 1) * GOLDEN_ANGLE
			offset = Vector2.from_angle(angle) * radial
		positions.append(offset)
		radii.append(glue_radius)
	return {"positions": positions, "radii": radii}


func _ensure_particle_nodes(required: int) -> void:
	while _particle_nodes.size() < required:
		var particle := BlobSprite.new()
		particle.name = "Particle%03d" % _particle_nodes.size()
		add_child(particle)
		_particle_nodes.append(particle)


func _particle_color(index: int) -> Color:
	var shade := 0.96 + fposmod(float(index) * 0.173, 1.0) * 0.06
	return Color(color.r * shade, color.g * shade, color.b * shade, color.a)


func _emit_layout() -> void:
	layout_changed.emit(_layout_positions, _layout_radii)


func _tuning_float(property_name: String, fallback: float) -> float:
	var tuning := get_node_or_null("/root/GameTuning")
	if tuning != null:
		return float(tuning.get(property_name))
	return fallback


func _tuning_int(property_name: String, fallback: int) -> int:
	var tuning := get_node_or_null("/root/GameTuning")
	if tuning != null:
		return int(tuning.get(property_name))
	return fallback
