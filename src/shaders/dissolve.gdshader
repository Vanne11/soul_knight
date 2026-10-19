shader_type canvas_item;
// Disolucion por ruido en bloques: progress 0 = se ve todo, 1 = desaparece.
// El ruido sale de la posicion en pantalla, asi logo y texto comparten el patron.
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float block = 6.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	float n = hash(floor(FRAGCOORD.xy / block));
	// el umbral recorre 0..1 con un margen para que progress=1 borre todo
	float t = progress * 1.2;
	float a = smoothstep(t - 0.2, t, n);
	COLOR.a *= a;
}
