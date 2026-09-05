extends Control
## Test-level HUD: carried glue count, controls reminder, auto-run toggle.
## Connects to GameplayEvents.player_glue_changed to stay in sync across the
## pool of glued balls.

@onready var _glue_label: Label = find_child("GlueLabel", true, false)


func _ready() -> void:
	GameplayEvents.player_glue_changed.connect(_on_glue_changed)
	_on_glue_changed(GameTuning.start_glue, GameTuning.max_glue)


func _on_glue_changed(count: int, max_count: int) -> void:
	if _glue_label != null:
		_glue_label.text = "glue: %d/%d" % [count, max_count]
