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
var collection_layout_pack := 0.6  # particle-centre spacing multiplier (1.0 = spread, lower = tightly packed)

# Spit
var spit_interval := 0.12
var spit_speed := 540.0
var spit_spread_deg := 6.0  # full launch-angle spread for each ball

# Suck
var suck_cone_angle_deg := 30.0  # full cone angle; half = 15
var suck_range := 430.0
var suck_speed := 760.0
var max_suck_glue := 24
var show_suck_range := true

# GlueBall (single particle)
var glue_ball_radius := 12
var glue_ball_collision_radius := 10  # about 16.7% smaller than the 12px visual radius
var glue_splat_spread := 6.0   # tangential scatter when splatting on a wall
var glue_splat_forward := 3.5  # push-out along the wall normal when splatting
var glue_fly_timeout := 6.0
var glue_outside_margin := 90.0
var glue_swell_delay := 0.2       # seconds resting before the elastic swell starts
var glue_swell_scale := 2.0       # visual + collision final size after swell (2x)
var glue_swell_anim_time := 0.5   # elastic swell animation duration
var player_body_color := Color(0.98, 0.965, 0.953, 1.0)
var collection_bubble_radius := 16

# Audio balance (dBFS). Per-SFX gains were derived from runtime measurements
# (scripts/qa/measure_audio_loudness.gd) so that glueUP/jump/shoot land on the
# same loudness near sfx_target_loudness_db. bgm_gain_db pulls Digital
# Lemonade down from its raw -17.8 average to the old Circulation baseline so
# SFX still sit above the music bed. Listen and nudge these values freely.
var sfx_target_loudness_db := -22.5
var sfx_jump_gain_db := -1.4
var sfx_glue_up_gain_db := -1.0
var sfx_shoot_gain_db := 18.1
var bgm_gain_db := -5.2
var glue_up_pitch_min := 0.9    # glueUP pitch at 0% glue
var glue_up_pitch_max := 1.8    # glueUP pitch at 100% glue (x2 = one octave up)
