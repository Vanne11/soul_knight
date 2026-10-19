class_name Pasillos
extends RefCounted

## PASILLOS ENTRE REINOS: geometria del mapa del mundo (assets/data/world_map.json) para decidir en que
## pared de la sala del jefe se abre la puerta de cada reino destino. La construccion del pasillo en
## si esta en corridor.gd; el flujo (puertas, cruce, fundido) en main.gd (open_exit / _begin_corridor).

const WORLD_FILE := "res://assets/data/world_map.json"
const DIRS := ["up", "down", "left", "right"]  # mismo orden que Door.Direction

static var _centers: Dictionary = {}
static var _loaded := false


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	var f := FileAccess.open(WORLD_FILE, FileAccess.READ)
	if f == null:
		return
	var d = JSON.parse_string(f.get_as_text())
	if d is Dictionary:
		for r in d.get("regions", []):
			_centers[str(r.id)] = Vector2(float(r.x) + float(r.w) * 0.5, float(r.y) + float(r.h) * 0.5)


## Centro del reino en el mapa del mundo (celdas) o Vector2.INF si el mapa no lo conoce.
static func center_of(region: String) -> Vector2:
	_load()
	return _centers.get(region, Vector2.INF)


## Pared por la que sale quien va de `from` a `to`: "up" (norte), "down", "left" u "right", segun la
## posicion relativa en el mapa del mundo (la y crece hacia abajo). Sin datos: "up" (el centro esta arriba).
static func direction(from: String, to: String) -> String:
	var a := center_of(from)
	var b := center_of(to)
	if a == Vector2.INF or b == Vector2.INF:
		return "up"
	var d := b - a
	if absf(d.x) > absf(d.y):
		return "left" if d.x < 0.0 else "right"
	return "up" if d.y < 0.0 else "down"


## Coordenada a lo largo de la pared (para ordenar dos puertas del mismo lado): x en paredes N/S, y en E/O.
static func along(from: String, to: String, dir: String) -> float:
	var a := center_of(from)
	var b := center_of(to)
	if a == Vector2.INF or b == Vector2.INF:
		return 0.0
	return (b.x - a.x) if dir in ["up", "down"] else (b.y - a.y)


static func dir_index(dir: String) -> int:
	return DIRS.find(dir)


static func opposite(dir: String) -> String:
	return {"up": "down", "down": "up", "left": "right", "right": "left"}[dir]


## Reparto de puertas en las paredes de una sala. `items`: Array de {dir, along, ...}. `taken`: posiciones
## (px locales) de puertas que ya existen. `size_px`: tamano de la sala. `ok`: Callable(pos_local, dir) -> bool
## (el sitio de dentro es suelo pisable). Devuelve los mismos items con "pos": Vector2 local de la puerta.
## Dos o mas del mismo lado se separan a lo largo de la pared, en el orden de su direccion real.
static func layout(items: Array, taken: Array, size_px: Vector2, ok: Callable) -> Array:
	var out: Array = []
	for dir in DIRS:
		var same: Array = items.filter(func(it): return it.dir == dir)
		if same.is_empty():
			continue
		same.sort_custom(func(a, b): return a.along < b.along)
		var horizontal: bool = dir in ["up", "down"]
		var length := size_px.x if horizontal else size_px.y
		var slots: Array = []
		for t in [0.5, 0.3, 0.7, 0.2, 0.8, 0.4, 0.6, 0.15, 0.85]:
			var pos := _wall_pos(dir, t, size_px)
			if not ok.call(pos, dir):
				continue
			var free := true
			for tk in taken:
				if (tk as Vector2).distance_to(pos) < 170.0:
					free = false
			for s in slots:
				if absf((s as float) - t) * length < 170.0:
					free = false
			if free:
				slots.append(t)
			if slots.size() >= same.size():
				break
		# sin sitios libres suficientes: el resto va a lo largo, sin comprobar (mejor puerta apretada que ninguna)
		var k := 1
		while slots.size() < same.size():
			slots.append(clampf(0.5 + 0.12 * k * (1 if k % 2 == 0 else -1), 0.1, 0.9))
			k += 1
		slots.sort()
		for i in same.size():
			var it: Dictionary = same[i]
			it["pos"] = _wall_pos(dir, slots[i], size_px)
			out.append(it)
	return out


static func _wall_pos(dir: String, t: float, size_px: Vector2) -> Vector2:
	match dir:
		"up": return Vector2(size_px.x * t, 0.0)
		"down": return Vector2(size_px.x * t, size_px.y)
		"left": return Vector2(0.0, size_px.y * t)
	return Vector2(size_px.x, size_px.y * t)
