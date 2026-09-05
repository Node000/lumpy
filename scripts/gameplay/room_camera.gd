class_name RoomCamera
extends Node2D
## Room-aware locked camera for the big-map level.
##
## Scans the level for RoomRegion markers, snaps onto the room that contains
## the player at start, then stays locked on that room's focus. When the
## player's centre crosses into another room it pans smoothly to the new
## room's focus (single in-flight pan; the player can keep moving meanwhile).
##
## Rooms are sized for ~1920x1080 world units and the default zoom keeps a
## room at roughly 90% of the viewport (limiting axis), so the map reads as
## one screen per room. Place this node anywhere in the level; it owns its
## Camera2D child and calls make_current() itself.

const MIN_ZOOM := 0.05
const MAX_ZOOM := 8.0

@export var pan_duration := 0.55
@export var snap_on_start := true
@export_range(0.4, 1.0) var fill_ratio := 0.9  # room fills this fraction of the viewport
@export var debug_active_room := false

var player: Node2D = null

var _camera: Camera2D = null
var _regions: Array[RoomRegion] = []
var _current: RoomRegion = null
var _pan_tween: Tween = null
var _panning := false


func _ready() -> void:
	_collect_regions()
	_camera = Camera2D.new()
	_camera.name = "Camera2D"
	add_child(_camera)
	_camera.make_current()
	player = get_parent().get_node_or_null("Player") as Node2D
	if player == null:
		player = get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		player = get_tree().get_first_node_in_group("lumpy_player") as Node2D
	# The window may not have reached its final size yet when _ready runs, so
	# compute the fit on the first real frame and keep it in sync on resize.
	_camera.get_viewport().size_changed.connect(_recompute_zoom)
	_recompute_zoom.call_deferred()
	if snap_on_start:
		var start := _room_containing(player.global_position if player != null else global_position)
		_apply_snap(start)


func set_player(value: Node2D) -> void:
	player = value


func _collect_regions() -> void:
	_regions.clear()
	# Own RoomRegion children first, then any in the same level tree.
	var own := find_children("*", "RoomRegion", true, false)
	for r in own:
		if r is RoomRegion:
			_regions.append(r)
	if get_parent() != null:
		for r in get_parent().find_children("*", "RoomRegion", true, false):
			if r is RoomRegion and not _regions.has(r):
				_regions.append(r)


func _room_containing(p: Vector2) -> RoomRegion:
	var best: RoomRegion = null
	var best_area := INF
	for r in _regions:
		if r.contains_global(p):
			var a: float = r.get_world_rect().size.x * r.get_world_rect().size.y
			if a < best_area:
				best = r
				best_area = a
	return best


func _recompute_zoom() -> void:
	# Fit so the whole (widest) room stays visible at `fill_ratio`. The window
	# can be any aspect ratio, so use whichever axis limits us the most.
	var viewport := _camera.get_viewport()
	if viewport == null:
		return
	var vp := viewport.get_visible_rect().size
	var vp_w: float = vp.x
	var vp_h: float = vp.y
	if vp_w <= 0.0 or vp_h <= 0.0:
		return
	var room_w := 1920.0  # default authored room width
	var room_h := 1080.0  # default authored room height
	for r in _regions:
		var rect := r.get_world_rect()
		room_w = maxf(room_w, rect.size.x)
		room_h = maxf(room_h, rect.size.y)
	var z_w := vp_w * fill_ratio / room_w
	var z_h := vp_h * fill_ratio / room_h
	var z := minf(z_w, z_h)  # limiting axis keeps the room fully visible
	z = clampf(z, MIN_ZOOM, MAX_ZOOM)
	_camera.zoom = Vector2(z, z)


func _process(_delta: float) -> void:
	# Panning uses a tween, so if we're mid-pan just keep polling the room
	# membership; the tween callback applies the snap at the end.
	if _panning:
		return
	var p := player.global_position if player != null else global_position
	var target := _room_containing(p)
	if target == null or target == _current:
		return
	_start_pan(target)


func _start_pan(target: RoomRegion) -> void:
	_current = target
	_panning = true
	var from: Vector2 = _camera.global_position
	var to: Vector2 = target.get_focus_world()
	if _pan_tween != null and _pan_tween.is_valid():
		_pan_tween.kill()
	_pan_tween = create_tween()
	_pan_tween.set_trans(Tween.TRANS_SINE)
	_pan_tween.set_ease(Tween.EASE_IN_OUT)
	_pan_tween.tween_property(_camera, "global_position", to, pan_duration)
	_pan_tween.tween_callback(_finish_pan)


func _apply_snap(target: RoomRegion) -> void:
	if target == null:
		return
	_current = target
	if _pan_tween != null and _pan_tween.is_valid():
		_pan_tween.kill()
	_camera.global_position = target.get_focus_world()
	_panning = false


func _finish_pan() -> void:
	_panning = false


func current_room() -> RoomRegion:
	return _current
