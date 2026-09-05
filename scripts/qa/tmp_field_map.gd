extends SceneTree
## Experimental: measure silhouette radius of the liquid_collection shader for
## (a) a lone central field blob of world radius Rc, then (b) same plus inner
## granule texture, so we can pick Rc that makes silhouette == collection r.

var _start := 0
var _started_tasks := false
var _viewport: SubViewport
var _img: Image
var _glue := 120
var _center := Vector2(256, 256)


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--glue="):
			_glue = int(arg.trim_prefix("--glue="))
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(512, 512)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.02, 0.03, 1.0)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_viewport.add_child(bg)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_start = Time.get_ticks_msec()


func _process(_delta: float) -> bool:
	if _started_tasks:
		return false
	_started_tasks = true
	_measure_map()
	return false


func _luma(px: Color) -> float:
	return px.r * 0.4 + px.g * 0.4 + px.b * 0.2


func _make_material(color: Color) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/liquid_collection.gdshader")
	mat.set_shader_parameter("color", color)
	mat.set_shader_parameter("time", 0.0)
	mat.set_shader_parameter("surface", 1.2)
	mat.set_shader_parameter("edge", 0.10)
	mat.set_shader_parameter("flow_speed", 0.0)
	mat.set_shader_parameter("distortion", 0.0)
	mat.set_shader_parameter("velocity", Vector2.ZERO)
	return mat


func _build_quad(margin: float) -> Sprite2D:
	var spr := Sprite2D.new()
	spr.centered = true
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var tex := GradientTexture2D.new()
	tex.width = 128
	tex.height = 128
	tex.fill = GradientTexture2D.FILL_SQUARE
	var grad := Gradient.new()
	grad.colors = PackedColorArray([Color.WHITE, Color.WHITE])
	tex.gradient = grad
	spr.texture = tex
	spr.position = _center
	# quad world half-size = r * margin -> scale = 2*r*margin/128
	spr.scale = Vector2.ONE
	_viewport.add_child(spr)
	return spr


func _measure_map() -> void:
	var col := Color(0.98, 0.965, 0.953, 1.0)
	var results := ""
	# BlobSprite granule silhouette at radius 6 world
	for child in _viewport.get_children():
		if child is Node2D:
			child.queue_free()
	var granule := BlobSprite.new()
	granule.position = _center
	granule.base_radius = 6.0
	granule.set_tint(col)
	_viewport.add_child(granule)
	await _wait()
	results += "granule r=6 -> silhouette=%.1f\n" % _silhouette_r_mat(granule.get_node_or_null("LiquidSprite"))
	print(results)
	quit(0)


func _wait() -> void:
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < 400:
		await process_frame
	var img := _viewport.get_texture().get_image()
	if img != null:
		_img = img


func _silhouette_r(mat: ShaderMaterial) -> float:
	# measure along +x from sprite center using stored image
	var best := 0.0
	for i in range(1, 200):
		var w := _center + Vector2.RIGHT * float(i)
		var l := _luma(_img.get_pixel(int(w.x), int(w.y)))
		if l > 0.18:
			best = float(i)
	return best


func _silhouette_r_mat(node: Node) -> float:
	var spr := node as Sprite2D
	if spr == null:
		return -1.0
	var best := 0.0
	for i in range(1, 200):
		var w := _center + Vector2.RIGHT * float(i)
		var l := _luma(_img.get_pixel(int(w.x), int(w.y)))
		if l > 0.18:
			best = float(i)
	return best
