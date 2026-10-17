shader_type canvas_item;
render_mode unshaded, blend_mix;

// Vineta suave de bordes; con poca vida se enrojece y pulsa levemente.
uniform float strength : hint_range(0.0, 1.0) = 0.4;
uniform float low_health : hint_range(0.0, 1.0) = 0.0;
uniform float pulse_amount : hint_range(0.0, 1.0) = 1.0;
uniform vec3 blood_color : source_color = vec3(0.55, 0.02, 0.05);

void fragment() {
	vec2 p = (UV - 0.5) * vec2(1.0, 0.82) * 2.0;
	float d = clamp(length(p) * 0.82, 0.0, 1.5);
	float v = smoothstep(0.45, 1.15, d);
	float pulse = 0.5 + 0.5 * sin(TIME * (2.2 + 2.6 * low_health));
	pulse = mix(1.0, pulse, pulse_amount);
	vec3 col = mix(vec3(0.02, 0.0, 0.04), blood_color, clamp(low_health * 1.2, 0.0, 1.0));
	float a = v * (strength + low_health * 0.3 * mix(0.6, 1.0, pulse));
	COLOR = vec4(col, clamp(a, 0.0, 0.85));
}
