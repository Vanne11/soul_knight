extends Label
class_name FloatingText

## Numero de dano / texto flotante en fuente pixel (Silkscreen + sombra dura).
## Vive en un CanvasLayer de UI (ver FloatingTextManager): se guarda la posicion
## de MUNDO y cada frame se proyecta a pantalla redondeada a pixeles enteros, asi
## la fuente se rasteriza a su tamano real (nitida) aunque la camara tenga zoom.
## No se anima `scale` (emborrona): solo posicion en pixeles enteros y alpha.

var lifetime: float = 1.2
var fade_delay: float = 0.55
var rise_px: float = 48.0     # subida total en pixeles de pantalla
var bounce_px: float = 0.0    # salto extra inicial (criticos)

var _world_pos: Vector2 = Vector2.ZERO
var _t: float = 0.0
var _mgr: Node = null


func setup(mgr: Node, world_pos: Vector2, txt: String, color: Color, is_crit: bool, is_number: bool, font_size: int = 0) -> void:
	_mgr = mgr
	_world_pos = world_pos
	_t = 0.0
	modulate.a = 1.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Critico: oro, Bold 24 y "!"; normal: Silkscreen 16. Texto no numerico: 16.
	if is_crit:
		txt += "!"
		color = HudStyle.GOLD
		lifetime = 1.4
		rise_px = 64.0
		bounce_px = 12.0
	else:
		lifetime = 1.2
		rise_px = 48.0
		bounce_px = 0.0
	text = txt
	HudStyle.style_label(self, 24 if is_crit else (font_size if font_size > 0 else 16), color, is_crit or font_size > 16)
	# Fuerza el tamano minimo con el texto nuevo para centrar bien.
	reset_size()
	size = get_minimum_size()
	pivot_offset = Vector2.ZERO
	_place()


func _process(delta: float) -> void:
	_t += delta
	if _t >= lifetime:
		_mgr.return_to_pool(self)
		return
	if _t > fade_delay:
		modulate.a = 1.0 - clampf((_t - fade_delay) / (lifetime - fade_delay), 0.0, 1.0)
	_place()


## Mundo -> pantalla, redondeado a pixel entero.
func _place() -> void:
	var k := clampf(_t / lifetime, 0.0, 1.0)
	var rise := (1.0 - pow(1.0 - k, 2.0)) * rise_px
	# Salto inicial: sube rapido bounce_px y vuelve en el primer ~0.25 s.
	var hop := 0.0
	if bounce_px > 0.0 and _t < 0.25:
		hop = sin(_t / 0.25 * PI) * bounce_px
	var scr: Vector2 = get_viewport().get_canvas_transform() * _world_pos
	position = (scr + Vector2(-size.x * 0.5, -size.y * 0.5 - rise - hop)).round()
