"""Genera el arte de suelos por reino (assets/sprites/environment/floors/) y sus TileSets.

Uso: python3 tools/gen_floor_art.py [reino ...]
Un atlas PNG por reino (512x384, baldosas de 64x64, 1 pixel de arte = 1 pixel de mundo):
  fila 0:        relleno 0-7
  fila 1:        relleno 8-11 (cols 0-3) + relleno ornamentado 0-3 (cols 4-7)
  fila 2:        borde A  N,E,S,O (cols 0-3) + esquinas NO,NE,SE,SO (cols 4-7)
  fila 3:        borde B  N,E,S,O (cols 0-3) + motivo central 3x3 (cols 5-7, filas 3-5)
Todas las variantes de relleno comparten la misma red de juntas (asi embaldosan sin
costuras); cambian tonos, grano y decoracion (siempre lejos del borde de la baldosa).
Los TileSets (assets/tilesets/floor_<reino>.tres) los escribe este mismo script.
Arte de BAJO contraste: el suelo es fondo, no compite con enemigos, balas ni objetos.
"""
import math
import random
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets/sprites/environment/floors"
TS_OUT = ROOT / "assets/tilesets"
T = 64
COLS, ROWS = 8, 6


# ------------------------------------------------------------------ lienzo
class Cv:
	"""Lienzo RGB + alfa (float). blend mezcla con alfa; sirve tambien para capas sueltas (bordes)."""

	def __init__(self, w, h, rgb=None, a=1.0):
		self.w, self.h = w, h
		self.c = np.zeros((h, w, 3)) if rgb is None else rgb.astype(float).copy()
		self.a = np.full((h, w), float(a))

	def blend(self, mask, col, al=1.0):
		m = mask.astype(float) * al
		col = np.asarray(col, float)
		if col.ndim == 1:
			col = col[None, None, :]
		na = m + self.a * (1 - m)
		num = col * m[..., None] + self.c * (self.a * (1 - m))[..., None]
		self.c = np.where((na > 1e-6)[..., None], num / np.maximum(na, 1e-6)[..., None], self.c)
		self.a = na

	def comp(self, other):
		self.blend(other.a > 0, other.c, other.a)

	def rot(self, k):
		o = Cv(self.w, self.h)
		o.c = np.rot90(self.c, k).copy()
		o.a = np.rot90(self.a, k).copy()
		return o

	def img(self):
		rgba = np.dstack([np.clip(self.c, 0, 255), np.clip(self.a, 0, 1) * 255]).astype(np.uint8)
		return Image.fromarray(rgba, "RGBA")


def M(fn, w=64, h=64):
	im = Image.new("L", (w, h), 0)
	fn(ImageDraw.Draw(im))
	return np.array(im) > 0


def ell(cx, cy, rx, ry=None, w=64, h=64):
	ry = rx if ry is None else ry
	return M(lambda d: d.ellipse([cx - rx, cy - ry, cx + rx, cy + ry], fill=1), w, h)


def poly(pts, w=64, h=64):
	return M(lambda d: d.polygon([(round(x), round(y)) for x, y in pts], fill=1), w, h)


def line(pts, width=1, w=64, h=64):
	return M(lambda d: d.line([(round(x), round(y)) for x, y in pts], fill=1, width=width), w, h)


def rect(x0, y0, x1, y1, w=64, h=64):
	return M(lambda d: d.rectangle([x0, y0, x1, y1], fill=1), w, h)


def shift(m, dy, dx):
	o = np.zeros_like(m)
	H, W = m.shape
	ys0, ys1 = max(dy, 0), H + min(dy, 0)
	xs0, xs1 = max(dx, 0), W + min(dx, 0)
	o[ys0:ys1, xs0:xs1] = m[ys0 - dy:ys1 - dy, xs0 - dx:xs1 - dx]
	return o


def emboss(cv, mask, col, hi=None, lo=None, shadow=0.0, al=1.0):
	"""Relieve: luz arriba-izquierda, sombra abajo-derecha, sombra proyectada opcional."""
	if shadow > 0:
		cv.blend(shift(mask, 1, 1) & ~mask, (10, 8, 14), shadow)
	cv.blend(mask, col, al)
	tl = mask & (~shift(mask, 1, 0) | ~shift(mask, 0, 1))
	br = mask & (~shift(mask, -1, 0) | ~shift(mask, 0, -1)) & ~tl
	if hi is not None:
		cv.blend(tl, hi, al)
	if lo is not None:
		cv.blend(br, lo, al)


def mix(a, b, t):
	return tuple(a[i] * (1 - t) + b[i] * t for i in range(3))


def lighter(c, t):
	return mix(c, (255, 255, 255), t)


def darker(c, t):
	return mix(c, (0, 0, 0), t)


def blob(rng, cx, cy, r, n=4, w=64, h=64):
	m = ell(cx, cy, r, r * rng.uniform(0.7, 1.0), w, h)
	for _ in range(n):
		a = rng.uniform(0, 6.28)
		d = r * rng.uniform(0.4, 0.8)
		m |= ell(cx + math.cos(a) * d, cy + math.sin(a) * d, r * rng.uniform(0.35, 0.65), r * rng.uniform(0.3, 0.6), w, h)
	return m


def fringe(m):
	return m & ~(shift(m, 1, 0) & shift(m, -1, 0) & shift(m, 0, 1) & shift(m, 0, -1))


def checker(w=64, h=64, off=0):
	ys, xs = np.mgrid[0:h, 0:w]
	return ((xs + ys + off) % 2) == 0


def petal_mask(cx, cy, length, width, ang, w=64, h=64, base_off=0.0):
	"""Petalo en forma de lente que arranca en (cx,cy) apuntando hacia ang."""
	pts = []
	n = 14
	for i in range(n + 1):
		t = i / n
		pts.append((base_off + t * length, math.sin(t * math.pi) ** 0.8 * width / 2 * (1 - 0.25 * t)))
	ca, sa = math.cos(ang), math.sin(ang)
	out = [(cx + d * ca - wd * sa, cy + d * sa + wd * ca) for d, wd in pts + [(d, -wd) for d, wd in reversed(pts)]]
	return poly(out, w, h)


def ang_grid(cx, cy, w, h):
	ys, xs = np.mgrid[0:h, 0:w]
	dx, dy = xs - cx, ys - cy
	return np.hypot(dx, dy), np.arctan2(dy, dx)


# ------------------------------------------------------------------ redes de juntas
def vor_layout(seed, gx, gy, jit=0.33):
	rng = np.random.default_rng(seed)
	pts = []
	for i in range(gx):
		for j in range(gy):
			pts.append(((i + 0.5 + rng.uniform(-jit, jit)) * T / gx, (j + 0.5 + rng.uniform(-jit, jit)) * T / gy))
	ys, xs = np.mgrid[0:T, 0:T]
	d = np.zeros((len(pts), T, T))
	for k, (px, py) in enumerate(pts):
		dx = np.abs(xs - px)
		dx = np.minimum(dx, T - dx)
		dy = np.abs(ys - py)
		dy = np.minimum(dy, T - dy)
		d[k] = dx * dx + dy * dy
	order = np.sort(d, axis=0)
	return np.argmin(d, axis=0), np.sqrt(order[0]), np.sqrt(order[1]), len(pts)


def grid_layout(cw, ch, offset=0):
	ys, xs = np.mgrid[0:T, 0:T]
	row = ys // ch
	col = ((xs + (row % 2) * offset) % T) // cw
	return row * 16 + col, None, None, 256


