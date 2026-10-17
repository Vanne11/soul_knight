extends SceneTree

## Vuelca a JSON las constantes de datos de run_manager.gd (solo lo traducible).
## Uso: godot --headless --path . -s tools/dump_world.gd -- <ruta_salida.json>
func _init() -> void:
	var consts: Dictionary = load("res://src/autoloads/run_manager.gd").get_script_constant_map()
	var out := {}
	for k in ["FLOORS", "CHARACTERS", "BLESSINGS", "META_UPGRADES"]:
		out[k] = _clean(consts[k])
	var args := OS.get_cmdline_user_args()
	var f := FileAccess.open(args[0], FileAccess.WRITE)
	f.store_string(JSON.stringify(out, "  "))
	f.close()
	quit()


func _clean(v):
	if v is Dictionary:
		var d := {}
		for k in v:
			d[str(k)] = _clean(v[k])
		return d
	if v is Array:
		return v.map(_clean)
	if v is String or v is int or v is float or v is bool:
		return v
	return null  # Color, etc.: no se traduce
