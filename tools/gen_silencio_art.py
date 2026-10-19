"""Arte PROVISORIO de Las Tierras del Silencio, piso 1 "Superficie" (assets/sprites/silencio/).

Uso: python3 tools/gen_silencio_art.py

Reglas del reino (diseno_E3_silencio.md, seccion 0): figuras = siluetas planas, sin cara, sin genero
marcado, tamano humano (el heroe mide 32x48); NUNCA caricatura (sin bigotes, cejas, mazos ni nubes).
Paleta de gris tibio; la luz es lo unico que crece. Nada de chistes visuales.

Piezas (1 pixel de arte = 1 pixel de mundo, igual que el resto del juego):
  figura_pie_a/b/c   tres cuerpos de pie (delgado, ancho, redondeado), 32x48 aprox.
  figura_sentada     sentada de frente, tras una mesa (32x36)
  figura_espalda     sentada de espaldas, para la sala de revision (32x40)
  mesa_larga         mesa de reuniones, vista 3/4 (256x48)
  silla              silla de la sala de reuniones (22x22)
  banco              banco de anden de 3 asientos (96x24)
  escritorio         escritorio de la sala de revision (96x40)
  lampara            lampara de escritorio apagada (14x22)
  panel_caminos      cartel de dos caminos, sin letras (88x56; las letras las pone el codigo)
  puerta_pintada     puerta dibujada en el muro, no abre (44x64)
  bolsa              bolsa y abrigo sobre un asiento (28x16)
Piso 2 "Fondo" (S5 Cinco puertas, S6 El pasillo):
  puerta_s5          puerta de una estacion, hueco oscuro con marco (44x64)
  puerta_cerrada     sexta puerta: cerrada, sin picaporte a la vista (44x64)
  puerta_adentro     puerta con el picaporte hacia el lado de adentro (44x64)
  linterna, mochila, nota, vaso   objetos cotidianos de las estaciones
  figura_dormida     sentada contra la pared, cabeza baja (36x40)
  figura_encogida    de pie, hombros caidos, mas baja (36x44)
  figura_brazo       de pie con un brazo extendido contra la pared (44x52)
  interruptor, telefono          el interruptor lejano y el telefono sin pantalla
Jefe "El Pacto de Silencio" y sala de memoria (parte 2 del piso Fondo; ver gen_pacto_memoria):
  pacto_idle_0/1, pacto_attack, pacto_tired, pacto_hurt, pacto_death   la asamblea bajo la cortina (200x168)
  campana, olla, vidrio          los objetos de ruido del borde de la arena
  nicho_apagado, nicho_encendido, mesa_flores, flor_0..11, panel_mudo, puerta_luz, panel_ayuda   la sala de memoria
  fig_cara_0..5, banco_plaza, farol, fuente    el reino liberado (siluetas con cara simple, paleta calida)
"""
import random
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets/sprites/silencio"

OL = (13, 11, 15, 255)  # contorno comun del juego
BODY = (66, 66, 78, 255)
BODY_HI = (92, 92, 104, 255)
BODY_LO = (46, 46, 56, 255)
WOOD = (120, 112, 100, 255)
WOOD_HI = (146, 138, 124, 255)
WOOD_LO = (88, 82, 74, 255)
METAL = (110, 112, 120, 255)


def canvas(w, h):
	im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
	return im, ImageDraw.Draw(im)


def outline(im, col=OL):
	"""Contorno de 1 px alrededor de lo opaco."""
	px = im.load()
	w, h = im.size
	edge = []
	for y in range(h):
		for x in range(w):
			if px[x, y][3] > 0:
				continue
			for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
				nx, ny = x + dx, y + dy
				if 0 <= nx < w and 0 <= ny < h and px[nx, ny][3] > 0 and px[nx, ny] != col:
					edge.append((x, y))
					break
	for p in edge:
		px[p] = col
	return im


