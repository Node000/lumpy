extends SceneTree

## Builds editable SpriteFrames from the single 20-frame character sheet.
## The sheet is a 20 x 1 strip, each frame is 124 x 124.

const SHEET_PATH := "res://assets/character/lumpy-sheet.png"
const OUTPUT_PATH := "res://assets/character/lumpy_animations.tres"
const FRAME_SIZE := Vector2i(124, 124)

var sheet_texture: Texture2D


func _initialize() -> void:
	var sheet := load(SHEET_PATH) as Texture2D
	if sheet == null:
		push_error("Missing character sheet: " + SHEET_PATH)
		quit(1)
		return
	sheet_texture = sheet
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	_add_animation(frames, "idle", [0], 5.0, true)
	_add_animation(frames, "move", range(0, 8), 12.0, true)
	_add_animation(frames, "jump", range(8, 13), 12.0, false)
	_add_animation(frames, "spit", range(13, 16), 12.0, false)
	_add_animation(frames, "suck", range(16, 20), 12.0, true)

	var err := ResourceSaver.save(frames, OUTPUT_PATH)
	if err != OK:
		push_error("Could not save SpriteFrames: %s" % err)
		quit(1)
		return
	print("BUILT: character SpriteFrames -> " + OUTPUT_PATH)
	quit(0)


func _add_animation(frames: SpriteFrames, animation_name: String, indexes: Array, speed: float, looped: bool) -> void:
	frames.add_animation(animation_name)
	frames.set_animation_speed(animation_name, speed)
	frames.set_animation_loop(animation_name, looped)
	for index in indexes:
		var atlas := AtlasTexture.new()
		atlas.atlas = sheet_texture
		atlas.region = Rect2(Vector2i(index * FRAME_SIZE.x, 0), FRAME_SIZE)
		frames.add_frame(animation_name, atlas)
