shader_type canvas_item;

// Local liquid surface for one blob. Evaluated in the sprite's UV space so it
// can be reused by pooled world balls. The surface wobbles and flows, but
// never exceeds the texture bounds: stretch is applied as elliptical
// compression along the velocity axis, and the radius is clamped.

uniform float time : hint_range(0.0, 60.0) = 0.0;
uniform float flow_speed : hint_range(0.0, 5.0) = 1.35;
uniform float distortion : hint_range(0.0, 0.25) = 0.075;
uniform float edge_softness : hint_range(0.005, 0.2) = 0.055;
uniform float wobble : hint_range(0.0, 0.25) = 0.07;
uniform vec2 velocity = vec2(0.0);
uniform vec4 color : source_color = vec4(1.0);

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	vec2 centered = UV - vec2(0.5);
	vec2 flow = vec2(time * flow_speed, -time * flow_speed * 0.63);
	float n0 = noise(centered * 6.0 + flow);
	float n1 = noise(centered * 13.0 - flow * 1.4);
	float surface_noise = (n0 - 0.5) * 0.7 + (n1 - 0.5) * 0.3;
	float angle = atan(centered.y, centered.x);
	float radial_wave = sin(angle * 5.0 + time * flow_speed * 2.4);
	float radial_wave2 = sin(angle * 9.0 - time * flow_speed * 1.7 + centered.y * 8.0);
	float radius = 0.47 + surface_noise * distortion * 0.55 + radial_wave * wobble * 0.035;
	radius += radial_wave2 * distortion * 0.018;
	radius = clamp(radius, 0.08, 0.49);
	float distance_to_surface = radius - length(centered);
	float alpha = smoothstep(-edge_softness, edge_softness, distance_to_surface);
	vec3 liquid = color.rgb * (0.72 + alpha * 0.28);
	COLOR = vec4(liquid, alpha * color.a);
}
