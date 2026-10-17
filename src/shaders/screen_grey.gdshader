shader_type canvas_item;

// Pantalla en blanco y negro (la censura total de la Hoja de Parra, fase final).
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float amount : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec3 c = textureLod(screen_tex, SCREEN_UV, 0.0).rgb;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	l = clamp((l - 0.5) * 1.12 + 0.5, 0.0, 1.0);
	COLOR = vec4(mix(c, vec3(l), amount), 1.0);
}
