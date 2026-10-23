shader_type canvas_item;

// Old-cartoon film look over the whole screen: fade, warm tint, grain, flicker, vignette.
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float fade = 0.15;
uniform vec3 tint = vec3(1.0, 0.94, 0.82);
uniform float grain = 0.07;
uniform float flicker = 0.04;
uniform float vignette = 0.9;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	float t = floor(TIME * 24.0);
	float luma = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(c, vec3(luma) * tint, fade);
	c += (hash(SCREEN_UV * 731.0 + t) - 0.5) * grain;
	c *= 1.0 - flicker * hash(vec2(t, 0.37));
	vec2 d = SCREEN_UV - 0.5;
	c *= 1.0 - dot(d, d) * vignette;
	COLOR = vec4(c, 1.0);
}
