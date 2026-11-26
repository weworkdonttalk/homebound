shader_type canvas_item;

// ============================================================================
// Circular Vignette Shader — Limbo / Little Nightmares Style
// Menggunakan smoothstep untuk pinggiran pudar lembut di sudut layar.
// Terkoneksi dengan koordinat center_offset (unproject_position) Player.
// aspect_correction mengontrol bentuk lingkaran (1.0 = bulat sempurna).
// ============================================================================

uniform vec2 center_offset = vec2(0.5, 0.5);
uniform float inner_radius : hint_range(0.0, 1.0) = 0.32;
uniform float outer_radius : hint_range(0.0, 2.0) = 0.75;
uniform vec4 vignette_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float vignette_opacity : hint_range(0.0, 1.0) = 0.92;
uniform float aspect_correction : hint_range(0.0, 1.0) = 0.7;

void fragment() {
	// Koreksi rasio aspek agar lingkaran vignette berbentuk simetris
	float aspect_ratio = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec2 aspect = vec2(mix(1.0, aspect_ratio, aspect_correction), 1.0);
	vec2 diff = (SCREEN_UV - center_offset) * aspect;
	float dist = length(diff);

	// Pinggiran pudar lembut menggunakan fungsi smoothstep
	float vignette = smoothstep(inner_radius, outer_radius, dist);
	COLOR = vec4(vignette_color.rgb, vignette * vignette_opacity);
}
