extends SceneBuilderBase
## Builds the shader-test level: a dark backdrop, a metaball liquid surface
## demo in the centre and a single liquid-ball demo, both driven by a floating
## parameter panel (H toggles it).

func _initialize() -> void:
	var root := Node2D.new()
	root.name = "ShaderTest"

	var bg := ColorRect.new()
	bg.name = "Backdrop"
	bg.color = Color(0.05, 0.05, 0.09, 1.0)
	bg.size = Vector2(1280, 720)
	root.add_child(bg)
	var title := Label.new()
	title.name = "Title"
	title.position = Vector2(370, 32)
	title.text = "LIQUID LAB  /  METABALL + SINGLE BALL"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.72, 0.86, 0.92))
	root.add_child(title)
	# keep bg behind the canvas; anchors are irrelevant for Node2D children but
	# harmless here since ColorRect needs a Control parent to size with.

	# ---- Metaball demo ----
	var meta := ColorRect.new()
	meta.name = "MetaballDemo"
	meta.size = Vector2(1280, 720)
	var meta_mat := ShaderMaterial.new()
	meta_mat.shader = load("res://shaders/metaball_blob.gdshader")
	meta.material = meta_mat
	meta.set_script(load("res://scripts/shaders/metaball_field.gd"))
	root.add_child(meta)

	# MetaballField replaces the material in _ready(), so we pre-create the
	# ShaderMaterial here only to avoid a null shader until then.
	meta.set_script(load("res://scripts/shaders/metaball_field.gd"))

	# ---- Liquid single blob ----
	var liquid := Node2D.new()
	liquid.name = "LiquidDemo"
	liquid.position = Vector2(300, 300)
	liquid.set_script(load("res://scripts/shaders/liquid_demo.gd"))
	root.add_child(liquid)

	var spr := Sprite2D.new()
	spr.name = "LiquidSprite"
	spr.position = Vector2.ZERO
	var tex := GradientTexture2D.new()
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	var grad := Gradient.new()
	grad.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	grad.offsets = PackedFloat32Array([0.0, 0.72, 1.0])
	tex.gradient = grad
	tex.width = 128
	tex.height = 128
	spr.texture = tex
	spr.centered = true
	var spr_mat := ShaderMaterial.new()
	spr_mat.shader = load("res://shaders/liquid_ball.gdshader")
	spr.material = spr_mat
	spr.scale = Vector2.ONE
	liquid.add_child(spr)

	# ---- Panel ----
	var hud := CanvasLayer.new()
	hud.name = "HUD"
	hud.layer = 10
	root.add_child(hud)

	var panel := Control.new()
	panel.name = "Panel"
	panel.position = Vector2(24, 24)
	panel.size = Vector2(310, 240)
	hud.add_child(panel)
	var panel_script := load("res://scripts/shaders/shader_test_panel.gd")
	panel.set_script(panel_script)
	# Re-fetching via the parent is unnecessary for GDScript, but calling the
	# method after the script is attached lets the builder retain a valid node.
	panel.call("add_controller", meta)
	panel.call("add_controller", liquid)

	_pack_and_save(root, "res://scenes/levels/shader_test.tscn")
