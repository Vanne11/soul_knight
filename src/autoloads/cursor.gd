extends Node
## Cursores pixel art: mira en la partida, puntero dorado en menús/pausa.
## No toca las escenas: vigila la escena actual y la pausa, y solo cambia si difiere.

const ESCENA_PARTIDA := "res://src/scenes/main.tscn"
const BASE := Vector2(1280, 720)
const MIRA := "res://assets/sprites/ui/hud/cursor_aim%s.png"
## En menus: la toallita con alas (cursor_pointer.png, la flecha dorada, queda de repuesto).
const PUNTERO := "res://assets/sprites/ui/hud/cursor_pad%s.png"
# Hotspots en px de arte (se multiplican por la escala): centro de la mira / punta del puntero.
const HOT_MIRA := Vector2(7, 7)
const HOT_PUNTERO := Vector2(7, 1)

var _mira := {}
var _puntero := {}
var _estado_mira := false
var _escala := 0
var _aplicado := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for e in [2, 3]:
		var suf := "" if e == 2 else "_3x"
		_mira[e] = load(MIRA % suf)
		_puntero[e] = load(PUNTERO % suf)
	_aplicar()


func _process(_dt: float) -> void:
	var escena := get_tree().current_scene
	var mira := escena != null and escena.scene_file_path == ESCENA_PARTIDA and not get_tree().paused
	if not _aplicado or mira != _estado_mira or _escala_ventana() != _escala:
		_estado_mira = mira
		_aplicar()


## 3x si la ventana es >= 1.5x la base (los cursores no se escalan con el stretch).
func _escala_ventana() -> int:
	var s := Vector2(DisplayServer.window_get_size()) / BASE
	return 3 if minf(s.x, s.y) >= 1.5 else 2


func _aplicar() -> void:
	_aplicado = true
	_escala = _escala_ventana()
	var e := _escala
	if _estado_mira:
		Input.set_custom_mouse_cursor(_mira[e], Input.CURSOR_ARROW, HOT_MIRA * e + Vector2(e, e) * 0.5)
	else:
		Input.set_custom_mouse_cursor(_puntero[e], Input.CURSOR_ARROW, HOT_PUNTERO * e + Vector2(e * 0.5, 0))
	# La manita de los botones también usa el puntero propio.
	Input.set_custom_mouse_cursor(_puntero[e], Input.CURSOR_POINTING_HAND, HOT_PUNTERO * e + Vector2(e * 0.5, 0))


## Al cerrar, soltar los cursores: si no, Input retiene las texturas cuando el
## RenderingServer ya no existe y Godot avisa de fugas al salir.
func _exit_tree() -> void:
	Input.set_custom_mouse_cursor(null, Input.CURSOR_ARROW)
	Input.set_custom_mouse_cursor(null, Input.CURSOR_POINTING_HAND)
