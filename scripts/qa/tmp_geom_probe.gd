extends SceneTree

## TEMP: print collection geometry at start and max glue.
## run: godot --headless --path . --script res://scripts/qa/tmp_geom_probe.gd

var _done := false


func _initialize() -> void:
	var level := (load("res://scenes/levels/player_test.tscn") as PackedScene).instantiate()
	root.add_child(level)
	await process_frame
	await process_frame
	var player: Node2D = level.get_node_or_null("Player")
	var blob: Node2D = player.get_node_or_null("VisualBlob")
	var sprite: CanvasItem = player.get_node_or_null("AnimatedSprite2D")
	var g = root.get_node_or_null("GameTuning")
	for glue in [g.start_glue, g.max_glue]:
		player.call("set_glue_count", glue)
		await process_frame
		await process_frame
		var layout: Dictionary = blob.get_particle_layout()
		var pos: PackedVector2Array = layout["positions"]
		var lowest := -1e9
		var highest := 1e9
		var leftmost := 1e9
		var rightmost := -1e9
		for i in pos.size():
			var p: Vector2 = pos[i]
			lowest = maxf(lowest, p.y)
			highest = minf(highest, p.y)
			leftmost = minf(leftmost, p.x)
			rightmost = maxf(rightmost, p.x)
		print("glue=", glue, " collection_radius_target=", blob.get("radius_target"))
		print("  blob.position.y=", blob.position.y, " (local) — collection center above player root")
		print("  particle lowest=", lowest, " highest=", highest, " leftmost=", leftmost, " rightmost=", rightmost)
		print("  particle bottom in player-local y = ", blob.position.y + lowest)
		print("  anchor bottom_y (GameTuning)=", g.player_collection_bottom_y)
		if sprite != null:
			print("  sprite.position.y=", sprite.position.y, " scale=", sprite.scale)
	player.call("set_glue_count", g.start_glue)
	level.queue_free()
	quit(0)
