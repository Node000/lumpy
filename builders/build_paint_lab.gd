extends SceneBuilderBase
## Builds the paint-lab sample level: a small floor plus a few painted walls
## with placeholder textures (replace res://assets/walls/*.png with your own).
## This is the editable starting point for the editor-based wall workflow; the
## player_test level stays untouched.

const PAINT_WALL_SCRIPT := "res://scripts/gameplay/paint_wall.gd"

func _initialize() -> void:
	var root := Node2D.new()
	root.name = "PaintLab"

	var bg := Node2D.new()
	bg.name = "Backdrop"
	bg.set_script(load("res://scripts/gameplay/level_bg.gd"))
	root.add_child(bg)

	# Floor: wide painted wall, rough by default.
	var floor := _paint_wall("Floor", Vector2(160, 420), Vector2(1200, 32), false)
	floor.scale.y = 1.0
	root.add_child(floor)

	# Left and right boundary.
	root.add_child(_paint_wall("WallLeft", Vector2(24, 250), Vector2(48, 420), false))
	root.add_child(_paint_wall("WallRight", Vector2(296, 250), Vector2(48, 420), false))

	# A smooth shelf in the middle to test glue reflection.
	var shelf := _paint_wall("ShelfSmooth", Vector2(160, 250), Vector2(180, 24), true)
	root.add_child(shelf)

	# A rough block on the right side to test glue stopping.
	root.add_child(_paint_wall("BlockRough", Vector2(230, 360), Vector2(70, 90), false))

	# A resting glue pile spawned by the GlueSpot component, ready to suck.
	var spot := Node2D.new()
	spot.name = "GlueSpot"
	spot.position = Vector2(160, 392)
	spot.set_script(load("res://scripts/gameplay/glue_spot.gd"))
	spot.count = 4
	spot.spread = 12.0
	root.add_child(spot)

	var hud_layer := CanvasLayer.new()
	hud_layer.name = "HUD"
	hud_layer.layer = 10
	root.add_child(hud_layer)
	var hud := Control.new()
	hud.name = "HUDContent"
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud_layer.add_child(hud)
	var title := Label.new()
	title.name = "Title"
	title.position = Vector2(24, 24)
	title.text = "Paint Lab: drop your texture into assets/walls, replace it on any painted wall"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.75, 0.78, 0.88))
	hud.add_child(title)

	_pack_and_save(root, "res://scenes/levels/paint_lab.tscn")


func _paint_wall(node_name: String, pos: Vector2, size_px: Vector2, smooth: bool) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.name = node_name
	body.position = pos
	body.set_script(load(PAINT_WALL_SCRIPT))
	body.smooth = smooth
	body.size_px = size_px
	return body
