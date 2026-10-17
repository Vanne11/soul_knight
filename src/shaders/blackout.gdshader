shader_type canvas_item;

// Apagon de los jefes: pantalla casi negra salvo el halo del jugador (hole_a) y un
// brillo tenue sobre el jefe (hole_b). Posiciones en unidades del viewport.
uniform vec2 vp_size = vec2(1280.0, 720.0);
uniform vec2 hole_a = vec2(640.0, 360.0);
uniform float rad_a = 160.0;
uniform vec2 hole_b = vec2(-1000.0, -1000.0);
uniform float rad_b = 40.0;
uniform vec3 tint = vec3(0.0, 0.0, 0.0);
uniform float amount : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 p = SCREEN_UV * vp_size;
	float la = smoothstep(rad_a, rad_a * 0.5, distance(p, hole_a));
	float lb = smoothstep(rad_b, rad_b * 0.35, distance(p, hole_b)) * 0.75;
	float lit = max(la, lb);
	COLOR = vec4(tint, amount * (1.0 - lit));
}
