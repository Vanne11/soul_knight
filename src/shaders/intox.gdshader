shader_type canvas_item;
render_mode unshaded;

// Mareo por intoxicacion: ondulacion leve, aberracion cromatica y desenfoque suave.
uniform sampler2D screen_tex : hint_screen_texture, filter_linear, repeat_disable;
uniform float amount : hint_range(0.0, 1.0) = 0.0;
uniform float wave : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	float t = TIME;
	float a = amount;
	vec2 w = vec2(
		sin(uv.y * 9.0 + t * 1.3) + 0.5 * sin(uv.y * 21.0 - t * 0.9),
		cos(uv.x * 7.0 + t * 1.1)) * 0.0035 * a * wave;
	vec2 base = uv + w;
	vec2 dir = uv - 0.5;
	float ca = (0.0008 + 0.0042 * a) * (0.6 + 0.4 * sin(t * 0.8));
	vec3 c;
	c.r = texture(screen_tex, base + dir * ca * 2.0).r;
	c.g = texture(screen_tex, base).g;
	c.b = texture(screen_tex, base - dir * ca * 2.0).b;
	float bl = 0.0012 * smoothstep(0.35, 1.0, a) * (0.7 + 0.3 * sin(t * 0.6));
	if (bl > 0.0) {
		vec3 s = texture(screen_tex, base + vec2(bl, 0.0)).rgb
			+ texture(screen_tex, base - vec2(bl, 0.0)).rgb
			+ texture(screen_tex, base + vec2(0.0, bl)).rgb
			+ texture(screen_tex, base - vec2(0.0, bl)).rgb;
		c = mix(c, (c + s * 0.25) * 0.5, 0.8);
	}
	COLOR = vec4(c, 1.0);
}
