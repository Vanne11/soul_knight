shader_type canvas_item;

// Censura de la sala: color_amount 0 = gris (censurada), 1 = color real (liberada).
// Respeta las luces 2D (no es unshaded). Lo maneja src/fx/censor.gd.
uniform float color_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec3 grey_tint : source_color = vec3(0.88, 0.88, 0.95);
uniform float grey_dark : hint_range(0.0, 1.0) = 0.7;

void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	float l = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	vec3 g = vec3(l) * grey_tint * grey_dark;
	COLOR = vec4(mix(g, c.rgb, color_amount), c.a);
}
