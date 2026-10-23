shader_type canvas_item;

// Tutorial spotlight: greys out and dims everything drawn below it (lower z), so only the
// things lifted above it (the hero, the bomb, the core) stay in colour.
uniform sampler2D screen : hint_screen_texture, filter_nearest;
uniform vec4 shade : source_color = vec4(0.176, 0.153, 0.188, 1.0);
uniform float amount : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec3 c = texture(screen, SCREEN_UV).rgb;
	vec3 grey = mix(shade.rgb, vec3(dot(c, vec3(0.299, 0.587, 0.114))), 0.55);
	COLOR = vec4(mix(c, grey, amount), 1.0);
}
