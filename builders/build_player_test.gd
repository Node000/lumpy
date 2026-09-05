extends SceneBuilderBase
## Builds the player-test level scene from code and saves it to
## res://scenes/levels/player_test.tscn

func _initialize() -> void:
	var root := Node2D.new()
	root.name = "PlayerTest"

	var bg := Node2D.new()
	bg.name = "Backdrop"
	bg.set_script(load("res://scripts/gameplay/level_bg.gd"))
	root.add_child(bg)

	var player := CharacterBody2D.new()
	player.name = "Player"
	player.position = Vector2(180, 400)

	var col := CollisionShape2D.new()
	col.name = "Collision"
	var circle := CircleShape2D.new()
	circle.radius = 18.0
	col.shape = circle
	player.add_child(col)

	var visual := BlobBackdrop.new()
	visual.name = "VisualBlob"
	visual.set_bottom_anchor(14.0)
	player.add_child(visual)

	var animated := AnimatedSprite2D.new()
	animated.name = "AnimatedSprite2D"
	animated.sprite_frames = load("res://assets/character/lumpy_animations.tres")
	animated.animation = "idle"
	animated.centered = true
	animated.position = Vector2(0, -15)
	animated.scale = Vector2(0.72, 0.72)
	animated.z_index = 2
	player.add_child(animated)

	var cam := Camera2D.new()
	cam.name = "Camera2D"
	player.add_child(cam)

	player.set_script(load("res://scripts/gameplay/player.gd"))
	root.add_child(player)

	# Walls
	var wall := _wall(Vector2(40, 520), Vector2(320, 24), false)
	root.add_child(wall)
	var w2 := _wall(Vector2(430, 540), Vector2(720, 40), false)
	root.add_child(w2)
	var w3 := _wall(Vector2(120, 250), Vector2(24, 300), false)   # left boundary
	root.add_child(w3)
	var w4 := _wall(Vector2(890, 330), Vector2(24, 420), false)   # right boundary
	root.add_child(w4)
	var plat := _wall(Vector2(640, 390), Vector2(180, 16), false)
	root.add_child(plat)
	var smooth_wall := _wall(Vector2(680, 150), Vector2(150, 16), true)
	root.add_child(smooth_wall)
	var vertical := _wall(Vector2(330, 330), Vector2(16, 90), true)
	root.add_child(vertical)

	var level_script := Node2D.new()
	level_script.name = "LevelLogic"
	level_script.set_script(load("res://scripts/gameplay/player_test_level.gd"))
	root.add_child(level_script)
	level_script.call("set_player", player)

	var hud_layer := CanvasLayer.new()
	hud_layer.name = "HUD"
	hud_layer.layer = 10
	var hud := Control.new()
	hud.name = "HUDContent"
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud_layer.add_child(hud)
	var glue_label := Label.new()
	glue_label.name = "GlueLabel"
	glue_label.position = Vector2(24, 24)
	glue_label.text = "glue: --/--"
	glue_label.add_theme_font_size_override("font_size", 24)
	hud.add_child(glue_label)
	var controls := Label.new()
	controls.name = "Controls"
	controls.position = Vector2(24, 58)
	controls.text = "A/D move   Space jump   LMB spit   RMB suck   R restart"
	controls.add_theme_color_override("font_color", Color(0.75, 0.78, 0.88))
	hud.add_child(controls)
	hud.set_script(load("res://scripts/gameplay/level_hud.gd"))
	# The HUD logic script is attached to the full-rect Control, not the
	# CanvasLayer, so it can find GlueLabel without breaking native inheritance.
	root.add_child(hud_layer)

	_pack_and_save(root, "res://scenes/levels/player_test.tscn")


func _wall(pos: Vector2, size: Vector2, smooth: bool) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.name = "WallSmooth" if smooth else "Wall"
	body.position = pos
	var s := RectangleShape2D.new()
	s.size = size
	var cs := CollisionShape2D.new()
	cs.name = "Shape"
	cs.shape = s
	body.add_child(cs)
	var script := load("res://scripts/gameplay/test_wall.gd")
	body.set_script(script)
	body.smooth = smooth
	body.collision_layer = 2 if smooth else 1
	return body
