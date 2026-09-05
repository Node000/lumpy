extends Node
## Cross-scene gameplay events. Autoload singleton "GameplayEvents".

signal player_glue_changed(count: int, max_count: int)


func emit_glue_changed(count: int, max_count: int) -> void:
	player_glue_changed.emit(count, max_count)
