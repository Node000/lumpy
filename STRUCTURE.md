# lumpy

## Dimension: 2D

Prototype platformer and puzzle interaction loop. Player and glue balls are
`CharacterBody2D`; test walls are `StaticBody2D`; UI is on a `CanvasLayer`.

## Input Actions

| Action | Keys / Button |
|---|---|
| move_left | A |
| move_right | D |
| jump | Space |
| spit_glue | Mouse left |
| suck_glue | Mouse right |
| restart_level | R |

## Scenes

### GlueBall
- File: `res://scenes/gameplay/glue_ball.tscn`
- Root: `CharacterBody2D`
- Children: `Visual/GlueBody`, `Collision`

### Player Test
- File: `res://scenes/levels/player_test.tscn`
- Root: `Node2D`
- Children: player, rough/smooth test walls, pooled glue balls at runtime, HUD

### Shader Test
- File: `res://scenes/levels/shader_test.tscn`
- Root: `Node2D`
- Children: metaball field, single liquid-ball demo, shader control panel

## Scripts

- `res://scripts/gameplay/player.gd`: movement, variable jump, coyote/buffer,
  spit/suck, body size and jump-height mapping.
- `res://scripts/gameplay/glue_ball.gd`: FLY/STUCK/SUCK state machine, smooth
  wall reflection, rough collision stop, swell animation and collection.
- `res://scripts/core/gameplay_tuning.gd`: single tuning autoload.
- `res://scripts/core/gameplay_events.gd`: cross-scene glue count signal.
- `res://scripts/core/glue_pool.gd`: pooled glue ball instances.
- `res://scripts/gameplay/test_wall.gd`: per-object smooth-wall property.
- `res://scripts/shaders/metaball_field.gd`: metaball shader demo controller.
- `res://scripts/shaders/liquid_demo.gd`: single liquid shader demo controller.

## Collision Layers

Layer 1 is rough wall, layer 2 is smooth wall, layer 3 is resting glue, layer
4 is flying glue, and layer 5 is player. The values used in code are bitmasks:
`1`, `2`, `4`, `8`, and `16`.

## Build Order

1. `godot --headless --import`
2. `builders/build_glue_ball.gd` -> `scenes/gameplay/glue_ball.tscn`
3. `builders/build_player_test.gd` -> `scenes/levels/player_test.tscn`
4. `builders/build_shader_test.gd` -> `scenes/levels/shader_test.tscn`

## QA

- `tests/test_player_glue.gd` validates scene/resource loading, player setup,
  glue pool instances, and shader resources.
- Windowed capture helper: `scripts/qa/visual_capture.gd` with user args
  `--scene=res://... --output=...`.

## Asset Hints

- Player core sprite or vector illustration, centered on a 64 px square.
- Glue ball sprite or vector illustration, centered on a 40 px square.
- Rough wall tile/texture for test replacement.
- Smooth wall tile/texture for test replacement.
