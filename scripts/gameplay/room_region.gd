class_name RoomRegion
extends Node2D
## Authoring marker that describes one camera room on the big map.
##
## Place this node at the room's centre and size `room_rect` (in the node's
## local space, so it follows the marker when you drag it) to the room's
## bounds. The RoomCamera snaps/locks onto `get_focus_world()` whenever the
## player's centre enters `room_rect`.
##
## The node draws a translucent box in the EDITOR so level authors can see and
## hand-tune each room's bounds without leaving the scene view. The overlay is
## editor-only: it never renders while the game is running.

@export var room_name := "Room"
@export var room_rect := Rect2(-960, -540, 1920, 1080)
@export var focus_override := Vector2.ZERO  # local; ZERO = room_rect centre

var _time := 0.0


func get_world_rect() -> Rect2:
	# Axis-aligned in the common (unrotated) case; room_rect lives in local
	# space so dragging the marker moves the whole room.
	return Rect2(room_rect.position + global_position, room_rect.size)


func get_focus_world() -> Vector2:
	var local_focus: Vector2 = focus_override if focus_override != Vector2.ZERO else room_rect.get_center()
	return to_global(local_focus)


func contains_global(p: Vector2) -> bool:
	return room_rect.has_point(to_local(p))


func _ready() -> void:
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	if not Engine.is_editor_hint():
		return  # authoring overlay never renders in-game
	var c := Color(0.35, 0.9, 1.0, 0.10)
	draw_rect(room_rect, c, true)
	draw_rect(room_rect, Color(0.55, 1.0, 1.0, 0.7), false, 2.0)
	var focus: Vector2 = focus_override if focus_override != Vector2.ZERO else room_rect.get_center()
	draw_circle(focus, 6.0, Color(1, 1, 1, 0.6))
	var pulse := 0.6 + 0.4 * sin(_time * 2.0)
	draw_arc(room_rect.get_center(), 90.0 + pulse * 20.0, 0.0, TAU, 24, Color(1, 1, 1, 0.5), 1.0)
	if room_name != "":
		draw_string(ThemeDB.fallback_font, focus + Vector2(14, -6), room_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1, 1, 1, 0.9))
