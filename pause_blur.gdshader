shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float blur_radius = 3.0;
uniform float darkness : hint_range(0.0, 1.0) = 0.38;

void fragment() {
	vec2 step_uv = SCREEN_PIXEL_SIZE * blur_radius;
	vec3 color = textureLod(screen_texture, SCREEN_UV, 0.0).rgb * 0.20;
	color += textureLod(screen_texture, SCREEN_UV + vec2(step_uv.x, 0.0), 0.0).rgb * 0.12;
	color += textureLod(screen_texture, SCREEN_UV - vec2(step_uv.x, 0.0), 0.0).rgb * 0.12;
	color += textureLod(screen_texture, SCREEN_UV + vec2(0.0, step_uv.y), 0.0).rgb * 0.12;
	color += textureLod(screen_texture, SCREEN_UV - vec2(0.0, step_uv.y), 0.0).rgb * 0.12;
	color += textureLod(screen_texture, SCREEN_UV + step_uv, 0.0).rgb * 0.08;
	color += textureLod(screen_texture, SCREEN_UV - step_uv, 0.0).rgb * 0.08;
	color += textureLod(screen_texture, SCREEN_UV + vec2(step_uv.x, -step_uv.y), 0.0).rgb * 0.08;
	color += textureLod(screen_texture, SCREEN_UV + vec2(-step_uv.x, step_uv.y), 0.0).rgb * 0.08;
	COLOR = vec4(color * (1.0 - darkness), 1.0);
}
