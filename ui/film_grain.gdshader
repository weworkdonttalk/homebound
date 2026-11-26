shader_type canvas_item;

// Very light 24fps film grain over the whole screen. Keeps the flat 3D render
// feeling like printed, moving film without hurting UI legibility.

uniform float amount : hint_range(0.0, 0.12) = 0.028;
uniform float steps_per_second = 24.0;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void fragment() {
	float t = floor(TIME * steps_per_second);
	vec2 p = floor(FRAGCOORD.xy) + vec2(t * 17.0, t * 9.0);
	float n = hash21(p);
	float a = abs(n - 0.5) * amount;
	vec3 tone = n > 0.5 ? vec3(1.0) : vec3(0.0);
	COLOR = vec4(tone, a);
}
