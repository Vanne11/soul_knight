class_name BossPicker

## Sorteo del jefe del reino: el original (claves "boss"/"boss_name" del piso) o el
## ALTERNATIVO ("boss_alt"/"boss_alt_name", etapa 6c). Solo los pisos con las dos claves
## sortean; el resto (o los de 1a etapa, sin jefe) siguen con un unico jefe.
## Regla: 50/50 segun la semilla de la partida y el piso (misma semilla, mismo jefe: vale para
## la semilla diaria y para repetir partidas); no depende del progreso, asi dos jugadores con la
## misma semilla se enfrentan al mismo jefe.
## Cada llamada da la misma respuesta: main, la presentacion y el menu de depuracion coinciden.

## "" sorteo normal, "main" siempre el original, "alt" siempre el alternativo (pruebas/depuracion).
static var force := ""


## true si el piso (datos fd) con esa semilla usa el jefe alternativo.
static func uses_alt(fd: Dictionary, seed_: int, floor_n: int) -> bool:
	if str(fd.get("boss", "")) == "" or str(fd.get("boss_alt", "")) == "":
		return false
	if force != "":
		return force == "alt"
	var h := (absi(seed_) * 2654435761 + floor_n * 40503) & 0x7fffffff
	return ((h >> 11) & 1) == 1


## {variant, name}: variante de sprite/script y nombre (en espanol, como en los datos) del jefe.
static func pick(fd: Dictionary, seed_: int, floor_n: int) -> Dictionary:
	if uses_alt(fd, seed_, floor_n):
		return {"variant": str(fd.boss_alt), "name": str(fd.get("boss_alt_name", fd.get("boss_name", ""))), "alt": true}
	return {"variant": str(fd.get("boss", "")), "name": str(fd.get("boss_name", "")), "alt": false}
