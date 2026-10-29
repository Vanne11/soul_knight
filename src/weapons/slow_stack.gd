class_name SlowStack
extends RefCounted

## Frenados de varias fuentes sobre un mismo enemigo (charco de globos, masilla, lubricante,
## espermicida). Cada fuente pone y quita SOLO su factor; la velocidad es base x producto.
## Antes cada una guardaba su propia "velocidad original": si una entraba con otra ya puesta,
## guardaba la velocidad frenada como original y el enemigo quedaba lento el resto de la sala.
## Si la IA recalcula la velocidad (fase del jefe, PSA, Ego), lo que encuentra pasa a ser la base.


## Pone (o cambia) el factor de `key` sobre la propiedad `prop` del enemigo.
static func set_factor(e: Object, key: String, factor: float, prop := "move_speed") -> void:
	if not is_instance_valid(e) or not (prop in e):
		return
	var d := _data(e, prop)
	d.f[key] = factor
	_refresh(e, prop, d)


## Quita el factor de `key` (no pasa nada si no estaba).
static func clear(e: Object, key: String, prop := "move_speed") -> void:
	if not is_instance_valid(e) or not e.has_meta(_meta(prop)):
		return
	var d: Dictionary = e.get_meta(_meta(prop))
	d.f.erase(key)
	_refresh(e, prop, d)


static func has_factor(e: Object, key: String, prop := "move_speed") -> bool:
	return is_instance_valid(e) and e.has_meta(_meta(prop)) and e.get_meta(_meta(prop)).f.has(key)


static func _meta(prop: String) -> String:
	return "slow_stack_" + prop


static func _data(e: Object, prop: String) -> Dictionary:
	if not e.has_meta(_meta(prop)):
		var cur := float(e.get(prop))
		e.set_meta(_meta(prop), {"base": cur, "applied": cur, "f": {}})
	return e.get_meta(_meta(prop))


static func _refresh(e: Object, prop: String, d: Dictionary) -> void:
	var cur := float(e.get(prop))
	if not is_equal_approx(cur, d.applied):
		d.base = cur  # alguien mas la cambio mientras estaba frenado: esa es la nueva base
	var m := 1.0
	for k in d.f:
		m *= float(d.f[k])
	if d.f.is_empty():
		e.set(prop, d.base)
		e.remove_meta(_meta(prop))
		return
	d.applied = d.base * m
	e.set(prop, d.applied)
