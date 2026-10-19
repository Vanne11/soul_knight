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
	print("silencio: %d piezas en %s" % (len(list(OUT.glob("*.png"))), OUT))


if __name__ == "__main__":
	main()