def shade(im, hi=BODY_HI, lo=BODY_LO, seed=1):
	"""Luz plana desde arriba a la izquierda: una franja clara y otra oscura, sin rasgos."""
	px = im.load()
	w, h = im.size
	rng = random.Random(seed)
	for y in range(h):
		for x in range(w):
			if px[x, y][3] == 0 or px[x, y] == OL:
				continue
			left = x == 0 or px[x - 1, y][3] == 0
			right = x == w - 1 or px[x + 1, y][3] == 0
			if left and rng.random() < 0.9:
				px[x, y] = hi
			elif right:
				px[x, y] = lo
	return im


def figura_pie(name, shoulder, hip, head_r, seed):
	w, h = 36, 52
	im, d = canvas(w, h)
	cx = w // 2
	top = 3
	# cabeza lisa: un ovalo sin ningun rasgo
	d.ellipse([cx - head_r, top, cx + head_r, top + head_r * 2 + 2], fill=BODY)
	neck = top + head_r * 2 + 2
	# torso + piernas: un solo bloque plano
	d.polygon([(cx - shoulder, neck + 2), (cx + shoulder, neck + 2), (cx + hip, 36), (cx + hip - 2, h - 3),
		(cx + 1, h - 3), (cx + 1, 38), (cx - 1, 38), (cx - 1, h - 3), (cx - hip + 2, h - 3), (cx - hip, 36)], fill=BODY)
	# brazos pegados al cuerpo
	d.rectangle([cx - shoulder - 3, neck + 3, cx - shoulder - 1, 33], fill=BODY)
	d.rectangle([cx + shoulder + 1, neck + 3, cx + shoulder + 3, 33], fill=BODY)
	shade(im, seed=seed)
	outline(im)
	im.save(OUT / name)


def figura_sentada(name, back):
	w, h = 36, 40
	im, d = canvas(w, h)
	cx = w // 2
	d.ellipse([cx - 6, 2, cx + 6, 16], fill=BODY)
	d.polygon([(cx - 11, 18), (cx + 11, 18), (cx + 12, 34), (cx - 12, 34)], fill=BODY)
	if not back:
		d.rectangle([cx - 14, 22, cx - 11, 32], fill=BODY)  # brazos sobre la mesa
		d.rectangle([cx + 11, 22, cx + 14, 32], fill=BODY)
	shade(im)
	outline(im)
	im.save(OUT / name)


def mesa_larga():
	w, h = 256, 48
	im, d = canvas(w, h)
	d.rectangle([0, 0, w - 1, h - 11], fill=WOOD)  # tablero
	d.rectangle([0, h - 11, w - 1, h - 1], fill=WOOD_LO)  # canto frontal
	d.rectangle([1, 1, w - 2, 3], fill=WOOD_HI)
	for x in range(32, w, 64):  # juntas del tablero
		d.line([(x, 4), (x, h - 12)], fill=WOOD_LO)
	outline(im)
	im.save(OUT / "mesa_larga.png")


def silla():
	im, d = canvas(22, 22)
	d.rectangle([3, 2, 18, 8], fill=WOOD_LO)  # respaldo
	d.rectangle([2, 8, 19, 16], fill=WOOD)
	d.rectangle([4, 16, 6, 20], fill=WOOD_LO)
	d.rectangle([15, 16, 17, 20], fill=WOOD_LO)
	outline(im)
	im.save(OUT / "silla.png")


def banco():
	im, d = canvas(96, 24)
	d.rectangle([0, 4, 95, 12], fill=METAL)  # asiento corrido
	d.rectangle([0, 12, 95, 15], fill=(80, 82, 90, 255))
	for x in (4, 44, 84):
		d.rectangle([x, 15, x + 4, 22], fill=(80, 82, 90, 255))
	for x in (32, 64):  # separadores de los 3 asientos
		d.line([(x, 4), (x, 12)], fill=(80, 82, 90, 255))
	outline(im)
	im.save(OUT / "banco.png")


