extends Node
## All tunable gameplay attributes live here as one shared object so gameplay
## code can be tuned from a single file. Autoload singleton "GameTuning".
## Designer edits values here and retests without touching scene logic.

# Movement
var move_speed := 235.0
var accel := 3400.0
var friction := 3000.0

# Jump
var gravity := 1520.0
var gravity_hold_ratio := 0.34
var jump_velocity := -560.0
var jump_cut_velocity := -90.0
var jump_hold_time := 0.24
var jump_buffer_time := 0.12
var coyote_time := 0.10

# Glue / body size (counts are GLUE PARTICLES)
var glue_effect_cap := 20
var glue_jump_weight_max := 0.5  # at the cap the jump keeps only 50% height
var body_radius_base := 15
var player_collection_bottom_y := 9.0
var player_collection_radius_base := 15.0
var player_collection_radius_per_glue := 3
var player_collection_max_radius := 100
var max_glue := 30
var start_glue := 10

# Spit
var spit_interval := 0.12
var spit_speed := 540.0
var spit_spread_deg := 6.0  # full launch-angle spread for each ball

# Suck
var suck_cone_angle_deg := 30.0  # full cone angle; half = 15
var suck_range := 430.0
var suck_speed := 760.0
var max_suck_glue := 24
var suck_recast_time := 0.10
var show_suck_range := true

# GlueBall (single particle)
var glue_ball_radius := 12
var glue_ball_collision_radius := 10  # 30% smaller than the 6px visual radius
var glue_splat_spread := 6.0   # tangential scatter when splatting on a wall
var glue_splat_forward := 3.5  # push-out along the wall normal when splatting
var glue_fly_timeout := 6.0
var glue_outside_margin := 90.0
var glue_swell_delay := 0.2       # seconds resting before the elastic swell starts
var glue_swell_scale := 2.0       # visual + collision final size after swell (2x)
var glue_swell_anim_time := 0.5   # elastic swell animation duration
var player_body_color := Color(0.98, 0.965, 0.953, 1.0)
var collection_bubble_radius := 16
