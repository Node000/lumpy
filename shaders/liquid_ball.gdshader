shader_type canvas_item;
// Simple liquid-edge placeholder for a single ball: a white circle whose rim
// wobbles softly, with a brighter core so carried blobs read as gooey lumps.

uniform float time : hint_range(0.0, 60.0) = 0.0;
uniform float wobble : hint_range(0.0, 0.2) = 0.05;
uniform vec4 color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV - vec2(0.5);
	float d = length(uv);
	float a = atan(uv.y, uv.x);
	float wob = 1.0 + wobble * (sin(a * 5.0 + time * 3.0) + 0.5 * sin(a * 11.0 - time * 2.2));
	float rim = 0.48 * wob;
	float alpha = smoothstep(rim + 0.06, rim, d);
	float soft = smoothstep(rim + 0.16, rim, d) - alpha;
	vec3 col = mix(color.rgb * 0.6, color.rgb, alpha + soft * 0.25);
	COLOR = vec4(col, alpha * color.a);
}
