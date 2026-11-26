shader_type canvas_item;

// ============================================================================
// Horror Post-Process Overlay — 24fps Analog Film Grain & Forgotten Cold Wash
// Pure alpha-blended overlay (no screen_texture read) so it never darkens or
// conflicts with other CanvasLayer post-process passes.
// ============================================================================

uniform float grain_amount : hint_range(0.0, 0.15) = 0.045;
uniform float mood_forgotten : hint_range(0.0, 1.0) = 0.0;
uniform float steps_per_second : hint_range(1.0, 60.0) = 24.0;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void fragment() {
	vec2 diff = SCREEN_UV - vec2(0.5);
	float dist = length(diff);
	float edge_mask = smoothstep(0.24, 0.85, dist);

	float t = floor(TIME * steps_per_second);
	vec2 gp = floor(FRAGCOORD.xy) + vec2(t * 17.0, t * 11.0);
	float n = hash21(gp);

	// 24fps film grain (lightly stronger in Forgotten mode)
	float grain_alpha = abs(n - 0.5) * grain_amount * (1.0 + mood_forgotten * 0.45);
	vec3 grain_tone = n > 0.5 ? vec3(0.92, 0.94, 0.96) : vec3(0.02, 0.025, 0.035);

	// Subtle cold atmospheric edge haze when shifted into Forgotten void
	vec3 fog_wash = vec3(0.08, 0.14, 0.24);
	float wash_alpha = mood_forgotten * 0.14 * edge_mask;

	float out_alpha = clamp(grain_alpha + wash_alpha, 0.0, 0.35);
	vec3 out_rgb = mix(grain_tone, fog_wash, wash_alpha / max(out_alpha, 0.0001));
	COLOR = vec4(out_rgb, out_alpha);
}
