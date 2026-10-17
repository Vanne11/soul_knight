shader_type canvas_item;

// Destello blanco al recibir un golpe. canvas_item normal (sin unshaded): las luces
// y la censura siguen funcionando, solo se mezcla el color del sprite con blanco.
uniform float flash : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	COLOR.rgb = mix(COLOR.rgb, vec3(1.0), flash);
}
