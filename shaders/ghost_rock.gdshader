shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, unshaded;

// ============================================================================
// Spectral Ghost Rock Shader — Little Nightmares / Limbo Shifting Preview
// Renders inactive dimension rocks as an eerie translucent mist silhouette
// with a glowing Fresnel rim so players can read jump targets through fog.
// ============================================================================

uniform vec4 ghost_color : source_color = vec4(0.35, 0.78, 1.0, 1.0);
uniform float core_alpha : hint_range(0.0, 0.5) = 0.04;
uniform float rim_alpha : hint_range(0.0, 1.0) = 0.46;
uniform float fresnel_power : hint_range(0.5, 6.0) = 2.4;

void fragment() {
	float ndv = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float fresnel = pow(1.0 - ndv, fresnel_power);
	float pulse = 0.92 + 0.08 * sin(TIME * 2.6);
	float alpha = mix(core_alpha, rim_alpha, fresnel) * pulse;
	ALBEDO = ghost_color.rgb * (0.7 + 0.6 * fresnel);
	ALPHA = clamp(alpha, 0.0, 0.75);
}
