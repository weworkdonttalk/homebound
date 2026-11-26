shader_type canvas_item;

// Full-screen cinematic scrim: darkens the right side for the parchment panel,
// lifts a warm halo behind the falling character, and adds a soft vignette.

uniform vec4 ink : source_color = vec4(0.035, 0.043, 0.062, 1.0);
uniform vec4 warm_glow : source_color = vec4(0.42, 0.30, 0.16, 1.0);
uniform vec2 glow_center = vec2(0.30, 0.42);
uniform float right_strength = 0.72;
uniform float vignette_strength = 0.52;

void fragment() {
	vec2 uv = UV;

	float right = smoothstep(0.34, 0.84, uv.x);
	right = right * right * (3.0 - 2.0 * right);
	float alpha = right * right_strength;

	vec2 c = uv * 2.0 - 1.0;
	float vig = smoothstep(0.42, 1.22, length(c * vec2(0.88, 1.0)));
	alpha = max(alpha, vig * vignette_strength);

	float glow = exp(-pow(length((uv - glow_center) * vec2(1.25, 1.55)), 2.0) * 4.2);
	vec3 col = mix(ink.rgb, warm_glow.rgb, glow * 0.55);

	// Slight cool tint at the very top keeps the storm mood.
	col = mix(col, vec3(0.075, 0.095, 0.135), smoothstep(0.65, 0.0, uv.y) * 0.22);

	COLOR = vec4(col, alpha);
}
