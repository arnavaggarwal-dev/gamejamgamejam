shader_type canvas_item;

// Rubber-hose "line boil": UVs wobble in steps of `fps`, so still drawings look hand-animated.
uniform float fps = 12.0;
uniform float strength = 1.5; // wobble size in texture pixels
uniform float noise_scale = 0.05;

varying vec4 vertex_color;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void vertex() {
	vertex_color = COLOR;
}

void fragment() {
	float t = floor(TIME * fps);
	vec2 px = UV / TEXTURE_PIXEL_SIZE;
	vec2 wobble = vec2(noise(px * noise_scale + t * 7.13), noise(px * noise_scale + t * 3.71 + 17.0)) - 0.5;
	COLOR = texture(TEXTURE, UV + wobble * 2.0 * strength * TEXTURE_PIXEL_SIZE) * vertex_color;
}
