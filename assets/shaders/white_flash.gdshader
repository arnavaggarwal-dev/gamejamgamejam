shader_type canvas_item;

// Whites a sprite out (keeping its shape): 0 = normal, 1 = solid white. Children that set
// use_parent_material flash with it.
uniform float flash : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	COLOR = vec4(mix(c.rgb, vec3(1.0), flash), c.a);
}
