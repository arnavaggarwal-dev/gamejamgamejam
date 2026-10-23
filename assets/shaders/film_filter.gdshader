shader_type canvas_item;

// Soft ink vignette over the whole screen. It only darkens the corners, so the pixel art stays crisp.
uniform vec4 tint : source_color = vec4(0.176, 0.153, 0.188, 1.0);
uniform float strength = 0.35;

void fragment() {
	vec2 d = UV - 0.5;
	COLOR = vec4(tint.rgb, smoothstep(0.12, 0.5, dot(d, d)) * strength);
}
