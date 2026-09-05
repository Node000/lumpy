shader_type canvas_item;

// Local metaball field. All source positions are in this node's pixel space.
const int MAX_BLOBS = 64;

uniform int blob_count = 0;
uniform vec2 blob_positions[MAX_BLOBS];
uniform float blob_radii[MAX_BLOBS];
uniform float surface = 1.2;
uniform float edge = 0.10;
uniform float time : hint_range(0.0, 60.0) = 0.0;
uniform float flow_speed : hint_range(0.0, 5.0) = 1.35;
uniform float distortion : hint_range(0.0, 0.25) = 0.075;
uniform vec2 velocity = vec2(0.0);
uniform vec4 color : source_color = vec4(1.0);

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x),
		mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec2 pixel = UV / TEXTURE_PIXEL_SIZE;
	float field = 0.0;
	float speed = length(velocity) * 0.001;
	vec2 flow = vec2(time * flow_speed, -time * flow_speed * 0.63);
	float local_noise = (noise(pixel * 0.045 + flow) - 0.5) * distortion;
	float directional = dot(normalize(velocity + vec2(0.0001)), UV - vec2(0.5)) * speed;
	for (int i = 0; i < MAX_BLOBS; i++) {
		if (i >= blob_count) {
			break;
		}
		vec2 delta = pixel - blob_positions[i];
		float radius = blob_radii[i];
		float radius_sq = radius * radius;
		field += radius_sq / (dot(delta, delta) + radius_sq * 0.08);
	}
	float threshold = surface + local_noise + directional;
	float core = smoothstep(threshold - edge, threshold + edge, field);
	float rim = smoothstep(threshold - edge * 2.4, threshold, field) * (1.0 - core);
	float highlight = smoothstep(0.55, 0.05, length(UV - vec2(0.36, 0.32))) * 0.16;
	vec3 liquid = color.rgb * (0.72 + core * 0.28 + rim * 0.16 + highlight);
	float alpha = max(core, rim * 0.62);
	COLOR = vec4(liquid, alpha * color.a);
}
