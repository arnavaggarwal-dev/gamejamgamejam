shader_type canvas_item;
// The hero splattered on the screen: liquid goo. Each blob (x, y, radius in px of the 1280x720
// screen; w the moment it lands) splashes in with a little overshoot, merges with its neighbours
// like liquid (a metaball field), and runs down in a thinning drip; after a moment the whole splat
// slides down the glass and fades. Drawn in 4 px blocks, ink edge, teal rim, mint body, a cream
// glint on each blob, to match the pixel art. HUD.splat() scatters the blobs; GooFx runs t.

const int MAX_BLOBS = 64;
uniform vec4 blobs[64];
uniform int count = 0;
uniform float t = 0.0;  // seconds since the splat
uniform vec2 size = vec2(1280.0, 720.0);
uniform float block = 4.0;
uniform vec4 ink : source_color = vec4(0.176, 0.153, 0.188, 1.0);
uniform vec4 rim : source_color = vec4(0.0, 0.612, 0.537, 1.0);
uniform vec4 body : source_color = vec4(0.588, 0.859, 0.569, 1.0);
uniform vec4 shine : source_color = vec4(0.988, 0.984, 0.988, 1.0);

void fragment() {
	vec2 p = (floor(UV * size / block) + 0.5) * block;
	float slide = max(t - 0.9, 0.0);
	p.y -= slide * slide * 120.0;
	float field = 0.0;
	float gloss = 0.0;
	for (int i = 0; i < MAX_BLOBS; i++) {
		if (i >= count) {
			break;
		}
		vec4 b = blobs[i];
		float age = t - b.w;
		if (age <= 0.0) {
			continue;
		}
		float r = b.z * min(age / 0.06, 1.0) * (1.0 + 0.3 * max(0.0, 1.0 - age / 0.14));
		vec2 d = p - b.xy;
		field += r * r / (dot(d, d) + 1.0);
		float run = clamp((age - 0.2) * b.z * 1.4, 0.0, b.z * 3.0);  // the drip lengthens
		if (run > 0.0) {
			float y = clamp(d.y, 0.0, run);
			vec2 q = vec2(d.x, d.y - y);
			float rd = b.z * 0.3 * (1.0 - 0.6 * y / (b.z * 3.0));
			field += rd * rd / (dot(q, q) + 1.0);
		}
		if (b.z > 40.0) {  // a glint on each big gob only (lumps and spray merge in plain)
			gloss = max(gloss, 1.0 - length(d + vec2(0.35, 0.4) * r) / (r * 0.2 + 0.001));
		}
	}
	vec4 c = vec4(0.0);
	if (field > 1.0) {
		c = ink;
	}
	if (field > 1.12) {
		c = gloss > 0.0 ? shine : rim;
	}
	if (field > 1.6 && gloss <= 0.0) {
		c = body;
	}
	float fade = clamp((2.6 - t) / 0.6, 0.0, 1.0);
	COLOR = vec4(c.rgb, c.a * fade);
}
