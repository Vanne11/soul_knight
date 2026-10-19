class_name SilencioSuelo
extends Node2D

## Suelo PROVISORIO de una sala del Silencio: color plano de gris tibio con juntas muy tenues, sin
## ornamento ni decoracion (diseno_E3: "sala de reuniones gris tibia", sin chistes visuales). Cada
## sala trae su tono; la luz de la sala (RoomLighting) lo va oscureciendo.

const TONES := {
	"entrada": Color("86817a"),
	"pasillo": Color("7c7872"),
	"turno": Color("8d867b"),      # sala de reuniones: gris tibio, de madera
	"espacio": Color("7d8086"),    # anden: gris frio y uniforme
	"revision": Color("786f66"),   # cuarto: tibio y apagado
	"mensajes": Color("5c5d66"),   # salon oscuro
	"cinco_puertas": Color("767379"),  # pasillo de las cinco puertas: gris tibio, mas frio que arriba
	"pasillo_s6": Color("6a6a73"),     # el pasillo largo: la luz ya es casi nada
	"habitacion": Color("726b66"),     # habitacion: tibia y apagada
	"jefe": Color("65646d"),           # sala del jefe: gris azulado, mas frio
	"memoria": Color("6a686b"),        # sala de memoria: piedra gris
	"plaza": Color("b9a47c"),          # Plaza de la Palabra: ocre claro (el reino ya transformado)
}
const TILE := 64.0

var size := Vector2(512, 384)
var kind := "pasillo"


func _draw() -> void:
	var tone: Color = TONES.get(kind, TONES["pasillo"])
	draw_rect(Rect2(Vector2.ZERO, size), tone)
	var seam := tone.darkened(0.16)
	seam.a = 0.55
	match kind:
		"turno":  # tablones largos, horizontales
			var y := 0.0
			while y < size.y:
				draw_line(Vector2(0, y), Vector2(size.x, y), seam, 1.0)
				y += 32.0
		"espacio":  # losas del anden y una linea de seguridad junto a cada borde
			var x := 0.0
			while x < size.x:
				draw_line(Vector2(x, 0), Vector2(x, size.y), seam, 1.0)
				x += TILE * 2.0
			var line := tone.lightened(0.18)
			draw_rect(Rect2(0, 44, size.x, 4), line)
			draw_rect(Rect2(0, size.y - 48, size.x, 4), line)
		_:  # losetas cuadradas
			var gx := 0.0
			while gx < size.x:
				draw_line(Vector2(gx, 0), Vector2(gx, size.y), seam, 1.0)
				gx += TILE
			var gy := 0.0
			while gy < size.y:
				draw_line(Vector2(0, gy), Vector2(size.x, gy), seam, 1.0)
				gy += TILE
