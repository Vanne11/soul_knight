shader_type canvas_item;
render_mode unshaded, blend_add;

// Polvo en suspension (mas visible cerca de la luz del jugador y dentro de los
// rayos) y rayos diagonales suaves. Todo procedural, sin texturas.
uniform float dust : hint_range(0.0, 1.0) = 0.5;
uniform float rays : hint_range(0.0, 1.0) = 0.0;
uniform float dark : hint_range(0.0, 1.0) = 0.0;
uniform vec2 light_uv = vec2(0.5, 0.5);
uniform vec3 tint : source_color = vec3(1.0, 0.86, 0.6);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float ray_band(vec2 uv, float freq, float speed, float ph) {
	float x = uv.x * 1.6 + uv.y * 0.9;
	float b = sin(x * freq + ph + TIME * speed);
	return smoothstep(0.35, 1.0, b);
}

void fragment() {
	vec2 uv = UV;
	vec2 asp = vec2(16.0 / 9.0, 1.0);

	// rayos diagonales, nacen arriba a la derecha
	float r = ray_band(uv, 7.0, 0.12, 0.0) * 0.6 + ray_band(uv, 13.0, -0.08, 2.0) * 0.4;
	float fall = smoothstep(1.1, 0.0, uv.y + (1.0 - uv.x) * 0.35);
	float ray_a = r * fall * rays * 0.075;

	// polvo: una mota en ~1 de cada 5 celdas, derivando lento
	float acc = 0.0;
	for (int layer = 0; layer < 2; layer++) {
		float sc = layer == 0 ? 26.0 : 15.0;
		float spd = layer == 0 ? 0.010 : 0.018;
		vec2 q = uv * asp * sc + vec2(TIME * spd * sc * 0.6, -TIME * spd * sc * 0.9);
		vec2 id = floor(q);
		vec2 f = fract(q) - 0.5;
		float h = hash(id + float(layer) * 17.3);
		if (h > 0.22) continue;
		vec2 off = vec2(hash(id + 3.1), hash(id + 7.7)) - 0.5;
		off = off * 0.55 + 0.12 * vec2(sin(TIME * 0.7 + h * 40.0), cos(TIME * 0.5 + h * 31.0));
		float dd = length(f - off);
		float size = layer == 0 ? 0.055 : 0.085;
		float m = smoothstep(size, size * 0.2, dd);
		float tw = 0.6 + 0.4 * sin(TIME * 0.9 + h * 90.0);
		acc += m * tw * (layer == 0 ? 0.7 : 1.0);
	}
	float near = smoothstep(0.42, 0.0, length((uv - light_uv) * asp));
	float vis = 0.18 + r * rays * 0.9 + near * (0.35 + dark * 0.9);
	float dust_a = acc * vis * dust * 0.55;

	COLOR = vec4(tint * (ray_a + dust_a), 1.0);
}