# ------------------------------------------------------------------ base
def base_tile(cfg, rng, reps=1):
	"""Suelo base: tono por celda (compartido), grano (propio de la variante), juntas con relieve."""
	lab, f1, f2, n = cfg["layout"]
	trng = np.random.default_rng(cfg["seed"] + 1)
	tone = trng.uniform(-cfg["tone"], cfg["tone"], n)
	tint = trng.uniform(-1, 1, (n, 3)) * np.array(cfg.get("cell_tint", (0, 0, 0)))
	L = np.tile(lab, (reps, reps))
	img = np.array(cfg["base"], float)[None, None, :] * (1 + tone[L])[..., None] + tint[L]
	if f1 is not None and cfg.get("dome", 0) > 0:
		dome = 1 - np.tile(f1 / np.maximum(f2, 1e-3), (reps, reps))
		img *= (1 + cfg["dome"] * (dome - 0.45))[..., None]
	H = T * reps
	nrng = np.random.default_rng(rng.randrange(1 << 30))
	img *= (1 + nrng.normal(0, cfg["grain"], (H, H)))[..., None]
	sp = nrng.random((H, H))
	img[sp < 0.035] *= 1.06
	img[sp > 0.97] *= 0.94
	dark = (np.roll(L, -1, 1) != L) | (np.roll(L, -1, 0) != L)
	light = ((np.roll(L, 1, 1) != L) | (np.roll(L, 1, 0) != L)) & ~dark
	inner = (np.roll(dark, 1, 1) | np.roll(dark, 1, 0)) & ~dark & ~light
	img[inner] *= 0.95
	img[dark] = img[dark] * (1 - cfg["jd"]) + np.array(cfg["joint"], float) * cfg["jd"]
	img[light] = img[light] * (1 - cfg["jl"]) + np.array(cfg["hi"], float) * cfg["jl"]
	return Cv(H, H, img)


# ------------------------------------------------------------------ decoraciones comunes
def d_stain(cv, rng, col, al=0.28, r=None, margin=14):
	r = r or rng.uniform(7, 12)
	cx = rng.uniform(margin + r * 0.5, T - margin - r * 0.5)
	cy = rng.uniform(margin + r * 0.5, T - margin - r * 0.5)
	m = blob(rng, cx, cy, r, 4)
	fr = fringe(m)
	cv.blend(m & ~fr, col, al)
	cv.blend(fr & checker(), col, al * 0.8)


def d_crack(cv, rng, cfg, n=1, length=(22, 34), margin=7):
	for _ in range(n):
		x = rng.uniform(margin + 6, T - margin - 6)
		y = rng.uniform(margin + 6, T - margin - 6)
		a = rng.uniform(0, 6.28)
		path, branches = [], []
		for s in range(rng.randint(*length)):
			a += rng.uniform(-0.55, 0.55)
			x += math.cos(a)
			y += math.sin(a)
			if not (margin <= x < T - margin and margin <= y < T - margin):
				break
			path.append((int(x), int(y)))
			if s > 6 and rng.random() < 0.07:
				branches.append((x, y, a + rng.choice([-1, 1]) * rng.uniform(0.6, 1.1)))
		for bx, by, ba in branches[:2]:
			for s in range(rng.randint(5, 10)):
				ba += rng.uniform(-0.4, 0.4)
				bx += math.cos(ba)
				by += math.sin(ba)
				if not (margin <= bx < T - margin and margin <= by < T - margin):
					break
				path.append((int(bx), int(by)))
		m = np.zeros((T, T), bool)
		for px, py in path:
			m[py, px] = True
		cv.blend(shift(m, 1, 1) & ~m, cfg["hi"], 0.45)
		cv.blend(m, cfg["crack"], 0.85)


def d_flake(cv, rng, cfg, n=1, margin=12):
	"""Desconchon: parche de sustrato con borde sombreado."""
	for _ in range(n):
		r = rng.uniform(3.2, 5.5)
		cx, cy = rng.uniform(margin, T - margin), rng.uniform(margin, T - margin)
		m = blob(rng, cx, cy, r, 3)
		cv.blend(m, cfg["under"], 0.92)
		cv.blend(m & (~shift(m, 1, 0) | ~shift(m, 0, 1)), darker(cfg["under"], 0.35), 0.9)
		cv.blend(shift(m, 1, 1) & ~m, cfg["hi"], 0.55)
		for _ in range(rng.randint(1, 3)):
			fx, fy = int(cx + rng.uniform(-r - 3, r + 3)), int(cy + rng.uniform(-r - 3, r + 3))
			f = rect(fx, fy, fx + 1, fy)
			cv.blend(f, cfg["under"], 0.8)
			cv.blend(shift(f, 1, 1) & ~f, cfg["crack"], 0.4)


def pebbles(cv, rng, col, n=3, margin=8):
	for _ in range(n):
		cx, cy = rng.uniform(margin, T - margin), rng.uniform(margin, T - margin)
		r = rng.choice([1.2, 1.6, 2.1])
		emboss(cv, ell(cx, cy, r, r * 0.8), col, lighter(col, 0.25), darker(col, 0.3), 0.3)


def flower(cv, cx, cy, r, petal, center, n=5):
	for i in range(n):
		a = i * 6.2832 / n - 1.57
		emboss(cv, petal_mask(cx, cy, r, r * 0.9, a, cv.w, cv.h), petal, lighter(petal, 0.3), darker(petal, 0.25), 0.2)
	emboss(cv, ell(cx, cy, max(1.2, r * 0.3), None, cv.w, cv.h), center, lighter(center, 0.3), darker(center, 0.3))


