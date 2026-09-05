extends SceneBuilderBase

## Builds the reusable pooled glue ball scene.

func _initialize() -> void:
	var root := CharacterBody2D.new()
	root.name = "GlueBall"

	var visual := Node2D.new()
	visual.name = "Visual"
	root.add_child(visual)

	var blob := BlobSprite.new()
	blob.name = "GlueBody"
	blob.base_radius = 8.5
	visual.add_child(blob)

	var collision := CollisionShape2D.new()
	collision.name = "Collision"
	var shape := CircleShape2D.new()
	shape.radius = 8.5
	collision.shape = shape
	root.add_child(collision)

	root.set_script(load("res://scripts/gameplay/glue_ball.gd"))
	_pack_and_save(root, "res://scenes/gameplay/glue_ball.tscn")
