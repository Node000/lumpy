@tool
class_name GlueNoStickZone
extends Node2D
## Editor-visible rectangle that makes wall contact points non-stick.
## Instance scenes/gameplay/glue_no_stick_zone.tscn in a level, move it over
## the wall surface, and adjust region_size. Rotation and scale are supported.
## This marker has no collider and never draws in-game. It only affects new
## flying-glue impacts on walls, not existing glue or glue-to-glue stacking.

const GROUP_NAME := &"glue_no_stick_zones"

@export var enabled := true:
	set(value):
		enabled = value
		queue_redraw()

## Full width and height in this node's local space, centred on its origin.
@export var region_size := Vector2(256.0, 256.0):
	set(value):
		region_size = Vector2(maxf(value.x, 1.0), maxf(value.y, 1.0))
		queue_redraw()


func _enter_tree() -> void:
	if not Engine.is_editor_hint():
		add_to_group(GROUP_NAME)


func _ready() -> void:
	queue_redraw()


func contains_wall_contact(world_position: Vector2) -> bool:
	if not enabled:
		return false
	var point := to_local(world_position)
	var half := region_size * 0.5
	# Include all four edges, unlike Rect2.has_point's exclusive bottom/right.
	return absf(point.x) <= half.x and absf(point.y) <= half.y


static func blocks_wall_contact(source: Node2D, world_position: Vector2) -> bool:
	# Called only on rough-wall impact, not every frame or every overlap.
	for node in source.get_tree().get_nodes_in_group(GROUP_NAME):
		if node is GlueNoStickZone and node.get_world_2d() == source.get_world_2d():
			if node.contains_wall_contact(world_position):
				return true
	return false


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var rect := Rect2(-region_size * 0.5, region_size)
	var edge := Color(1.0, 0.42, 0.18, 0.95) if enabled else Color(0.55, 0.55, 0.55, 0.65)
	var fill := Color(edge, 0.12 if enabled else 0.04)
	draw_rect(rect, fill, true)
	draw_rect(rect, edge, false, 2.0)
	draw_line(Vector2(-7.0, 0.0), Vector2(7.0, 0.0), edge, 2.0)
	draw_line(Vector2(0.0, -7.0), Vector2(0.0, 7.0), edge, 2.0)
	var label := "NO GLUE" if enabled else "NO GLUE (OFF)"
	draw_string(ThemeDB.fallback_font, rect.position + Vector2(8.0, 22.0), label,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 16, edge)