def mushroom(cv, x, y, s, cap, spot):
	st = (206, 196, 170)
	emboss(cv, rect(x - max(1, s // 3), y, x + max(1, s // 3), y + s, cv.w, cv.h), st, lighter(st, 0.3), darker(st, 0.25), 0.25)
	yy = np.mgrid[0:cv.h, 0:cv.w][0]
	emboss(cv, ell(x, y, s, s * 0.7, cv.w, cv.h) & (yy <= y), cap, lighter(cap, 0.25), darker(cap, 0.3), 0.25)
	for dx in (-s // 2, 0, s // 2):
		cv.blend(rect(x + dx, y - s // 2, x + dx, y - s // 2, cv.w, cv.h), spot, 0.9)


def vein(cv, rng, col, al=0.35, margin=6, width=1):
	x, y = rng.uniform(margin, T - margin), rng.uniform(margin, T - margin)
	a = rng.uniform(0, 6.28)
	m = np.zeros((T, T), bool)
	for _ in range(rng.randint(22, 40)):
		a += rng.uniform(-0.4, 0.4)
		x += math.cos(a)
		y += math.sin(a)
		if not (margin <= x < T - margin and margin <= y < T - margin):
			break
		m[int(y), int(x)] = True
	cv.blend(m, col, al)


# ================================================================== SELVA (neutral)
def selva_cfg():
	return dict(
		seed=11, layout=vor_layout(11, 3, 3, 0.3), base=(164, 134, 96), tone=0.045, grain=0.03,
		joint=(112, 88, 62), jd=0.6, hi=(192, 164, 124), jl=0.4, crack=(88, 66, 46), under=(128, 102, 74), dome=0.0,
	)


MOSS = (96, 130, 72)
ROOT = (100, 72, 48)


def selva_moss(cv, rng, cx=None, cy=None, r=None):
	r = r or rng.uniform(8, 12)
	cx = cx if cx is not None else rng.uniform(18, 46)
	cy = cy if cy is not None else rng.uniform(18, 46)
	m = blob(rng, cx, cy, r, 5, cv.w, cv.h)
	fr = fringe(m)
	cv.blend(m & ~fr, MOSS, 0.78)
	cv.blend(fr & checker(cv.w, cv.h), MOSS, 0.6)
	ys, xs = np.mgrid[0:cv.h, 0:cv.w]
	spots = m & (((xs * 7 + ys * 13) % 11) == 0)
	cv.blend(spots, lighter(MOSS, 0.3), 0.7)
	cv.blend(shift(m, 1, 1) & ~m, (40, 34, 24), 0.25)


def selva_root(cv, rng, y0=None, thick=3, x_from=6, x_to=57, fork=True):
	y0 = y0 if y0 is not None else rng.uniform(18, 46)
	ph = rng.uniform(0, 6.28)
	amp = rng.uniform(3, 6)
	pts = [(x, y0 + amp * math.sin(x / 9.0 + ph)) for x in range(x_from, x_to + 1)]
	m = line(pts, thick, cv.w, cv.h)
	if fork:
		fx = rng.randint(20, 40)
		fy = pts[fx - x_from][1]
		d = rng.choice([-1, 1])
		m |= line([(fx, fy), (fx + 5, fy + d * 7), (fx + 6, fy + d * 13)], max(1, thick - 1), cv.w, cv.h)
	emboss(cv, m, ROOT, lighter(ROOT, 0.28), darker(ROOT, 0.3), 0.3)


def selva_rizo(cv, rng):
	"""Gag raro: un rizo de pelo suelto (la Selva es publica, a fin de cuentas)."""
	cx, cy = rng.uniform(22, 42), rng.uniform(22, 42)
	pts = []
	for i in range(60):
		t = i / 60 * 4.2 * math.pi
		r = 1.2 + t * 0.95
		pts.append((cx + r * math.cos(t), cy + r * math.sin(t) * 0.8))
	m = line(pts, 1, cv.w, cv.h)
	cv.blend(shift(m, 1, 1) & ~m, (40, 30, 24), 0.3)
	cv.blend(m, (66, 46, 34), 0.95)


def selva_tufts(cv, rng, n=3):
	for _ in range(n):
		x, y = rng.randint(10, 52), rng.randint(14, 54)
		for dx, h in ((-1, 3), (0, 4), (1, 3)):
			m = line([(x + dx, y), (x + dx * 2, y - h)], 1, cv.w, cv.h)
			cv.blend(m, lighter(MOSS, 0.12), 0.85)


def selva_fill(i, cv, rng, cfg):
	if i in (0, 3):
		pebbles(cv, rng, (150, 138, 118), rng.randint(1, 3))
	if i in (1, 4):
		selva_tufts(cv, rng, 2)
	if i == 5:
		selva_moss(cv, rng)
	elif i == 6:
		selva_root(cv, rng)
	elif i == 7:
		d_crack(cv, rng, cfg, 1)
	elif i == 8:
		d_stain(cv, rng, (58, 44, 32), 0.3)
	elif i == 9:
		d_flake(cv, rng, cfg, 2)
		pebbles(cv, rng, (150, 138, 118), 2)
	elif i == 10:
		selva_moss(cv, rng, r=7)
		d_crack(cv, rng, cfg, 1, (14, 22))
	elif i == 11:
		selva_rizo(cv, rng)


def selva_ornate(i, cv, rng, cfg):
	if i == 0:
		mushroom(cv, 24, 32, 4, (158, 92, 84), (236, 222, 200))
		mushroom(cv, 38, 40, 3, (158, 92, 84), (236, 222, 200))
	elif i == 1:
		selva_moss(cv, rng, 32, 32, 12)
		flower(cv, 32, 32, 4, (230, 214, 150), (200, 150, 70), 5)
	elif i == 2:
		selva_moss(cv, rng, 32, 32, 10)
		for k in range(6):
			a = k * 1.047
			mushroom(cv, int(32 + math.cos(a) * 14), int(34 + math.sin(a) * 11), 2, (158, 92, 84), (236, 222, 200))
	else:
		selva_root(cv, rng, 32, 3, 8, 55, False)
		flower(cv, 20, 24, 3, (216, 190, 220), (210, 160, 80), 5)
		flower(cv, 44, 42, 3, (230, 214, 150), (200, 150, 70), 5)


def selva_band(cv, b):
	"""Borde N: raiz gruesa ondulada pegada al muro, musgo y raicillas colgando."""
	rng = random.Random(77)
	ys = np.arange(T)
	cv.blend(rect(0, 0, 63, 2), (40, 30, 22), 0.55)
	cv.blend(rect(0, 3, 63, 5), (40, 30, 22), 0.25)
	yc = lambda x: 7 + 2.4 * math.sin(2 * math.pi * x / 64 + 0.6)
	# musgo bajo la raiz
	for x0, w, h in ((6, 12, 4), (30, 14, 5), (50, 8, 3)):
		m = blob(rng, x0 + w / 2, 12, w / 2, 3, cv.w, cv.h) & (np.mgrid[0:cv.h, 0:cv.w][0] >= 8)
		cv.blend(m & ~fringe(m), MOSS, 0.72)
		cv.blend(fringe(m) & checker(), MOSS, 0.55)
	# raicillas
	for x0, ln in ((10, 7), (23, 10), (41, 6), (55, 9)):
		y0 = yc(x0) + 2
		m = line([(x0, y0), (x0 + 1, y0 + ln * 0.5), (x0 - 1, y0 + ln)], 1, cv.w, cv.h)
		cv.blend(m, darker(ROOT, 0.1), 0.85)
	main = line([(x, yc(x)) for x in range(0, 64)], 4, cv.w, cv.h)
	emboss(cv, main, ROOT, lighter(ROOT, 0.28), darker(ROOT, 0.3), 0.35)
	if b == 1:
		flower(cv, 17, 17, 3, (230, 214, 150), (200, 150, 70), 5)
		mushroom(cv, 44, 15, 3, (158, 92, 84), (236, 222, 200))
		flower(cv, 54, 18, 2, (216, 190, 220), (210, 160, 80), 5)


def selva_corner(cv, b):
	rng = random.Random(5)
	m = ell(10, 10, 9, 8, cv.w, cv.h)
	emboss(cv, m, ROOT, lighter(ROOT, 0.28), darker(ROOT, 0.3), 0.35)
	for a in (0.3, 0.9, 1.2):
		s = line([(10, 10), (10 + math.cos(a) * 16, 10 + math.sin(a) * 16)], 3, cv.w, cv.h)
		emboss(cv, s & ~m, ROOT, lighter(ROOT, 0.28), darker(ROOT, 0.3), 0.3)
	mm = blob(rng, 15, 17, 5, 3, cv.w, cv.h) & ~m
	cv.blend(mm, MOSS, 0.75)
	cv.blend(ell(9, 8, 3, 2, cv.w, cv.h), darker(ROOT, 0.35), 0.8)  # hueco del nudo


def selva_motif(cv, rng):
	"""Claro de musgo con corro de setas y una flor en el centro."""
	W = cv.w
	r, th = ang_grid(96, 96, W, W)
	edge = 70 + 6 * np.sin(3 * th) + 4 * np.sin(5 * th + 1.0)
	inside = r < edge
	fr = fringe(inside)
	cv.blend(inside & ~fr, MOSS, 0.55)
	cv.blend(fr & checker(W, W), MOSS, 0.4)
	cv.blend(inside & (r < edge - 12), darker(MOSS, 0.1), 0.35)
	ys, xs = np.mgrid[0:W, 0:W]
	cv.blend(inside & (((xs * 7 + ys * 13) % 13) == 0), lighter(MOSS, 0.3), 0.6)
	for k in range(8):
		a = k * 0.785 + 0.2
		mushroom(cv, int(96 + math.cos(a) * 46), int(100 + math.sin(a) * 42), 4, (158, 92, 84), (236, 222, 200))
	pebs = [(96 + math.cos(k * 0.52) * 60, 96 + math.sin(k * 0.52) * 56) for k in range(12)]
	for px, py in pebs:
		emboss(cv, ell(px, py, 2, 1.6, W, W), (150, 138, 118), lighter((150, 138, 118), 0.25), darker((150, 138, 118), 0.3), 0.3)
	for k in range(5):
		a = k * 1.257 - 1.57
		emboss(cv, petal_mask(96, 96, 14, 12, a, W, W), (232, 218, 160), (250, 240, 200), (190, 170, 110), 0.25)
	emboss(cv, ell(96, 96, 5, 5, W, W), (206, 150, 70), (240, 200, 120), (150, 100, 40), 0.2)


# ================================================================== PENELANDIA (pene)
LAPIS = (84, 112, 158)
TERRA = (176, 112, 84)
GOLD = (196, 166, 96)
CREAM = (214, 210, 198)


def pene_cfg():
	return dict(
		seed=21, layout=grid_layout(32, 32), base=(178, 178, 186), tone=0.03, grain=0.018,
		cell_tint=(5, 3, -4), joint=(132, 134, 146), jd=0.75, hi=(226, 226, 230), jl=0.55,
		crack=(108, 110, 124), under=(158, 160, 172), dome=0.0,
	)


def pene_fill(i, cv, rng, cfg):
	if i < 5:
		for _ in range(rng.randint(1, 2)):
			vein(cv, rng, (150, 156, 176), 0.28)
	if i == 5:
		d_stain(cv, rng, (120, 124, 140), 0.22)
		vein(cv, rng, (150, 156, 176), 0.28)
	elif i == 6:
		d_crack(cv, rng, cfg, 1)
	elif i == 7:
		d_flake(cv, rng, cfg, 2)
	elif i == 8:
		d_crack(cv, rng, cfg, 1, (14, 24))
		vein(cv, rng, (150, 156, 176), 0.3)
		d_stain(cv, rng, (120, 124, 140), 0.18, 7)
	elif i == 9:  # ramita de laurel caida
		x, y = rng.uniform(22, 38), rng.uniform(22, 38)
		a = rng.uniform(0, 6.28)
		cv.blend(line([(x, y), (x + math.cos(a) * 14, y + math.sin(a) * 14)], 1), (90, 100, 70), 0.9)
		for k in range(5):
			bx, by = x + math.cos(a) * (3 + k * 2.6), y + math.sin(a) * (3 + k * 2.6)
			for s in (-1, 1):
				emboss(cv, petal_mask(bx, by, 5, 2.6, a + s * 0.9), (110, 138, 92), (150, 176, 128), (74, 98, 62), 0.2)
	elif i == 10:  # teselas sueltas
		for _ in range(rng.randint(3, 5)):
			x, y = rng.randint(14, 48), rng.randint(14, 48)
			c = rng.choice([LAPIS, TERRA, CREAM])
			emboss(cv, rect(x, y, x + 2, y + 2), c, lighter(c, 0.3), darker(c, 0.3), 0.3)
	elif i == 11:  # hoja de parra caida (guino al jefe del Palacio)
		x, y = rng.uniform(26, 38), rng.uniform(26, 38)
		a = rng.uniform(0, 6.28)
		emboss(cv, petal_mask(x, y, 12, 11, a), (116, 148, 96), (158, 188, 134), (76, 104, 66), 0.25)
		cv.blend(line([(x, y), (x + math.cos(a) * 11, y + math.sin(a) * 11)], 1), (76, 104, 66), 0.8)


def rosette(cv, cx, cy, r, c1=GOLD, c2=LAPIS, n=8):
	emboss(cv, ell(cx, cy, r, r, cv.w, cv.h), CREAM, lighter(CREAM, 0.3), darker(CREAM, 0.25), 0.3)
	for k in range(n):
		a = k * 6.2832 / n
		emboss(cv, petal_mask(cx, cy, r * 0.9, r * 0.45, a, cv.w, cv.h), c2 if k % 2 else c1, None, None, 0.0, 0.9)
	emboss(cv, ell(cx, cy, max(1.5, r * 0.28), None, cv.w, cv.h), c1, lighter(c1, 0.3), darker(c1, 0.3))


def pene_ornate(i, cv, rng, cfg):
	if i == 0:
		rosette(cv, 32, 32, 9)
	elif i == 1:
		d = poly([(32, 18), (46, 32), (32, 46), (18, 32)])
		emboss(cv, d, LAPIS, lighter(LAPIS, 0.3), darker(LAPIS, 0.3), 0.3, 0.9)
		emboss(cv, poly([(32, 25), (39, 32), (32, 39), (25, 32)]), GOLD, lighter(GOLD, 0.3), darker(GOLD, 0.3), 0, 0.9)
	elif i == 2:
		pts = []
		for k in range(16):
			a = k * 6.2832 / 16
			emboss(cv, petal_mask(32 + math.cos(a) * 11, 32 + math.sin(a) * 11, 6, 3.5, a + 1.5), (116, 148, 96), (158, 188, 134), (76, 104, 66), 0.2)
		rosette(cv, 32, 32, 5, GOLD, TERRA, 6)
	else:
		fr = rect(20, 20, 43, 43)
		emboss(cv, fr & ~rect(23, 23, 40, 40), LAPIS, lighter(LAPIS, 0.3), darker(LAPIS, 0.3), 0.3, 0.9)
		emboss(cv, rect(28, 28, 35, 35), TERRA, lighter(TERRA, 0.3), darker(TERRA, 0.3), 0.3, 0.9)


def meander(cv, y_top, col=LAPIS, unit=16, h=10):
	"""Greca griega continua, periodo `unit` (divide a 64)."""
	m = np.zeros((cv.h, cv.w), bool)
	m |= rect(0, y_top + h - 1, 63, y_top + h - 1, cv.w, cv.h)
	for ux in range(0, 64, unit):
		p = [(ux, y_top + h - 1), (ux, y_top), (ux + 11, y_top), (ux + 11, y_top + 6), (ux + 5, y_top + 6), (ux + 5, y_top + 3), (ux + 8, y_top + 3)]
		m |= line(p, 2, cv.w, cv.h)
	emboss(cv, m, col, lighter(col, 0.3), darker(col, 0.3), 0.25, 0.92)


def pene_band(cv, b):
	cv.blend(rect(0, 0, 63, 15), (160, 162, 176), 0.9)
	cv.blend(rect(0, 0, 63, 2), (96, 98, 112), 0.7)
	cv.blend(rect(0, 3, 63, 4), (96, 98, 112), 0.25)
	cv.blend(rect(0, 14, 63, 14), (118, 120, 134), 0.9)
	cv.blend(rect(0, 15, 63, 15), (222, 222, 228), 0.7)
	meander(cv, 4, LAPIS if b == 0 else TERRA)
	if b == 1:
		for x in (6, 22, 38, 54):
			cv.blend(rect(x, 15, x + 1, 15), GOLD, 0.0)


def pene_corner(cv, b):
	emboss(cv, rect(0, 0, 17, 17, cv.w, cv.h), (168, 170, 186), lighter((168, 170, 186), 0.3), darker((168, 170, 186), 0.3), 0.35)
	emboss(cv, rect(3, 3, 14, 14, cv.w, cv.h), LAPIS, darker(LAPIS, 0.3), lighter(LAPIS, 0.3), 0, 0.92)
	rosette(cv, 8, 8, 4)


def pene_motif(cv, rng):
	W = cv.w
	r, th = ang_grid(96, 96, W, W)
	ys, xs = np.mgrid[0:W, 0:W]
	rim = r < 84

	def tesserae(mask, cols, size=4, al=0.8, pat=None):
		ti, tj = xs // size, ys // size
		sel = ((ti * 7 + tj * 13) % len(cols))
		out = np.zeros((W, W, 3))
		for k, c in enumerate(cols):
			out[sel == k] = c
		cv.blend(mask, out, al)
		grout = mask & (((xs % size) == size - 1) | ((ys % size) == size - 1))
		cv.blend(grout, (214, 212, 206), 0.45)

	cv.blend(ell(97, 98, 82, 82, W, W), (20, 20, 30), 0.12)
	sector = ((th + math.pi) / (2 * math.pi) * 28).astype(int)
	ring1 = (r >= 72) & (r < 82)
	ring1c = np.where((sector % 2 == 0)[..., None], np.array(TERRA), np.array(CREAM))
	cv.blend(ring1, ring1c, 0.6)
	cv.blend(ring1 & (((xs % 4) == 3) | ((ys % 4) == 3)), (214, 212, 206), 0.4)
	tesserae((r >= 62) & (r < 72), [LAPIS, darker(LAPIS, 0.12)], 4, 0.65)
	tesserae(r < 62, [CREAM, lighter(CREAM, 0.06), darker(CREAM, 0.05)], 4, 0.75)
	# greca interior circular (anillo de rombos) y sol
	ring2 = (r >= 40) & (r < 46)
	sec2 = ((th + math.pi) / (2 * math.pi) * 16).astype(int)
	cv.blend(ring2, np.where((sec2 % 2 == 0)[..., None], np.array(LAPIS), np.array(TERRA)), 0.85)
	for k in range(16):
		a = k * 6.2832 / 16
		emboss(cv, petal_mask(96, 96, 32, 7, a, W, W, 8), GOLD, lighter(GOLD, 0.3), darker(GOLD, 0.3), 0.2, 0.9)
	emboss(cv, ell(96, 96, 11, 11, W, W), GOLD, lighter(GOLD, 0.35), darker(GOLD, 0.35), 0.3)
	emboss(cv, ell(96, 96, 5, 5, W, W), TERRA, lighter(TERRA, 0.3), darker(TERRA, 0.3))
	cv.blend(fringe(ell(97, 98, 83, 83, W, W)), darker((190, 190, 194), 0.35), 0.5)


# ================================================================== VULVANIA (vulva)
ROSA = (214, 120, 146)


def vulva_cfg():
	return dict(
		seed=31, layout=vor_layout(31, 3, 3, 0.36), base=(204, 148, 160), tone=0.035, grain=0.022,
		joint=(134, 84, 104), jd=0.55, hi=(232, 178, 186), jl=0.4, crack=(106, 56, 78), under=(156, 94, 114), dome=0.2,
		cell_tint=(4, -2, 2),
	)


def petals_scatter(cv, rng, n, col=ROSA):
	for _ in range(n):
		x, y = rng.uniform(14, 50), rng.uniform(14, 50)
		a = rng.uniform(0, 6.28)
		c = mix(col, (240, 170, 190), rng.uniform(0, 0.4))
		emboss(cv, petal_mask(x, y, rng.uniform(7, 10), rng.uniform(4, 5.5), a), c, lighter(c, 0.3), darker(c, 0.3), 0.3, 0.92)
		cv.blend(line([(x, y), (x + math.cos(a) * 6, y + math.sin(a) * 6)], 1), darker(c, 0.22), 0.5)


def beso(cv, rng):
	"""Gag raro: marca de pintalabios."""
	cx, cy = rng.uniform(26, 38), rng.uniform(26, 38)
	lab = (172, 56, 92)
	up = poly([(cx - 8, cy), (cx - 4, cy - 4), (cx, cy - 2), (cx + 4, cy - 4), (cx + 8, cy), (cx, cy + 1)])
	dn = poly([(cx - 8, cy), (cx, cy + 1), (cx + 8, cy), (cx + 4, cy + 5), (cx - 4, cy + 5)])
	emboss(cv, up | dn, lab, lighter(lab, 0.25), darker(lab, 0.3), 0.15, 0.7)
	cv.blend(line([(cx - 7, cy), (cx, cy + 1), (cx + 7, cy)], 1), darker(lab, 0.4), 0.8)


def vulva_fill(i, cv, rng, cfg):
	if i < 5 and rng.random() < 0.5:
		vein(cv, rng, (150, 84, 108), 0.22)
	if i == 5:
		petals_scatter(cv, rng, rng.randint(2, 4))
	elif i == 6:
		d_crack(cv, rng, cfg, 1)
	elif i == 7:
		d_stain(cv, rng, (110, 50, 80), 0.26)
	elif i == 8:
		d_flake(cv, rng, cfg, 2)
	elif i == 9:
		for _ in range(rng.randint(3, 5)):
			x, y = rng.randint(14, 50), rng.randint(14, 50)
			emboss(cv, ell(x, y, 1.8, 1.8), (232, 214, 220), (255, 250, 252), (170, 140, 156), 0.3)
	elif i == 10:
		petals_scatter(cv, rng, 2)
		d_crack(cv, rng, cfg, 1, (14, 22))
	elif i == 11:
		beso(cv, rng)


def vulva_ornate(i, cv, rng, cfg):
	if i == 0:
		flower(cv, 32, 32, 9, ROSA, (240, 214, 150), 5)
	elif i == 1:
		emboss(cv, ell(32, 32, 5, 5), (236, 220, 226), (255, 252, 252), (176, 146, 160), 0.35)
		petals_scatter(cv, rng, 3)
	elif i == 2:
		hp = poly([(32, 44), (20, 32), (22, 24), (28, 22), (32, 27), (36, 22), (42, 24), (44, 32)])
		emboss(cv, hp, (222, 110, 146), lighter((222, 110, 146), 0.3), darker((222, 110, 146), 0.3), 0.3, 0.85)
	else:
		for k in range(8):
			emboss(cv, petal_mask(32, 32, 14, 8, k * 0.785), ROSA, lighter(ROSA, 0.3), darker(ROSA, 0.3), 0.2, 0.85)
		emboss(cv, ell(32, 32, 4, 4), (240, 214, 150), lighter((240, 214, 150), 0.3), darker((240, 214, 150), 0.3))


def vulva_band(cv, b):
	cv.blend(rect(0, 0, 63, 3), (96, 44, 70), 0.55)
	cv.blend(rect(0, 4, 63, 5), (96, 44, 70), 0.22)
	# petalos en abanico pegados al muro (periodo 16)
	for k in range(4):
		cx = 8 + k * 16
		for s, (dx, ln, ang) in enumerate(((-6, 9, 1.95), (6, 9, 1.19), (0, 12, 1.57))):
			col = ROSA if s == 2 else mix(ROSA, (190, 100, 130), 0.4)
			emboss(cv, petal_mask(cx + dx, 3, ln, 11 if s == 2 else 9, ang, cv.w, cv.h), col, lighter(col, 0.3), darker(col, 0.3), 0.3, 0.92)
	if b == 1:
		for k in range(4):
			emboss(cv, ell(16 + k * 16 - 0.5, 8, 1.8, 1.8, cv.w, cv.h), (236, 220, 226), (255, 252, 252), (176, 146, 160), 0.25)


def vulva_corner(cv, b):
	for k in range(6):
		a = 0.15 + k * 0.25
		emboss(cv, petal_mask(2, 2, 18, 8, a, cv.w, cv.h), mix(ROSA, (190, 100, 130), 0.3 + 0.1 * (k % 2)), (240, 170, 190), (160, 80, 110), 0.3, 0.92)
	emboss(cv, ell(5, 5, 4, 4, cv.w, cv.h), (240, 214, 150), lighter((240, 214, 150), 0.3), darker((240, 214, 150), 0.3), 0.3)


def vulva_motif(cv, rng):
	W = cv.w
	cv.blend(ell(98, 99, 80, 80, W, W), (60, 20, 40), 0.1)
	for k in range(8):
		a = k * 0.785 + 0.39
		c = mix(ROSA, (176, 86, 118), 0.35)
		emboss(cv, petal_mask(96, 96, 78, 36, a, W, W, 6), c, lighter(c, 0.28), darker(c, 0.28), 0.3, 0.85)
		cv.blend(line([(96 + math.cos(a) * 20, 96 + math.sin(a) * 20), (96 + math.cos(a) * 62, 96 + math.sin(a) * 62)], 1, W, W), darker(c, 0.2), 0.45)
	for k in range(8):
		a = k * 0.785
		c = mix(ROSA, (244, 170, 190), 0.3)
		emboss(cv, petal_mask(96, 96, 54, 26, a, W, W, 4), c, lighter(c, 0.28), darker(c, 0.28), 0.3, 0.85)
		cv.blend(line([(96 + math.cos(a) * 14, 96 + math.sin(a) * 14), (96 + math.cos(a) * 44, 96 + math.sin(a) * 44)], 1, W, W), darker(c, 0.2), 0.4)
	emboss(cv, ell(96, 96, 17, 17, W, W), (240, 214, 150), lighter((240, 214, 150), 0.3), darker((240, 214, 150), 0.3), 0.3, 0.9)
	for k in range(9):
		a = k * 0.698
		cv.blend(ell(96 + math.cos(a) * 9, 96 + math.sin(a) * 9, 1.4, 1.4, W, W), (176, 120, 70), 0.9)
	emboss(cv, ell(96, 96, 4, 4, W, W), (236, 220, 226), (255, 252, 252), (176, 146, 160))


# ================================================================== PERINEO (mixto)
YEL = (206, 172, 66)


def mixto_cfg():
	return dict(
		seed=41, layout=vor_layout(41, 4, 4, 0.3), base=(148, 140, 134), tone=0.035, grain=0.022,
		joint=(96, 88, 86), jd=0.55, hi=(176, 168, 160), jl=0.3, crack=(70, 62, 62), under=(112, 104, 100), dome=0.22,
		cell_tint=(-5, 0, 6),
	)


def tally(cv, rng):
	"""Marcas de recuento a tiza (el Aduanero lleva la cuenta)."""
	x, y = rng.randint(20, 34), rng.randint(22, 40)
	for k in range(4):
		cv.blend(line([(x + k * 3, y), (x + k * 3, y + 7)], 1), (226, 224, 214), 0.6)
	cv.blend(line([(x - 2, y + 6), (x + 11, y + 1)], 1), (226, 224, 214), 0.6)


def pasaporte(cv, rng):
	"""Gag raro: un pasaporte extraviado."""
	x, y = rng.randint(22, 34), rng.randint(24, 36)
	emboss(cv, rect(x, y, x + 9, y + 12), (66, 84, 134), (104, 124, 176), (40, 52, 88), 0.35, 0.92)
	cv.blend(ell(x + 4.5, y + 5, 2.5, 2.5), (214, 186, 100), 0.8)
	cv.blend(rect(x + 2, y + 9, x + 7, y + 9), (214, 186, 100), 0.7)


def mixto_fill(i, cv, rng, cfg):
	if i < 5 and rng.random() < 0.5:
		pebbles(cv, rng, (130, 122, 114), 2)
	if i == 5:
		d_stain(cv, rng, (40, 36, 44), 0.3)
	elif i == 6:
		d_crack(cv, rng, cfg, 1)
	elif i == 7:
		d_flake(cv, rng, cfg, 2)
	elif i == 8:
		for _ in range(3):
			x, y = rng.randint(12, 52), rng.randint(12, 52)
			for dx in (-1, 0, 1):
				cv.blend(line([(x + dx, y), (x + dx * 2, y - rng.randint(2, 4))], 1), (112, 140, 84), 0.85)
	elif i == 9:
		tally(cv, rng)
	elif i == 10:
		d_crack(cv, rng, cfg, 1, (14, 22))
		d_stain(cv, rng, (40, 36, 44), 0.2, 7)
	elif i == 11:
		pasaporte(cv, rng)


def sello_circ(cv, cx, cy, r, col, al):
	ring = ell(cx, cy, r, r, cv.w, cv.h) & ~ell(cx, cy, r - 2, r - 2, cv.w, cv.h)
	cv.blend(ring, col, al)
	d = r * 0.5
	cv.blend(line([(cx - d, cy - d), (cx + d, cy + d)], 2, cv.w, cv.h), col, al)
	cv.blend(line([(cx - d, cy + d), (cx + d, cy - d)], 2, cv.w, cv.h), col, al)


def mixto_ornate(i, cv, rng, cfg):
	if i == 0:
		sello_circ(cv, 32, 32, 10, YEL, 0.55)
	elif i == 1:
		cv.blend(ell(32, 32, 10, 10), (206, 172, 66), 0.4)
		pts = [(32 + (9 if k % 2 == 0 else 4) * math.cos(k * 0.628 - 1.57), 32 + (9 if k % 2 == 0 else 4) * math.sin(k * 0.628 - 1.57)) for k in range(10)]
		emboss(cv, poly(pts), YEL, lighter(YEL, 0.3), darker(YEL, 0.3), 0.3, 0.85)
	elif i == 2:
		tally(cv, rng)
		cv.blend(rect(14, 44, 49, 45), YEL, 0.35)
	else:
		for k in range(4):
			cv.blend(poly([(14 + k * 9, 44), (20 + k * 9, 44), (14 + k * 9 + 12, 50), (8 + k * 9 + 12, 50)]), YEL, 0.5)


def hazard(cv, x0, y0, x1, y1):
	m = rect(x0, y0, x1, y1, cv.w, cv.h)
	ys, xs = np.mgrid[0:cv.h, 0:cv.w]
	stripe = (((xs + ys) // 4) % 2) == 0
	emboss(cv, m, (62, 58, 60), lighter((62, 58, 60), 0.15), darker((62, 58, 60), 0.2), 0.25, 0.9)
	cv.blend(m & stripe, YEL, 0.75)


def mixto_band(cv, b):
	cv.blend(rect(0, 0, 63, 2), (40, 36, 40), 0.55)
	# bordillo: dos bloques largos
	for x0 in (0, 32):
		emboss(cv, rect(x0, 3, x0 + 31, 14, cv.w, cv.h), (172, 164, 156), (200, 192, 184), (110, 102, 98), 0.0, 0.95)
		cv.blend(rect(x0 + 31, 3, x0 + 31, 14, cv.w, cv.h), (96, 88, 86), 0.9)
		cv.blend(rect(x0, 3, x0, 14, cv.w, cv.h), (206, 198, 190), 0.6)
	# linea fronteriza discontinua (periodo 16)
	for x0 in range(0, 64, 16):
		cv.blend(rect(x0 + 2, 7, x0 + 11, 9, cv.w, cv.h), YEL, 0.78)
		cv.blend(rect(x0 + 2, 10, x0 + 11, 10, cv.w, cv.h), darker(YEL, 0.4), 0.5)
	if b == 1:
		hazard(cv, 0, 12, 63, 14)


def mixto_corner(cv, b):
	hazard(cv, 0, 0, 15, 15)
	cv.blend(rect(4, 4, 11, 11, cv.w, cv.h), (62, 58, 60), 0.9)
	sello_circ(cv, 8, 8, 3, YEL, 0.8)


def mixto_motif(cv, rng):
	"""Raya fronteriza: mitad azulada, mitad rosada, doble linea amarilla y sello de aduana."""
	W = cv.w
	ys, xs = np.mgrid[0:W, 0:W]
	d = np.minimum(np.minimum(xs, W - 1 - xs), np.minimum(ys, W - 1 - ys))
	fade = np.clip((d - 6) / 26.0, 0, 1)
	left = xs < 96
	cv.blend(left, (90, 120, 190), 0.20 * fade)
	cv.blend(~left, (210, 110, 150), 0.20 * fade)
	for x0 in (86, 102):
		m = rect(x0, 14, x0 + 3, 177, W, W)
		cv.blend(m & ((ys // 12) % 4 != 3), YEL, 0.7 * np.clip((d - 8) / 10.0, 0, 1))
	emboss(cv, ell(96, 96, 30, 30, W, W), (66, 62, 70), lighter((66, 62, 70), 0.25), darker((66, 62, 70), 0.25), 0.3, 0.55)
	ring = ell(96, 96, 26, 26, W, W) & ~ell(96, 96, 23, 23, W, W)
	cv.blend(ring, YEL, 0.8)
	pts = [(96 + (17 if k % 2 == 0 else 7) * math.cos(k * 0.628 - 1.57), 96 + (17 if k % 2 == 0 else 7) * math.sin(k * 0.628 - 1.57)) for k in range(10)]
	emboss(cv, poly(pts, W, W), YEL, lighter(YEL, 0.3), darker(YEL, 0.3), 0.2, 0.85)
	for ty in (24, 160):
		for k in range(3):
			cv.blend(rect(90 + k * 6, ty, 91 + k * 6, ty + 8, W, W), (226, 224, 214), 0.5)


# ================================================================== LA PROSTATA (prostata)
# Sala de espera: linoleo en cuadros nuez / rosa lechoso / gris, chicles, revistas y turnos.
NUEZ = (142, 108, 80)
LECHE = (222, 192, 190)
SALA = (150, 150, 154)


def prostata_cfg():
	return dict(
		seed=61, layout=grid_layout(32, 32), base=(178, 160, 156), tone=0.03, grain=0.02,
		joint=(112, 104, 104), jd=0.5, hi=(206, 196, 192), jl=0.3, crack=(84, 74, 74), under=(138, 126, 124), dome=0.0,
		cell_tint=(14, 4, 0),
	)


def revista(cv, rng, col):
	x, y = rng.randint(18, 36), rng.randint(20, 38)
	emboss(cv, rect(x, y, x + 11, y + 14), col, lighter(col, 0.3), darker(col, 0.3), 0.3, 0.92)
	cv.blend(rect(x + 2, y + 2, x + 9, y + 4), (240, 236, 226), 0.8)
	for k in range(3):
		cv.blend(rect(x + 2, y + 7 + k * 2, x + 9, y + 7 + k * 2), darker(col, 0.35), 0.8)


def turno(cv, rng):
	"""Ticket de turno tirado (numero impreso)."""
	x, y = rng.randint(20, 40), rng.randint(22, 40)
	emboss(cv, rect(x, y, x + 7, y + 10), (238, 226, 190), None, darker((238, 226, 190), 0.2), 0.3, 0.95)
	cv.blend(rect(x + 2, y + 3, x + 5, y + 3), (160, 40, 40), 0.9)
	cv.blend(rect(x + 2, y + 5, x + 5, y + 5), (160, 40, 40), 0.9)
	cv.blend(rect(x + 2, y + 7, x + 4, y + 7), (160, 40, 40), 0.9)


def chicle(cv, rng):
	x, y = rng.randint(16, 46), rng.randint(16, 46)
	cv.blend(ell(x, y, 2.2, 1.6), (214, 140, 160), 0.9)
	cv.blend(rect(x - 1, y - 1, x, y - 1), (240, 190, 204), 0.9)


def prostata_fill(i, cv, rng, cfg):
	if i < 5 and rng.random() < 0.4:
		pebbles(cv, rng, (160, 146, 142), 2)
	if i == 5:
		d_stain(cv, rng, (96, 78, 66), 0.26)
	elif i == 6:
		d_crack(cv, rng, cfg, 1)
	elif i == 7:
		d_flake(cv, rng, cfg, 2)
	elif i == 8:
		chicle(cv, rng)
	elif i == 9:
		turno(cv, rng)
	elif i == 10:
		d_stain(cv, rng, (150, 160, 120), 0.22, 6)  # un charquito dudoso
		d_crack(cv, rng, cfg, 1, (14, 22))
	elif i == 11:
		revista(cv, rng, (170, 110, 120))


def prostata_ornate(i, cv, rng, cfg):
	if i == 0:
		cv.blend(rect(14, 30, 49, 33), NUEZ, 0.5)
	elif i == 1:
		revista(cv, rng, (110, 130, 150))
	elif i == 2:
		cv.blend(ell(32, 32, 8, 8), NUEZ, 0.45)
		cv.blend(line([(32, 25), (32, 39)], 1), darker(NUEZ, 0.3), 0.7)
	else:
		for k in range(4):
			cv.blend(rect(12 + k * 12, 18, 18 + k * 12, 45), LECHE, 0.25)


def prostata_band(cv, b):
	cv.blend(rect(0, 0, 63, 2), (64, 52, 48), 0.55)
	# zocalo de madera de nuez con veta y una cinta gris
	emboss(cv, rect(0, 3, 63, 13, cv.w, cv.h), NUEZ, lighter(NUEZ, 0.25), darker(NUEZ, 0.3), 0.0, 0.95)
	for x0 in (10, 27, 44):
		cv.blend(line([(x0, 5), (x0 + 6, 11)], 1, cv.w, cv.h), darker(NUEZ, 0.2), 0.45)
	cv.blend(rect(0, 14, 63, 15, cv.w, cv.h), SALA, 0.6)
	if b == 1:
		cv.blend(rect(0, 8, 63, 8, cv.w, cv.h), LECHE, 0.5)


def prostata_corner(cv, b):
	emboss(cv, rect(0, 0, 15, 15, cv.w, cv.h), NUEZ, lighter(NUEZ, 0.25), darker(NUEZ, 0.3), 0.0, 0.95)
	cv.blend(rect(4, 4, 11, 11, cv.w, cv.h), darker(NUEZ, 0.25), 0.8)


def prostata_motif(cv, rng):
	"""Alfombra de sala de espera: rosa lechoso con orla nuez y, al centro, una nuez partida."""
	W = cv.w
	ys, xs = np.mgrid[0:W, 0:W]
	d = np.minimum(np.minimum(xs, W - 1 - xs), np.minimum(ys, W - 1 - ys))
	fade = np.clip((d - 6) / 20.0, 0, 1)
	rug = rect(30, 30, W - 31, W - 31, W, W)
	cv.blend(rug, LECHE, 0.42 * fade)
	cv.blend(rug & ~rect(36, 36, W - 37, W - 37, W, W), NUEZ, 0.35 * fade)
	cv.blend(rug & ((xs + ys) % 12 == 0), SALA, 0.25)
	emboss(cv, ell(96, 96, 18, 15, W, W), NUEZ, lighter(NUEZ, 0.3), darker(NUEZ, 0.3), 0.3, 0.7)
	cv.blend(line([(96, 82), (92, 96), (96, 110)], 1, W, W), darker(NUEZ, 0.4), 0.85)
	cv.blend(ell(100, 94, 5, 7, W, W), lighter(NUEZ, 0.2), 0.5)


# ================================================================== PALACIO (censura)
VIOLET = (128, 104, 176)
INK = (60, 54, 78)


def censura_cfg():
	return dict(
		seed=51, layout=grid_layout(32, 32), base=(216, 214, 226), tone=0.012, grain=0.01,
		joint=(158, 154, 178), jd=0.75, hi=(246, 244, 252), jl=0.6, crack=(130, 124, 152), under=(186, 182, 202), dome=0.0,
	)


def gloss(cv, rng):
	x0 = rng.uniform(12, 44)
	m = np.zeros((T, T), bool)
	ys, xs = np.mgrid[0:T, 0:T]
	d = (xs - ys) - (x0 - 32)
	m = (np.abs(d) < 2.2) & (xs > 8) & (xs < 56) & (ys > 8) & (ys < 56)
	cv.blend(m, (255, 255, 255), 0.22)
	m2 = (np.abs(d - 6) < 1.0) & (xs > 8) & (xs < 56) & (ys > 8) & (ys < 56)
	cv.blend(m2, (255, 255, 255), 0.14)


def barra(cv, x, y, w, h, al=0.5):
	emboss(cv, rect(x, y, x + w, y + h, cv.w, cv.h), INK, lighter(INK, 0.2), darker(INK, 0.3), 0.0, al)


def pixelado(cv, rng):
	"""Gag raro: un cuadradito de pixeles de censura."""
	x, y = rng.randint(22, 34), rng.randint(22, 34)
	for i in range(3):
		for j in range(3):
			c = 150 + ((i * 3 + j * 5) % 4) * 18
			cv.blend(rect(x + i * 4, y + j * 4, x + i * 4 + 3, y + j * 4 + 3), (c, c - 4, c + 10), 0.7)


def censura_fill(i, cv, rng, cfg):
	if i < 5:
		gloss(cv, rng)
	if i == 5:
		d_stain(cv, rng, (150, 144, 172), 0.22)
	elif i == 6:
		d_crack(cv, rng, cfg, 1, (16, 26))
	elif i == 7:
		d_flake(cv, rng, cfg, 1)
	elif i == 8:
		barra(cv, rng.randint(14, 30), rng.randint(24, 38), rng.randint(14, 20), 5, 0.3)
	elif i == 9:
		sello_circ(cv, rng.randint(24, 40), rng.randint(24, 40), 7, VIOLET, 0.3)
	elif i == 10:
		d_crack(cv, rng, cfg, 1, (12, 20))
		d_stain(cv, rng, (150, 144, 172), 0.18, 7)
	elif i == 11:
		pixelado(cv, rng)


def censura_ornate(i, cv, rng, cfg):
	if i == 0:
		sello_circ(cv, 32, 32, 11, VIOLET, 0.45)
	elif i == 1:
		barra(cv, 16, 28, 32, 7, 0.4)
		cv.blend(rect(16, 30, 18, 32), (216, 214, 226), 0.8)
	elif i == 2:
		pts = [(32 + (11 if k % 2 == 0 else 5) * math.cos(k * 0.628 - 1.57), 32 + (11 if k % 2 == 0 else 5) * math.sin(k * 0.628 - 1.57)) for k in range(10)]
		emboss(cv, poly(pts), (200, 188, 232), lighter((200, 188, 232), 0.4), darker((200, 188, 232), 0.2), 0.2, 0.7)
	else:
		pixelado(cv, rng)


def censura_band(cv, b):
	cv.blend(rect(0, 0, 63, 2), (110, 104, 136), 0.5)
	cv.blend(rect(0, 3, 63, 4), (110, 104, 136), 0.2)
	cv.blend(rect(0, 5, 63, 14), (196, 192, 214), 0.88)
	cv.blend(rect(0, 14, 63, 14), (150, 144, 172), 0.9)
	cv.blend(rect(0, 15, 63, 15), (246, 244, 252), 0.7)
	cv.blend(rect(0, 5, 63, 5), (236, 232, 246), 0.8)
	for k in range(2):
		cx = 16 + k * 32
		if b == 1 and k == 1:
			barra(cv, cx - 11, 7, 22, 5, 0.55)
			for px in range(-9, 9, 6):
				cv.blend(rect(cx + px, 8, cx + px + 1, 9, cv.w, cv.h), (196, 192, 214), 0.9)
		else:
			sello_circ(cv, cx, 10, 5, VIOLET, 0.7)


def censura_corner(cv, b):
	emboss(cv, rect(0, 0, 17, 17, cv.w, cv.h), (184, 178, 206), lighter((184, 178, 206), 0.4), darker((184, 178, 206), 0.2), 0.35)
	sello_circ(cv, 9, 9, 6, VIOLET, 0.85)
	barra(cv, 1, 8, 15, 3, 0.55)


def censura_motif(cv, rng):
	W = cv.w
	r, th = ang_grid(96, 96, W, W)
	ys, xs = np.mgrid[0:W, 0:W]
	ring_o = (r >= 76) & (r < 80)
	ring_i = (r >= 66) & (r < 69)
	ticks = (r >= 70) & (r < 75) & ((((th + math.pi) / (2 * math.pi) * 48).astype(int) % 2) == 0)
	cv.blend(ring_o | ring_i | ticks, VIOLET, 0.42)
	cv.blend(shift(ring_o | ring_i, 1, 1) & ~(ring_o | ring_i), (255, 255, 255), 0.4)
	ring_c = (r >= 38) & (r < 41)
	cv.blend(ring_c, VIOLET, 0.35)
	for k in range(5):
		a = k * 1.2566 - 1.5708
		pts = []
		for s in range(10):
			rr = 22 if s % 2 == 0 else 10
			aa = a + (s * 0.628 - 1.5708) * 0 + 0
		pass
	pts = [(96 + (30 if k % 2 == 0 else 13) * math.cos(k * 0.628 - 1.57), 96 + (30 if k % 2 == 0 else 13) * math.sin(k * 0.628 - 1.57)) for k in range(10)]
	emboss(cv, poly(pts, W, W), (200, 188, 232), lighter((200, 188, 232), 0.4), darker((200, 188, 232), 0.2), 0.2, 0.55)
	# barra de censura inclinada con muescas de "texto"
	ang = -0.35
	ca, sa = math.cos(ang), math.sin(ang)
	hw, hh = 64, 10
	bar = poly([(96 + x * ca - y * sa, 96 + x * sa + y * ca) for x, y in ((-hw, -hh), (hw, -hh), (hw, hh), (-hw, hh))], W, W)
	emboss(cv, bar, INK, lighter(INK, 0.2), darker(INK, 0.3), 0.3, 0.5)
	for k in range(-5, 6):
		x = k * 11
		cv.blend(poly([(96 + (x + a) * ca - b * sa, 96 + (x + a) * sa + b * ca) for a, b in ((0, -3), (5, -3), (5, 3), (0, 3))], W, W), (216, 214, 226), 0.35)


# ================================================================== registro y atlas
KINGDOMS = {
	"neutral": dict(cfg=selva_cfg, fill=selva_fill, ornate=selva_ornate, band=selva_band, corner=selva_corner, motif=selva_motif),
	"pene": dict(cfg=pene_cfg, fill=pene_fill, ornate=pene_ornate, band=pene_band, corner=pene_corner, motif=pene_motif),
	"vulva": dict(cfg=vulva_cfg, fill=vulva_fill, ornate=vulva_ornate, band=vulva_band, corner=vulva_corner, motif=vulva_motif),
	"mixto": dict(cfg=mixto_cfg, fill=mixto_fill, ornate=mixto_ornate, band=mixto_band, corner=mixto_corner, motif=mixto_motif),
	"prostata": dict(cfg=prostata_cfg, fill=prostata_fill, ornate=prostata_ornate, band=prostata_band, corner=prostata_corner, motif=prostata_motif),
	"censura": dict(cfg=censura_cfg, fill=censura_fill, ornate=censura_ornate, band=censura_band, corner=censura_corner, motif=censura_motif),
}


def paste(atlas, cv, col, row):
	atlas.alpha_composite(cv.img(), (col * T, row * T))


def make_edge(k, cfg, band_fn, b):
	base = base_tile(cfg, random.Random(900 + b))
	layer = Cv(T, T, a=0.0)
	band_fn(layer, b)
	return base, layer


def build(name):
	k = KINGDOMS[name]
	cfg = k["cfg"]()
	atlas = Image.new("RGBA", (COLS * T, ROWS * T), (0, 0, 0, 0))
	# relleno 0-11
	for i in range(12):
		rng = random.Random(cfg["seed"] * 100 + i)
		cv = base_tile(cfg, rng)
		k["fill"](i, cv, rng, cfg)
		paste(atlas, cv, i % 8, i // 8)
	for i in range(4):
		rng = random.Random(cfg["seed"] * 100 + 50 + i)
		cv = base_tile(cfg, rng)
		k["ornate"](i, cv, rng, cfg)
		paste(atlas, cv, 4 + i, 1)
	# bordes y esquinas
	rots = [0, -1, 2, 1]  # N, E, S, O
	for b in (0, 1):
		layer = Cv(T, T, a=0.0)
		k["band"](layer, b)
		for d, r in enumerate(rots):
			rng = random.Random(cfg["seed"] * 100 + 70 + b)
			cv = base_tile(cfg, rng)
			cv.comp(layer.rot(r))
			paste(atlas, cv, d, 2 + b)
	corner = Cv(T, T, a=0.0)
	k["corner"](corner, 0)
	band = Cv(T, T, a=0.0)
	k["band"](band, 0)
	# esquina NO = banda N + banda O + bloque; NE = N + E; SE = E + S; SO = S + O
	pairs = [(0, 1), (0, -1), (-1, 2), (2, 1)]
	cr = [0, -1, 2, 1]
	for d in range(4):
		rng = random.Random(cfg["seed"] * 100 + 80)
		cv = base_tile(cfg, rng)
		cv.comp(band.rot(pairs[d][0]))
		cv.comp(band.rot(pairs[d][1]))
		cv.comp(corner.rot(cr[d]))
		paste(atlas, cv, 4 + d, 2)
	# motivo central 3x3
	rng = random.Random(cfg["seed"] * 100 + 90)
	big = base_tile(cfg, rng, reps=3)
	k["motif"](big, rng)
	im = big.img()
	atlas.alpha_composite(im, (5 * T, 3 * T))
	OUT.mkdir(parents=True, exist_ok=True)
	atlas.save(OUT / f"floor_{name}.png")
	write_tileset(name)


def write_tileset(name):
	tiles = []
	for i in range(12):
		tiles.append((i % 8, i // 8))
	for i in range(4):
		tiles.append((4 + i, 1))
	for r in (2, 3):
		for c in range(4):
			tiles.append((c, r))
	for c in range(4, 8):
		tiles.append((c, 2))
	for y in range(3):
		for x in range(3):
			tiles.append((5 + x, 3 + y))
	lines = [
		"[gd_resource type=\"TileSet\" load_steps=3 format=3]",
		"",
		f"[ext_resource type=\"Texture2D\" path=\"res://assets/sprites/environment/floors/floor_{name}.png\" id=\"1\"]",
		"",
		"[sub_resource type=\"TileSetAtlasSource\" id=\"TileSetAtlasSource_1\"]",
		"texture = ExtResource(\"1\")",
		"texture_region_size = Vector2i(64, 64)",
	]
	for x, y in tiles:
		lines.append(f"{x}:{y}/0 = 0")
	lines += ["", "[resource]", "tile_size = Vector2i(64, 64)", "sources/0 = SubResource(\"TileSetAtlasSource_1\")", ""]
	TS_OUT.mkdir(parents=True, exist_ok=True)
	(TS_OUT / f"floor_{name}.tres").write_text("\n".join(lines))


if __name__ == "__main__":
	names = sys.argv[1:] or list(KINGDOMS)
	for n in names:
		build(n)
		print("ok", n)
