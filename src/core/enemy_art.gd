class_name EnemyArt
extends RefCounted

## Dónde está el arte de cada enemigo: assets/sprites/enemies/<reino>/<enemigo>/ (índice en
## assets/data/enemy_art.json, lo escribe tools/ordenar_sprites_enemigos.py). Si un enemigo no
## está en el índice (arte recién generado, sin ordenar), se busca en la raíz de siempre.

const BASE := "res://assets/sprites/enemies/"
const INDEX := "res://assets/data/enemy_art.json"

static var _index: Dictionary = {}
static var _loaded := false


## Carpeta del enemigo, con "/" al final.
static func dir(variant: String) -> String:
	if not _loaded:
		_loaded = true
		var f := FileAccess.open(INDEX, FileAccess.READ)
		if f != null:
			var d = JSON.parse_string(f.get_as_text())
			if d is Dictionary:
				_index = d
	if _index.has(variant):
		return BASE + String(_index[variant]) + "/"
	return BASE


## SpriteFrames del enemigo (<carpeta>/<variante>_sprite_frames.tres).
static func frames(variant: String) -> String:
	return dir(variant) + variant + "_sprite_frames.tres"


## Un archivo del enemigo por nombre (ej. "ladilla_idle_00.png").
static func file(variant: String, name: String) -> String:
	return dir(variant) + name
