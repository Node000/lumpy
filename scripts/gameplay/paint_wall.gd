extends StaticBody2D
## Editor-placed painted wall. Drag a hand-drawn PNG into the scene (as a
## Sprite2D child or assigned to `texture`), toggle `smooth`, and the wall is
## playable: the rectangle collision is sized from the texture automatically
## and the collision layer picks up the glue reflection behaviour.
##
## Collision layers (bit values):
##   1 = wall_rough, 2 = wall_smooth, 4 = glue_rest, 8 = glue_fly, 16 = player
##
## A painted wall's appearance comes from its texture only; `smooth` does NOT
## tint it. It is pure physics: smooth walls reflect flying glue, rough walls
## stop it (see glue_ball.gd).

@export var texture: Texture2D = null
@export var smooth := false
@export var pixels_per_unit := 100.0
@export var size_px := Vector2(64, 64)  # fallback size when no texture is set

var _sprite: Sprite2D = null
var _collision: CollisionShape2D = null


func _ready() -> void:
	_setup_visual()
	_setup_collision()
	collision_layer = 2 if smooth else 1
	collision_mask = 1 | 2 | 4 | 8 | 16


func get_wall_size() -> Vector2:
	var px := size_px
	if texture != null:
		px = Vector2(texture.get_width(), texture.get_height())
	return px / pixels_per_unit


func _setup_visual() -> void:
	_sprite = get_node_or_null("Sprite") as Sprite2D
	if texture == null:
		return
	if _sprite == null:
		_sprite = Sprite2D.new()
		_sprite.name = "Sprite"
		add_child(_sprite)
	_sprite.texture = texture
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_sprite.centered = true


func _setup_collision() -> void:
	var shape := RectangleShape2D.new()
	shape.size = get_wall_size()
	_collision = get_node_or_null("Collision") as CollisionShape2D
	if _collision == null:
		_collision = CollisionShape2D.new()
		_collision.name = "Collision"
		add_child(_collision)
	_collision.shape = shape
