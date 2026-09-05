extends SceneTree
class_name SceneBuilderBase


func _set_owner_on_new_nodes(node: Node, scene_owner: Node) -> void:
	for child in node.get_children():
		child.owner = scene_owner
		if child.scene_file_path.is_empty():
			_set_owner_on_new_nodes(child, scene_owner)


func _count_nodes(node: Node) -> int:
	var total := 1
	for child in node.get_children():
		total += _count_nodes(child)
	return total


func _validate_packed_scene(packed: PackedScene, expected_count: int, scene_path: String) -> bool:
	var test_instance := packed.instantiate()
	var actual := _count_nodes(test_instance)
	test_instance.free()
	if actual < expected_count:
		push_error("Pack validation failed for %s: expected %d nodes, got %d" % [scene_path, expected_count, actual])
		return false
	return true


func _pack_and_save(root_node: Node, output_path: String) -> void:
	_set_owner_on_new_nodes(root_node, root_node)
	var count := _count_nodes(root_node)
	var packed := PackedScene.new()
	var err := packed.pack(root_node)
	if err != OK:
		push_error("Pack failed: %s" % err)
		quit(1)
		return
	if not _validate_packed_scene(packed, count, output_path):
		quit(1)
		return
	err = ResourceSaver.save(packed, output_path)
	if err != OK:
		push_error("Save failed: %s" % err)
		quit(1)
		return
	print("BUILT: %d nodes -> %s" % [count, output_path])
	quit(0)