def escritorio():
	im, d = canvas(96, 40)
	d.rectangle([0, 0, 95, 27], fill=WOOD)
	d.rectangle([0, 27, 95, 39], fill=WOOD_LO)
	d.rectangle([1, 1, 94, 3], fill=WOOD_HI)
	d.rectangle([60, 28, 90, 39], fill=(70, 64, 58, 255))  # cajon cerrado
	outline(im)
	im.save(OUT / "escritorio.png")


def lampara():
	im, d = canvas(14, 22)
	d.rectangle([2, 19, 11, 21], fill=METAL)
	d.line([(7, 19), (7, 8)], fill=METAL)
	d.polygon([(2, 8), (12, 8), (10, 2), (4, 2)], fill=(150, 142, 118, 255))
	outline(im)
	im.save(OUT / "lampara.png")


def panel_caminos():
	im, d = canvas(88, 56)
	d.rectangle([4, 4, 83, 38], fill=(168, 160, 144, 255))
	d.rectangle([6, 6, 81, 36], fill=(196, 190, 176, 255))
	d.rectangle([22, 38, 25, 54], fill=WOOD_LO)
	d.rectangle([62, 38, 65, 54], fill=WOOD_LO)
	d.line([(44, 7), (44, 35)], fill=(150, 144, 130, 255))  # division A | B
	outline(im)
	im.save(OUT / "panel_caminos.png")


def puerta_pintada():
	im, d = canvas(44, 64)
	d.rectangle([0, 0, 43, 63], fill=(122, 118, 112, 255))
	d.rectangle([5, 6, 38, 63], fill=(98, 94, 90, 255))  # hueco "pintado"
	d.rectangle([7, 8, 36, 63], fill=(108, 104, 98, 255))
	d.rectangle([30, 36, 33, 40], fill=(150, 146, 136, 255))  # picaporte pintado
	outline(im)
	im.save(OUT / "puerta_pintada.png")


def bolsa():
	im, d = canvas(28, 16)
	d.rounded_rectangle([1, 4, 18, 15], radius=3, fill=(84, 78, 72, 255))  # bolso
	d.arc([4, 0, 15, 10], 180, 360, fill=OL)
	d.polygon([(16, 6), (27, 8), (26, 15), (15, 15)], fill=(70, 70, 82, 255))  # abrigo doblado
	outline(im)
	im.save(OUT / "bolsa.png")


def puerta_s5():
	im, d = canvas(44, 64)
	d.rectangle([0, 0, 43, 63], fill=(122, 118, 112, 255))  # marco en el muro
	d.rectangle([5, 6, 38, 63], fill=(30, 29, 34, 255))     # hueco oscuro
	d.rectangle([5, 6, 38, 8], fill=(74, 72, 80, 255))
	outline(im)
	im.save(OUT / "puerta_s5.png")


def puerta_cerrada():
	im, d = canvas(44, 64)
	d.rectangle([0, 0, 43, 63], fill=(112, 108, 104, 255))
	d.rectangle([5, 6, 38, 63], fill=(70, 66, 64, 255))
	d.rectangle([7, 8, 36, 63], fill=(78, 74, 72, 255))
	d.line([(21, 8), (21, 62)], fill=(60, 57, 56, 255))
	outline(im)
	im.save(OUT / "puerta_cerrada.png")


def puerta_adentro():
	im, d = canvas(44, 64)
	d.rectangle([0, 0, 43, 63], fill=(100, 96, 92, 255))
	d.rectangle([5, 6, 38, 63], fill=(86, 80, 76, 255))
	d.rectangle([7, 8, 36, 63], fill=(96, 90, 84, 255))
	d.rectangle([9, 36, 13, 40], fill=(168, 160, 142, 255))  # picaporte del lado de adentro
	outline(im)
	im.save(OUT / "puerta_adentro.png")


def linterna():
	im, d = canvas(16, 12)
	d.rectangle([1, 3, 9, 9], fill=METAL)
	d.rectangle([9, 2, 14, 10], fill=(150, 144, 120, 255))
	outline(im)
	im.save(OUT / "linterna.png")


