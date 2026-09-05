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
var glue_effect_cap := 90
var glue_jump_weight_max := 0.5  # at the cap the jump keeps only 50% height
var body_radius_base := 17.0
var body_radius_per_glue := 0.12
var body_collision_max_radius := 28.0
var body_collision_bottom_offset := 16.0  # local y of the collision circle bottom (feet)
var player_collection_bottom_y := 14.0
var player_collection_radius_base := 15.0
var player_collection_radius_per_glue := 0.24
var player_collection_max_radius := 46.0
var max_glue := 120
var start_glue := 30

# Spit
var spit_cooldown := 0.26
var spit_speed := 540.0
var glue_particles_per_unit := 10  # particles per single spit
var glue_spit_spread_deg := 12.0   # per-particle launch angle spread (full cone)
var glue_spit_pos_jitter := 6.0    # per-particle launch position jitter
var glue_spit_speed_variance := 0.1

# Suck
var suck_cone_angle_deg := 30.0  # full cone angle; half = 15
var suck_range := 430.0
var suck_speed := 760.0
var max_suck_glue := 24
var suck_recast_time := 0.10

# GlueBall (single particle)
var glue_ball_radius := 6.0
var glue_ball_collision_radius := 6.0  # same as visual radius
var glue_splat_spread := 6.0   # tangential scatter when splatting on a wall
var glue_splat_forward := 3.5  # push-out along the wall normal when splatting
var glue_swell_delay := 2.0
var glue_swell_scale := 3.0      # visual scale after swell (must equal collision factor)
var glue_swell_anim_time := 0.5
var glue_swell_collision_factor := 3.0  # final collision size after swell (must equal visual)
var glue_fly_timeout := 6.0
var glue_outside_margin := 90.0

# Liquid visual
var glue_visual_wobble := 0.07
var glue_visual_speed := 3.2
var glue_visual_flow_speed := 1.35
var glue_visual_distortion := 0.075
var glue_visual_edge_softness := 0.055
var glue_visual_stretch := 0.0009
var player_body_color := Color(0.98, 0.965, 0.953, 1.0)
var collection_bubble_core_radius := 6.0
var collection_bubble_radius := 6.0
var collection_bubble_spread := 24.0
var collection_bubble_surface := 1.2
