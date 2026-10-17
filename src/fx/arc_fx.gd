class_name ArcFx
extends RefCounted

## Arco electrico entre dos puntos (cadena del Dildo Electrico). Linea quebrada que
## se desvanece en 0.18 s. Solo presentacion.

static func zap(parent: Node, from: Vector2, to: Vector2) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var line := Line2D.new()
	line.z_index = 6
	line.width = 2.5
	line.default_color = Color(0.55, 0.9, 1.0)
	var n := 6
	var perp := (to - from).orthogonal().normalized()
	var pts := PackedVector2Array()
	for i in n + 1:
		var p := from.lerp(to, float(i) / n)
		if i > 0 and i < n:
			p += perp * RNG.randf_range(-7.0, 7.0)
		pts.append(p)
	line.points = pts
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	line.material = mat
	parent.add_child(line)
	var tw := line.create_tween()
	tw.tween_property(line, "modulate:a", 0.0, 0.18)
	tw.tween_callback(line.queue_free)
