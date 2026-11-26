shader_type canvas_item;

// Parchment surface for the menu panel.
// Gradient + paper grain + soft inner shadow + inset gold hairline.
// The drop shadow itself is provided by the panel's StyleBoxFlat.

uniform vec4 paper_light : source_color = vec4(0.953, 0.914, 0.827, 1.0);
uniform vec4 paper_dark : source_color = vec4(0.847, 0.780, 0.655, 1.0);
uniform vec4 gold_tint : source_color = vec4(0.839, 0.682, 0.404, 1.0);
uniform vec4 edge_tint : source_color = vec4(0.30, 0.24, 0.17, 1.0);
uniform vec2 rect_size = vec2(420.0, 720.0);
uniform float border_inset = 11.0;
uniform float border_alpha = 0.55;
uniform float grain_strength = 0.038;

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
	vec2 px = UV * rect_size;

	// Vertical paper gradient, warm at the top, older toward the bottom.
	vec3 col = mix(paper_light.rgb, paper_dark.rgb, smoothstep(0.0, 1.0, UV.y));

	// Soft light falling from the top-left corner.
	float warm = exp(-distance(UV * vec2(1.0, 0.72), vec2(0.10, -0.05)) * 2.6);
	col = mix(col, paper_light.rgb * 1.02, warm * 0.45);

	// Fibrous grain: two octaves of value noise plus faint horizontal fibers.
	float grain = vnoise(px * 0.55) * 0.6 + vnoise(px * 1.85) * 0.4;
	col += (grain - 0.5) * grain_strength;
	float fiber = vnoise(vec2(px.x * 0.03, px.y * 0.55));
	col += (fiber - 0.5) * 0.008;

	// Aged inner shadow around the edges.
	float edge_dist = min(min(px.x, rect_size.x - px.x), min(px.y, rect_size.y - px.y));
	float inner = 1.0 - smoothstep(0.0, 30.0, edge_dist);
	col = mix(col, col * 0.84, inner * 0.55);

	// Slightly darkened outer hairline.
	float rim = 1.0 - smoothstep(0.5, 1.6, edge_dist);
	col = mix(col, edge_tint.rgb, rim * 0.30);

	// Inset gold hairline, drawn as a signed distance to an inset rectangle.
	vec2 half_size = rect_size * 0.5;
	vec2 q = abs(px - half_size) - (half_size - vec2(border_inset));
	float sd = max(q.x, q.y);
	float gold_line = 1.0 - smoothstep(0.55, 1.35, abs(sd));
	float gold_fade = gold_line * border_alpha;
	// A hairline reads better when it is a touch brighter in the light.
	gold_fade *= 0.75 + warm * 0.25;
	col = mix(col, gold_tint.rgb, gold_fade);

	COLOR = vec4(col, 1.0);
}
