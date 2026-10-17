shader_type canvas_item;
// Cortinilla de rombos pixelados: una rejilla de diamantes que crecen hasta cubrir
// la pantalla (progress 0 = nada, 1 = todo cubierto). Sin difuminado: bordes duros.

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec2 screen_size = vec2(1280.0, 720.0);
uniform float cell_px = 32.0;
uniform vec4 fill_color : source_color = vec4(0.1019, 0.0431, 0.1490, 1.0);   // #1a0b26
uniform vec4 band_color : source_color = vec4(1.0, 0.3098, 0.6039, 1.0);      // #ff4f9a
uniform vec4 edge_color : source_color = vec4(0.9412, 0.7529, 0.2902, 1.0);   // #f0c04a

void fragment() {
	// Posicion en pixeles de pantalla y celda entera (bloques nitidos).
	vec2 px = floor(UV * screen_size);
	vec2 cell = floor(px / cell_px);
	vec2 inner = (px - cell * cell_px + 0.5) / cell_px - 0.5;
	float d = abs(inner.x) + abs(inner.y) * 1.0; // 0 centro .. 1 esquina

	// Retardo en diagonal: la onda barre de arriba-izquierda a abajo-derecha.
	vec2 cells = ceil(screen_size / cell_px);
	float delay = (cell.x + cell.y) / (cells.x + cells.y);
	float local = clamp(progress * 1.55 - delay * 0.4, 0.0, 1.15);

	if (d < local - 0.16) {
		COLOR = fill_color;
	} else if (d < local - 0.08) {
		COLOR = band_color;
	} else if (d < local) {
		COLOR = edge_color;
	} else {
		COLOR = vec4(0.0);
	}
}