def mochila():
	im, d = canvas(16, 20)
	d.rounded_rectangle([1, 4, 14, 18], radius=3, fill=(84, 78, 72, 255))
	d.rectangle([4, 9, 11, 14], fill=(70, 64, 60, 255))
	d.arc([3, 0, 12, 9], 180, 360, fill=OL)
	outline(im)
	im.save(OUT / "mochila.png")


def nota():
	im, d = canvas(12, 14)
	d.rectangle([1, 1, 10, 12], fill=(210, 204, 188, 255))
	for y in (4, 6, 8):
		d.line([(3, y), (8, y)], fill=(150, 144, 130, 255))
	outline(im)
	im.save(OUT / "nota.png")


def vaso():
	im, d = canvas(10, 12)
	d.polygon([(1, 1), (8, 1), (7, 10), (2, 10)], fill=(150, 156, 160, 255))
	d.rectangle([2, 5, 7, 9], fill=(120, 126, 132, 255))
	outline(im)
	im.save(OUT / "vaso.png")


def figura_dormida():
	w, h = 36, 40
	im, d = canvas(w, h)
	cx = w // 2
	d.ellipse([cx - 5, 8, cx + 7, 22], fill=BODY)  # cabeza caida hacia un lado
	d.polygon([(cx - 11, 22), (cx + 11, 20), (cx + 12, 36), (cx - 12, 36)], fill=BODY)
	d.rectangle([cx - 14, 26, cx - 11, 35], fill=BODY)
	d.rectangle([cx + 11, 26, cx + 14, 35], fill=BODY)
	shade(im, seed=5)
	outline(im)
	im.save(OUT / "figura_dormida.png")


def figura_encogida():
	w, h = 36, 48
	im, d = canvas(w, h)
	cx = w // 2
	d.ellipse([cx - 5, 12, cx + 5, 24], fill=BODY)  # cabeza baja
	d.polygon([(cx - 9, 25), (cx + 9, 25), (cx + 8, 38), (cx + 7, h - 3), (cx + 1, h - 3), (cx, 40),
		(cx - 1, 40), (cx - 1, h - 3), (cx - 7, h - 3), (cx - 8, 38)], fill=BODY)
	d.rectangle([cx - 11, 26, cx - 9, 38], fill=BODY)
	d.rectangle([cx + 9, 26, cx + 11, 38], fill=BODY)
	shade(im, seed=6)
	outline(im)
	im.save(OUT / "figura_encogida.png")


def figura_brazo():
	w, h = 52, 52
	im, d = canvas(w, h)
	cx = 20
	d.ellipse([cx - 5, 3, cx + 5, 15], fill=BODY)
	d.polygon([(cx - 8, 17), (cx + 8, 17), (cx + 9, 36), (cx + 8, h - 3), (cx + 1, h - 3), (cx + 1, 38),
		(cx - 1, 38), (cx - 1, h - 3), (cx - 8, h - 3), (cx - 9, 36)], fill=BODY)
	d.rectangle([cx - 11, 19, cx - 9, 34], fill=BODY)
	d.rectangle([cx + 8, 19, w - 4, 22], fill=BODY)  # el brazo se apoya en la pared
	shade(im, seed=7)
	outline(im)
	im.save(OUT / "figura_brazo.png")


def interruptor():
	im, d = canvas(12, 16)
	d.rectangle([1, 1, 10, 14], fill=(150, 146, 138, 255))
	d.rectangle([4, 4, 7, 10], fill=(70, 68, 72, 255))
	outline(im)
	im.save(OUT / "interruptor.png")


def telefono():
	im, d = canvas(28, 16)
	d.rounded_rectangle([1, 3, 26, 14], radius=2, fill=(72, 72, 82, 255))
	d.rectangle([4, 5, 23, 11], fill=(24, 24, 28, 255))  # sin pantalla: apagado
	outline(im)
	im.save(OUT / "telefono.png")


