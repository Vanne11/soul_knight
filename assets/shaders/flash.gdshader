// Destello blanco al recibir un golpe.
//
// Un shader de tipo `canvas_item` se ejecuta por pixel sobre el sprite.
// `uniform` = parametro que se puede animar desde GDScript con un Tween:
//   tween.tween_property(sprite, "material:shader_parameter/flash", 0.0, 0.15)
shader_type canvas_item;

uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	// Mezclamos hacia el color de destello, respetando la transparencia.
	tex.rgb = mix(tex.rgb, flash_color.rgb, flash * tex.a);
	COLOR = tex;
}
