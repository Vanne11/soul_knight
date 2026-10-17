shader_type canvas_item;
render_mode unshaded;

// Igual que censor.gdshader pero sin luces: los avisos de los jefes (zonas de peligro)
// tienen que leerse siempre, tambien en la penumbra. color_amount lo sincroniza
// BossZone con Censor.amount(sala) para que nazcan grises y se coloreen al liberar.
uniform float color_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec3 grey_tint : source_color = vec3(0.92, 0.92, 1.0);

void fragment() {
	vec4 c = COLOR;
	float l = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	vec3 g = vec3(l) * grey_tint;
	COLOR = vec4(mix(g, c.rgb, color_amount), c.a);
}