# ---------------------------------------------------------------- parte 2 del piso Fondo (jefe, memoria, reino liberado)
CURT = (70, 68, 90, 255)
CURT_HI = (104, 102, 126, 255)
CURT_LO = (48, 46, 64, 255)
STONE = (112, 110, 112, 255)
STONE_HI = (140, 138, 138, 255)
STONE_LO = (80, 78, 82, 255)
CANDLE = (214, 206, 184, 255)
FLAME = (255, 214, 130, 255)
WARM_SKIN = [(214, 170, 130, 255), (176, 128, 92, 255), (236, 196, 158, 255), (140, 98, 70, 255)]


def _seated(d, cx, y, w, bow=0, col=BODY):
	"""Silueta sentada de frente (cabeza ovalada lisa y un bloque de torso). bow = cuanto baja la cabeza."""
	d.ellipse([cx - w // 3, y + bow, cx + w // 3, y + w // 2 + 4 + bow], fill=col)
	d.polygon([(cx - w // 2, y + w // 2 + 6), (cx + w // 2, y + w // 2 + 6), (cx + w // 2 + 2, y + w + 12), (cx - w // 2 - 2, y + w + 12)], fill=col)


def _curtain(d, w, drop, sway):
	"""Cortina pesada: un dosel oscuro con pliegues que cuelga sobre la asamblea."""
	d.rectangle([0, 0, w - 1, drop], fill=CURT)
	for x in range(0, w, 14):
		bottom = drop + 8 + int(6 * ((x // 14 + sway) % 2))
		d.polygon([(x, drop - 4), (x + 14, drop - 4), (x + 13, bottom), (x + 1, bottom)], fill=CURT)
		d.line([(x + 7, 2), (x + 7, bottom - 2)], fill=CURT_LO)
	d.rectangle([0, 0, w - 1, 3], fill=CURT_HI)
	for side in (0, 1):  # los pliegues laterales que caen casi hasta el suelo
		x0 = 0 if side == 0 else w - 20
		d.polygon([(x0, drop), (x0 + 20, drop), (x0 + 16, drop + 60), (x0 + 4, drop + 66)], fill=CURT)
		d.line([(x0 + 9, drop), (x0 + 9, drop + 62)], fill=CURT_LO)


def pacto_frame(name, sway=0, bow=0, drop=46, slump=0, tint=None, standing=False):
	w, h = 200, 168
	im, d = canvas(w, h)
	col = (132, 132, 152, 255) if tint is None else tint
	if standing:
		# fin del pacto: se ponen de pie, sin cortina, cada una con una luz en las manos
		for i in range(7):
			cx = 22 + i * 26
			top = 58 + (i % 2) * 6
			d.ellipse([cx - 6, top, cx + 6, top + 16], fill=(132, 132, 152, 255))
			d.polygon([(cx - 9, top + 18), (cx + 9, top + 18), (cx + 10, top + 62), (cx + 1, top + 66), (cx + 1, top + 48), (cx - 1, top + 48), (cx - 1, top + 66), (cx - 10, top + 62)], fill=BODY)
			d.ellipse([cx - 3, top + 34, cx + 3, top + 40], fill=FLAME)
		shade(im, seed=11)
		outline(im)
		im.save(OUT / name)
		return
	for i, cx in enumerate([30, 66, 100, 134, 170]):
		_seated(d, cx, 66 + (i % 2) * 4 + slump, 28, bow, col)
	for i, cx in enumerate([48, 100, 152]):
		_seated(d, cx, 92 + slump, 34, bow, col)
	shade(im, seed=12)
	_curtain(d, w, drop + slump, sway)
	outline(im)
	im.save(OUT / name)


def campana():
	im, d = canvas(26, 36)
	d.rectangle([12, 0, 13, 6], fill=METAL)
	d.polygon([(13, 6), (22, 26), (24, 30), (2, 30), (4, 26)], fill=(150, 126, 84, 255))
	d.polygon([(13, 6), (8, 12), (6, 26), (4, 26)], fill=(180, 156, 110, 255))
	d.ellipse([10, 28, 16, 34], fill=(96, 80, 58, 255))
	outline(im)
	im.save(OUT / "campana.png")


def olla():
	im, d = canvas(26, 26)
	d.polygon([(4, 6), (22, 6), (24, 20), (21, 24), (5, 24), (2, 20)], fill=(120, 124, 132, 255))
	d.rectangle([3, 4, 23, 7], fill=(150, 154, 162, 255))
	d.rectangle([0, 10, 2, 13], fill=METAL)
	d.rectangle([23, 10, 25, 13], fill=METAL)
	d.line([(7, 10), (7, 20)], fill=(160, 164, 170, 255))
	outline(im)
	im.save(OUT / "olla.png")


def vidrio():
	im, d = canvas(44, 64)
	d.rectangle([0, 0, 43, 63], fill=WOOD_LO)
	d.rectangle([4, 4, 39, 59], fill=(150, 176, 190, 255))
	d.polygon([(6, 6), (20, 6), (6, 30)], fill=(196, 214, 222, 255))
	d.line([(24, 40), (36, 20)], fill=(196, 214, 222, 255))
	d.rectangle([0, 0, 43, 3], fill=WOOD)
	outline(im)
	im.save(OUT / "vidrio.png")


def nicho(name, lit):
	im, d = canvas(36, 46)
	d.rectangle([0, 0, 35, 45], fill=STONE)
	d.rectangle([1, 1, 34, 3], fill=STONE_HI)
	d.rectangle([5, 6, 30, 45], fill=(40, 38, 42, 255))  # hueco
	d.rectangle([5, 6, 30, 8], fill=(60, 58, 62, 255))
	d.rectangle([8, 36, 27, 40], fill=STONE_LO)  # repisa
	d.rectangle([16, 24, 19, 36], fill=CANDLE)  # vela
	d.line([(17, 22), (17, 24)], fill=(60, 56, 52, 255))  # pabilo
	if lit:
		d.ellipse([15, 17, 20, 25], fill=FLAME)
		d.ellipse([16, 19, 19, 24], fill=(255, 244, 200, 255))
	outline(im)
	im.save(OUT / name)


def mesa_flores():
	w, h = 416, 40
	im, d = canvas(w, h)
	d.rectangle([0, 0, w - 1, h - 9], fill=STONE)
	d.rectangle([0, h - 9, w - 1, h - 1], fill=STONE_LO)
	d.rectangle([1, 1, w - 2, 3], fill=STONE_HI)
	for x in range(34, w, 34):
		d.line([(x, 5), (x, 14)], fill=STONE_LO)  # marcas de lugar (12 lugares, uno cada 34 px)
	outline(im)
	im.save(OUT / "mesa_flores.png")


FLOWER_COLORS = [(236, 232, 220), (232, 208, 120), (214, 158, 170), (176, 160, 206), (164, 196, 214), (222, 140, 120),
	(204, 218, 150), (240, 214, 196), (186, 120, 150), (150, 178, 150), (226, 188, 90), (210, 206, 230)]


def flor(i):
	im, d = canvas(16, 22)
	col = FLOWER_COLORS[i] + (255,)
	d.line([(8, 21), (8, 10)], fill=(88, 120, 84, 255), width=2)
	if i % 3 == 0:  # una flor redonda
		for dx, dy in ((0, -4), (4, 0), (0, 4), (-4, 0), (0, 0)):
			d.ellipse([8 + dx - 3, 7 + dy - 3, 8 + dx + 3, 7 + dy + 3], fill=col)
	elif i % 3 == 1:  # una flor de pocos petalos
		for dx, dy in ((0, -4), (4, 2), (-4, 2)):
			d.ellipse([8 + dx - 3, 6 + dy - 3, 8 + dx + 3, 6 + dy + 3], fill=col)
		d.ellipse([6, 5, 10, 9], fill=(250, 232, 160, 255))
	else:  # una espiga
		for k in range(4):
			d.ellipse([6 + (k % 2) * 2, 2 + k * 3, 10 + (k % 2) * 2, 6 + k * 3], fill=col)
	d.polygon([(8, 16), (13, 13), (10, 17)], fill=(88, 120, 84, 255))  # una hoja
	outline(im)
	im.save(OUT / ("flor_%d.png" % i))


def panel_mudo():
	w, h = 420, 132
	im, d = canvas(w, h)
	d.rectangle([0, 0, w - 1, h - 1], fill=STONE)
	d.rectangle([6, 6, w - 7, h - 7], fill=(100, 98, 100, 255))
	d.rectangle([8, 8, w - 9, h - 9], fill=(90, 88, 92, 255))  # cara grabada, sin nada escrito
	d.rectangle([1, 1, w - 2, 3], fill=STONE_HI)
	outline(im)
	im.save(OUT / "panel_mudo.png")


def puerta_luz():
	im, d = canvas(52, 72)
	d.rectangle([0, 0, 51, 71], fill=STONE)
	d.rectangle([6, 8, 45, 71], fill=(226, 214, 184, 255))  # la luz tenue de afuera
	d.rectangle([6, 8, 45, 24], fill=(214, 202, 172, 255))
	d.rectangle([1, 1, 50, 3], fill=STONE_HI)
	outline(im)
	im.save(OUT / "puerta_luz.png")


def panel_ayuda():
	im, d = canvas(30, 40)
	d.rectangle([13, 24, 16, 39], fill=WOOD_LO)
	d.rectangle([2, 2, 27, 26], fill=(196, 190, 176, 255))
	d.rectangle([4, 4, 25, 24], fill=(214, 208, 194, 255))
	for y in (8, 12, 16, 20):
		d.line([(7, y), (22, y)], fill=(150, 144, 130, 255))
	outline(im)
	im.save(OUT / "panel_ayuda.png")


def fig_cara(i, shoulder, hip, head_r, cloth, skin):
	"""Silueta del reino liberado: la misma figura, pero con cara simple (dos ojos y una sonrisa) y color."""
	w, h = 36, 52
	im, d = canvas(w, h)
	cx = w // 2
	top = 3
	d.ellipse([cx - head_r, top, cx + head_r, top + head_r * 2 + 2], fill=skin)
	neck = top + head_r * 2 + 2
	d.polygon([(cx - shoulder, neck + 2), (cx + shoulder, neck + 2), (cx + hip, 36), (cx + hip - 2, h - 3),
		(cx + 1, h - 3), (cx + 1, 38), (cx - 1, 38), (cx - 1, h - 3), (cx - hip + 2, h - 3), (cx - hip, 36)], fill=cloth + (255,))
	d.rectangle([cx - shoulder - 3, neck + 3, cx - shoulder - 1, 33], fill=skin)
	d.rectangle([cx + shoulder + 1, neck + 3, cx + shoulder + 3, 33], fill=skin)
	ey = top + head_r
	d.point([(cx - 2, ey), (cx + 2, ey)], fill=(40, 30, 28, 255))
	d.line([(cx - 2, ey + 3), (cx - 1, ey + 4), (cx + 1, ey + 4), (cx + 2, ey + 3)], fill=(40, 30, 28, 255))
	hair = (70, 52, 44, 255) if i != 3 else (170, 160, 150, 255)
	if i % 2 == 0:  # pelo largo
		d.rectangle([cx - head_r, top, cx - head_r + 1, top + head_r * 2 + 6], fill=hair)
		d.rectangle([cx + head_r - 1, top, cx + head_r, top + head_r * 2 + 6], fill=hair)
	d.rectangle([cx - head_r + 1, top - 1, cx + head_r - 1, top + 2], fill=hair)
	outline(im)
	im.save(OUT / ("fig_cara_%d.png" % i))


def banco_plaza():
	im, d = canvas(96, 26)
	d.rectangle([0, 3, 95, 12], fill=(176, 130, 84, 255))
	d.rectangle([0, 3, 95, 5], fill=(204, 160, 108, 255))
	d.rectangle([0, 12, 95, 15], fill=(132, 96, 62, 255))
	for x in (6, 44, 86):
		d.rectangle([x, 15, x + 4, 24], fill=(104, 76, 50, 255))
	outline(im)
	im.save(OUT / "banco_plaza.png")


def farol():
	im, d = canvas(20, 64)
	d.rectangle([9, 18, 11, 62], fill=(80, 84, 96, 255))
	d.rectangle([5, 60, 15, 63], fill=(70, 74, 86, 255))
	d.rectangle([4, 4, 16, 18], fill=(60, 64, 76, 255))
	d.rectangle([6, 6, 14, 16], fill=(255, 224, 150, 255))
	d.polygon([(3, 4), (17, 4), (10, 0)], fill=(60, 64, 76, 255))
	outline(im)
	im.save(OUT / "farol.png")


def fuente():
	im, d = canvas(96, 70)
	d.ellipse([2, 34, 93, 66], fill=(116, 122, 132, 255))
	d.ellipse([8, 36, 87, 60], fill=(110, 170, 196, 255))
	d.ellipse([14, 40, 80, 56], fill=(142, 196, 218, 255))
	d.rectangle([42, 14, 54, 44], fill=(150, 154, 162, 255))
	d.ellipse([34, 8, 62, 20], fill=(150, 154, 162, 255))
	d.ellipse([38, 10, 58, 16], fill=(142, 196, 218, 255))
	outline(im)
	im.save(OUT / "fuente.png")


def gen_pacto_memoria():
	pacto_frame("pacto_idle_0.png", sway=0)
	pacto_frame("pacto_idle_1.png", sway=1, slump=1)
	pacto_frame("pacto_attack.png", sway=0, bow=7, drop=52)
	pacto_frame("pacto_tired.png", sway=1, bow=5, drop=60, slump=6, tint=(58, 58, 70, 255))
	pacto_frame("pacto_hurt.png", sway=0, tint=(96, 96, 110, 255))
	pacto_frame("pacto_death.png", standing=True)
	campana()
	olla()
	vidrio()
	nicho("nicho_apagado.png", False)
	nicho("nicho_encendido.png", True)
	mesa_flores()
	for i in range(12):
		flor(i)
	panel_mudo()
	puerta_luz()
	panel_ayuda()
	looks = [(7, 6, 5, (196, 132, 74), WARM_SKIN[0]), (11, 9, 6, (86, 112, 140), WARM_SKIN[1]), (9, 11, 5, (112, 150, 100), WARM_SKIN[2]),
		(7, 7, 4, (190, 96, 90), WARM_SKIN[3]), (10, 8, 6, (150, 120, 160), WARM_SKIN[0]), (8, 6, 5, (218, 182, 96), WARM_SKIN[1])]
	for i, (sh, hp, hr, cloth, skin) in enumerate(looks):
		fig_cara(i, sh, hp, hr, cloth, skin)
	banco_plaza()
	farol()
	fuente()


def main():
	OUT.mkdir(parents=True, exist_ok=True)
	figura_pie("figura_pie_a.png", shoulder=7, hip=6, head_r=5, seed=1)    # delgado
	figura_pie("figura_pie_b.png", shoulder=11, hip=9, head_r=6, seed=2)   # ancho
	figura_pie("figura_pie_c.png", shoulder=9, hip=11, head_r=5, seed=3)   # redondeado, abrigo largo
	figura_sentada("figura_sentada.png", back=False)
	figura_sentada("figura_espalda.png", back=True)
	mesa_larga()
	silla()
	banco()
	escritorio()
	lampara()
	panel_caminos()
	puerta_pintada()
	bolsa()
	for f in (puerta_s5, puerta_cerrada, puerta_adentro, linterna, mochila, nota, vaso, figura_dormida,
			figura_encogida, figura_brazo, interruptor, telefono):
		f()
	gen_pacto_memoria()
	print("silencio: %d piezas en %s" % (len(list(OUT.glob("*.png"))), OUT))


if __name__ == "__main__":
	main()
