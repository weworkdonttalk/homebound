shader_type canvas_item;

// A hand-pressed wax seal: irregular wobbly edge, dark rim, soft top-left
// highlight, inner stamped ring, and fine wax grain.

uniform vec4 wax_dark : source_color = vec4(0.36, 0.075, 0.075, 1.0);
uniform vec4 wax_mid : source_color = vec4(0.620, 0.169, 0.169, 1.0);
uniform vec4 wax_light : source_color = vec4(0.792, 0.318, 0.298, 1.0);
uniform vec2 rect_size = vec2(64.0, 64.0);

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
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
	vec2 p = (UV - 0.5) * 2.0;
	float ang = atan(p.y, p.x);
	float wobble = 1.0
		+ 0.045 * sin(ang * 5.0 + 0.8)
		+ 0.025 * sin(ang * 9.0 - 1.7)
		+ (vnoise(UV * 7.0) - 0.5) * 0.045;
	float r = length(p) / (0.86 * wobble);

	float alpha = 1.0 - smoothstep(0.965, 1.0, r);

	// Base wax body: mostly flat, only slightly darker toward the pressed rim.
	float radial = smoothstep(0.12, 1.0, r);
	vec3 col = mix(wax_mid.rgb, wax_dark.rgb, radial * 0.62);

	// Directional sheen from the upper-left.
	vec2 dir = normalize(p + vec2(0.0001));
	float lit = clamp(dot(dir, normalize(vec2(-0.58, -0.78))), 0.0, 1.0);
	col += wax_light.rgb * pow(lit, 3.0) * 0.24 * (1.0 - smoothstep(0.72, 1.0, r));

	// Small specular drop near the top-left.
	float spec = exp(-pow(length(p - vec2(-0.30, -0.34)) * 9.0, 2.0));
	col += vec3(1.0, 0.82, 0.76) * spec * 0.24;

	// Stamped inner ring.
	float ring = 1.0 - smoothstep(0.0, 0.032, abs(r - 0.64));
	col = mix(col, wax_light.rgb, ring * 0.46);

	// Fine wax grain.
	col += (vnoise(UV * rect_size * 0.45) - 0.5) * 0.075;

	// Dark, slightly glossy outer rim.
	float rim = smoothstep(0.84, 1.0, r);
	col = mix(col, wax_dark.rgb * 0.52, rim * 0.85);

	COLOR = vec4(col, alpha);
}
