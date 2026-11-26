shader_type canvas_item;

// ============================================================================
// Dimension Shift Transition Shader — Little Nightmares Psychological Horror
// Menghasilkan distorsi lensa, chromatic aberration radial, dan kilatan cahaya redup
// setiap kali pemain berpindah antara dimensi Remembered dan Forgotten.
// ============================================================================

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform float shift_strength : hint_range(0.0, 1.0) = 0.0;
uniform float aberration_amount : hint_range(0.0, 0.1) = 0.028;
uniform float distortion_amount : hint_range(0.0, 0.1) = 0.032;
uniform vec4 flash_color : source_color = vec4(0.12, 0.32, 0.28, 0.35);

void fragment() {
	if (shift_strength <= 0.001) {
		// Transparan penuh tanpa memproses tekstur layar saat tidak aktif
		COLOR = vec4(0.0);
	} else {
		vec2 center = vec2(0.5, 0.5);
		vec2 diff = SCREEN_UV - center;
		float dist = length(diff);

		// Distorsi lensa melingkar (shockwave ripple) dari pusat layar
		float ripple = sin(dist * 20.0 - shift_strength * 5.0) * distortion_amount * shift_strength;
		vec2 distorted_uv = SCREEN_UV + normalize(diff + vec2(0.0001)) * ripple;
		distorted_uv = clamp(distorted_uv, vec2(0.001), vec2(0.999));

		// Chromatic Aberration radial (pemisahan channel merah & biru)
		vec2 red_offset = normalize(diff + vec2(0.0001)) * (aberration_amount * shift_strength * (dist + 0.25));
		vec2 blue_offset = -red_offset;

		float r = texture(screen_texture, clamp(distorted_uv + red_offset, vec2(0.001), vec2(0.999))).r;
		float g = texture(screen_texture, distorted_uv).g;
		float b = texture(screen_texture, clamp(distorted_uv + blue_offset, vec2(0.001), vec2(0.999))).b;

		vec3 base_color = vec3(r, g, b);

		// Kilatan cahaya redup (subtle eerie flash tint)
		vec3 tinted_color = mix(base_color, flash_color.rgb, flash_color.a * shift_strength);

		COLOR = vec4(tinted_color, shift_strength);
	}
}
