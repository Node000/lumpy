shader_type canvas_item;
// Liquid metaball surface. Drives a threshold of overlapping blob fields.
// Fragments sum gaussians from each blob; where the sum crosses the surface
// level the pixel is opaque white, near the surface it gets a soft translucent
// edge so blobs visually fuse into one puddle.
//
// Uniforms are driven per-frame by the BlobFieldVisualizer script:
//   u_count      - how many blobs are active (0..MAX_BLOBS)
//   u_pos        - blob centers in viewport pixels
//   u_radius     - shared blob radius in pixels
//   u_surface    - threshold of the summed field that reads as "surface"
//   u_edge       - band width around the threshold for the soft rim
//   u_tint       - liquid colour

const int MAX_BLOBS = 24;

uniform int u_count = 0;
uniform vec2 u_pos[MAX_BLOBS];
uniform float u_radius = 20.0;
uniform float u_surface = 0.5;
uniform float u_edge = 0.12;
uniform vec4 u_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);

float blob_field(vec2 p, vec2 c, float r) {
	vec2 d = p - c;
	float dist2 = dot(d, d);
	return r * r / (dist2 + r * r * 0.02);
}

void fragment() {
	vec2 px = SCREEN_UV / SCREEN_PIXEL_SIZE;
	float sum = 0.0;
	for (int i = 0; i < MAX_BLOBS; i++) {
		if (i >= u_count) {
			break;
		}
		sum += blob_field(px, u_pos[i], u_radius);
	}
	float core = smoothstep(u_surface, u_surface + u_edge, sum);
	float rim = smoothstep(u_surface - u_edge * 2.0, u_surface, sum) * (1.0 - core);
	vec3 col = u_tint.rgb * (core + rim * 0.55);
	float alpha = max(core, rim * 0.5);
	COLOR = vec4(col, alpha * u_tint.a);
}
