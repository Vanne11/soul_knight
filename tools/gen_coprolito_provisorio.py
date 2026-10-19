"""ARTE PROVISORIO de El Coprolito y del Guijarro, dibujado por codigo (PIL), sin Gemini.
Se hizo porque la cuenta de Gemini llego al tope de gasto mensual (HTTP 429 RESOURCE_EXHAUSTED, 2026-10-19) y el jefe tenia que
poder jugarse. Genera las mismas hojas/.tres que tools/gen_coprolito_art.py (mismos nombres de animacion y de pose), asi que
cuando haya cuota basta con correr `gen_coprolito_art.py gen` y `build` para reemplazarlo sin tocar codigo.

Uso: python3 tools/gen_coprolito_provisorio.py [preview DIR]
"""
import math
import sys
from pathlib import Path

from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parent))
import gen_coprolito_art as C  # noqa: E402
import gen_arcoiria_art2 as A  # noqa: E402

W, H = C.TW, C.TH  # 176 x 184
K = 3  # supermuestreo
OUT = (34, 24, 20)
BASE = (128, 106, 84)
LIGHT = (166, 142, 112)
DARK = (84, 66, 52)
MOSS = (112, 138, 70)
MOSS_D = (78, 100, 52)
GOLD = (232, 196, 80)
EYE = (240, 232, 214)
ORANGE = (240, 130, 50)


def _ell(d, cx, cy, rx, ry, fill, outline=OUT, w=3):
    d.ellipse([(cx - rx) * K, (cy - ry) * K, (cx + rx) * K, (cy + ry) * K], fill=fill, outline=outline, width=w * K // 2)


def draw_copro(sy=1.0, dy=0, tilt=0.0, arms="down", eyes="open", mouth="flat", fx=None, phase=1, pile=0, step=0):
    """Una pose 176x184. arms: down|up|fwd|cane; eyes: open|closed|spiral|wide|half; pile: 0 entero, 1 grietas, 2 mitades, 3 monton."""
    im = Image.new("RGBA", (W * K, H * K), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    gy = H - 6 - dy  # suelo
    bw = 118  # ancho base
    if pile >= 3:  # monton de roca roto (muerte)
        for i, (x, y, rx, ry) in enumerate([(70, 0, 30, 14), (104, 0, 26, 12), (88, -14, 20, 10), (52, -4, 14, 8), (124, -2, 12, 7)]):
            _ell(d, x + 6, gy + y - ry, rx, ry, BASE if i % 2 else LIGHT)
        _ell(d, 96, gy - 26, 10, 10, EYE)
        d.line([(88 * K, (gy - 30) * K), (104 * K, (gy - 22) * K)], fill=OUT + (255,), width=3 * K)
        d.line([(104 * K, (gy - 30) * K), (88 * K, (gy - 22) * K)], fill=OUT + (255,), width=3 * K)
        d.line([(140 * K, gy * K), (140 * K, (gy - 40) * K)], fill=(150, 110, 70, 255), width=3 * K)  # baston
        d.polygon([(140 * K, (gy - 40) * K), (160 * K, (gy - 34) * K), (140 * K, (gy - 28) * K)], fill=(240, 240, 240, 255))  # bandera blanca
        return _finish(im)
    cx = W // 2
    h1, h2, h3 = 52 * sy, 46 * sy, 40 * sy
    y1 = gy - h1 * 0.5
    y2 = gy - h1 * 0.9 - h2 * 0.45
    y3 = y2 - h2 * 0.75 - h3 * 0.2
    # piernas cortas
    lo = 4 if step == 1 else (-4 if step == 2 else 0)
    for sx in (-1, 1):
        o = lo * sx
        d.rectangle([(cx + sx * 26 - 9) * K, (gy - 10 + o * 0.5) * K, (cx + sx * 26 + 9) * K, (gy + 2) * K], fill=DARK + (255,), outline=OUT + (255,), width=3 * K // 2)
    # cuerpo en espiral: tres anillos
    _ell(d, cx, y1, bw / 2, h1 / 2, BASE)
    _ell(d, cx, y1 - 6, bw / 2 - 10, h1 / 2 - 8, LIGHT, outline=None)
    _ell(d, cx, y2, bw / 2 - 18, h2 / 2, BASE)
    _ell(d, cx, y2 - 5, bw / 2 - 28, h2 / 2 - 8, LIGHT, outline=None)
    if pile < 2:
        _ell(d, cx, y3, bw / 2 - 36, h3 / 2, BASE)
        # punta enroscada arriba (no en fase 3: se rompio)
        if phase < 3:
            d.polygon([((cx - 14) * K, (y3 - 8) * K), ((cx + 22) * K, (y3 - 28) * K), ((cx + 8) * K, (y3 - 4) * K)], fill=BASE + (255,), outline=OUT + (255,))
            d.line([((cx - 6) * K, (y3 - 6) * K), ((cx + 14) * K, (y3 - 22) * K)], fill=LIGHT + (255,), width=2 * K)
    # vetas oscuras y amonitas
    for k in range(4):
        yy = [y1 + 10, y1 - 4, y2 + 8, y2 - 4][k]
        d.arc([(cx - 50 + k * 22) * K, (yy - 6) * K, (cx - 14 + k * 22) * K, (yy + 8) * K], 190, 350, fill=DARK + (255,), width=2 * K)
    ax, ay = cx + 34, y1 - 8
    for r in (11, 7, 3):
        d.arc([(ax - r) * K, (ay - r) * K, (ax + r) * K, (ay + r) * K], 0, 300, fill=DARK + (255,), width=2 * K)
    # cara en el anillo del medio
    ey = y2 - 2
    for ex in (cx - 15, cx + 15):
        if eyes == "closed":
            d.arc([(ex - 8) * K, (ey - 4) * K, (ex + 8) * K, (ey + 6) * K], 10, 170, fill=OUT + (255,), width=2 * K)
            continue
        _ell(d, ex, ey, 8, 7 if eyes != "wide" else 9, EYE)
        if eyes == "spiral":
            for r in (6, 3):
                d.arc([(ex - r) * K, (ey - r) * K, (ex + r) * K, (ey + r) * K], 0, 300, fill=OUT + (255,), width=K)
        else:
            _ell(d, ex + 1, ey + 1, 3, 3, OUT, outline=None)
            if eyes in ("open", "half"):  # parpados pesados de anciano
                d.rectangle([(ex - 9) * K, (ey - 8) * K, (ex + 9) * K, (ey - (1 if eyes == "half" else 3)) * K], fill=BASE + (255,))
                d.line([((ex - 9) * K, (ey - (1 if eyes == "half" else 3)) * K), ((ex + 9) * K, (ey - (1 if eyes == "half" else 3)) * K)], fill=OUT + (255,), width=2 * K)
        d.polygon([((ex - 10) * K, (ey - 11) * K), ((ex + 10) * K, (ey - 13) * K), ((ex + 8) * K, (ey - 8) * K), ((ex - 8) * K, (ey - 7) * K)], fill=MOSS + (255,), outline=MOSS_D + (255,))
    d.ellipse([(cx + 15 - 12) * K, (ey - 12) * K, (cx + 15 + 12) * K, (ey + 11) * K], outline=GOLD + (255,), width=2 * K)  # monoculo
    d.line([((cx + 15 + 9) * K, (ey + 8) * K), ((cx + 36) * K, (ey + 26) * K)], fill=GOLD + (255,), width=K)
    # barba de musgo
    by = ey + 12
    beard = [(cx - 30, by - 6), (cx + 30, by - 6), (cx + 24, by + 12), (cx + 12, by + 28), (cx, by + 20), (cx - 12, by + 30), (cx - 24, by + 12)]
    d.polygon([(x * K, y * K) for x, y in beard], fill=MOSS + (255,), outline=MOSS_D + (255,))
    if mouth == "open":
        _ell(d, cx, by + 2, 8, 6, OUT, outline=None)
    elif mouth == "strain":
        d.line([((cx - 9) * K, (by + 2) * K), ((cx + 9) * K, (by + 2) * K)], fill=OUT + (255,), width=3 * K)
    else:
        d.line([((cx - 6) * K, (by + 1) * K), ((cx + 6) * K, (by + 1) * K)], fill=OUT + (255,), width=2 * K)
    # brazos y baston
    sh = y1 - 14
    if arms == "up":
        for sx in (-1, 1):
            d.line([((cx + sx * 50) * K, sh * K), ((cx + sx * 62) * K, (sh - 46) * K)], fill=OUT + (255,), width=9 * K)
            d.line([((cx + sx * 50) * K, sh * K), ((cx + sx * 62) * K, (sh - 46) * K)], fill=BASE + (255,), width=6 * K)
    elif arms == "fwd":
        d.line([((cx + 50) * K, sh * K), ((cx + 82) * K, (sh - 6) * K)], fill=OUT + (255,), width=9 * K)
        d.line([((cx + 50) * K, sh * K), ((cx + 82) * K, (sh - 6) * K)], fill=BASE + (255,), width=6 * K)
        d.line([((cx - 50) * K, sh * K), ((cx - 66) * K, (sh + 12) * K)], fill=OUT + (255,), width=9 * K)
        d.line([((cx - 50) * K, sh * K), ((cx - 66) * K, (sh + 12) * K)], fill=BASE + (255,), width=6 * K)
    else:
        d.line([((cx - 50) * K, sh * K), ((cx - 62) * K, (sh + 18) * K)], fill=OUT + (255,), width=9 * K)
        d.line([((cx - 50) * K, sh * K), ((cx - 62) * K, (sh + 18) * K)], fill=BASE + (255,), width=6 * K)
        d.line([((cx + 52) * K, sh * K), ((cx + 66) * K, (sh + 14) * K)], fill=OUT + (255,), width=9 * K)
        d.line([((cx + 52) * K, sh * K), ((cx + 66) * K, (sh + 14) * K)], fill=BASE + (255,), width=6 * K)
        if arms == "cane":
            d.line([((cx + 68) * K, (sh + 12) * K), ((cx + 68) * K, (gy + 2) * K)], fill=(60, 40, 28, 255), width=5 * K)
            d.line([((cx + 68) * K, (sh + 12) * K), ((cx + 68) * K, (gy + 2) * K)], fill=(150, 110, 70, 255), width=3 * K)
    # danos por fase
    if phase >= 2 or pile >= 1:
        for (x0, y0, x1, y1_) in [(cx - 30, y1 - 22, cx - 12, y1 + 6), (cx + 6, y2 + 14, cx + 22, y1 + 8)]:
            d.line([(x0 * K, y0 * K), (((x0 + x1) // 2 + 4) * K, ((y0 + y1_) // 2) * K), (x1 * K, y1_ * K)], fill=OUT + (255,), width=3 * K)
            d.line([(x0 * K, y0 * K), (((x0 + x1) // 2 + 4) * K, ((y0 + y1_) // 2) * K), (x1 * K, y1_ * K)], fill=ORANGE + (255,), width=K)
    if phase >= 3 or pile >= 2:
        for (x0, y0, x1, y1_) in [(cx + 26, y1 - 18, cx + 44, y1 + 12), (cx - 8, y3 - 4, cx + 4, y2 + 6), (cx - 52, y1 + 2, cx - 34, y1 + 18)]:
            d.line([(x0 * K, y0 * K), (x1 * K, y1_ * K)], fill=OUT + (255,), width=3 * K)
            d.line([(x0 * K, y0 * K), (x1 * K, y1_ * K)], fill=ORANGE + (255,), width=K)
        for (x, y) in [(cx - 70, y2), (cx + 74, y2 - 20), (cx + 60, y3 - 10)]:  # fragmentos flotando
            d.polygon([(x * K, y * K), ((x + 8) * K, (y + 3) * K), ((x + 3) * K, (y + 9) * K)], fill=BASE + (255,), outline=OUT + (255,))
    if fx == "glow":
        for r, a in ((76, 40), (62, 70)):
            ov = Image.new("RGBA", im.size, (0, 0, 0, 0))
            ImageDraw.Draw(ov).ellipse([(cx - r) * K, (y2 - r * 0.9) * K, (cx + r) * K, (y2 + r * 0.9) * K], fill=(255, 220, 120, a))
            im = Image.alpha_composite(ov, im)
    elif fx == "dust":
        d2 = ImageDraw.Draw(im)
        for x in (-70, -50, 54, 76):
            _ell(d2, cx + x, gy - 4, 9, 6, (200, 180, 150, 255), outline=None)
    elif fx == "stone":
        d2 = ImageDraw.Draw(im)
        pts = [(cx + 84, y2 - 6), (cx + 98, y2 + 8), (cx + 74, y2 + 22)] if arms != "up" else [(cx - 60, y3 - 30), (cx + 60, y3 - 36), (cx, y3 - 50)]
        for (x, y) in pts:
            d2.polygon([(x * K, y * K), ((x + 10) * K, (y + 3) * K), ((x + 4) * K, (y + 11) * K)], fill=BASE + (255,), outline=OUT + (255,))
    return _finish(im, tilt)


def _finish(im, tilt=0.0):
    if tilt:
        im = im.rotate(tilt, resample=Image.BICUBIC, center=(W * K // 2, (H - 4) * K))
    return im.resize((W, H), Image.BOX)


POSES = dict(
    idle={"arms": "cane"}, w1={"arms": "cane", "step": 1}, w2={"arms": "cane", "dy": 2}, w3={"arms": "cane", "step": 2},
    temw={"arms": "up", "sy": 0.92, "eyes": "half", "mouth": "strain"}, temr={"arms": "fwd", "sy": 0.9, "fx": "dust", "mouth": "open", "eyes": "wide"},
    fosw={"arms": "up", "tilt": -4, "mouth": "open"}, fosr={"arms": "fwd", "tilt": 4, "fx": "stone", "mouth": "open"},
    intro={"arms": "up", "eyes": "wide", "mouth": "open", "fx": "stone"}, tired={"arms": "down", "sy": 0.94, "eyes": "closed", "tilt": 3},
    stun={"arms": "down", "eyes": "spiral", "tilt": -4}, channel={"arms": "up", "eyes": "closed", "fx": "glow"},
    hurt={"arms": "down", "eyes": "closed", "tilt": -6, "mouth": "open"},
    x1={"arms": "down", "eyes": "spiral", "tilt": -9, "pile": 1}, x2={"arms": "up", "eyes": "closed", "tilt": 14, "pile": 2, "sy": 0.85},
    x3={"pile": 3},
    fanw={"arms": "up", "tilt": -3, "eyes": "half"}, fanr={"arms": "fwd", "tilt": 4, "fx": "stone", "mouth": "open"},
    tapw={"arms": "down", "eyes": "closed", "mouth": "strain", "sy": 0.9}, tapr={"arms": "fwd", "eyes": "open", "fx": "stone", "sy": 1.04},
    llaw={"arms": "up", "mouth": "open"}, llar={"arms": "cane", "fx": "dust", "mouth": "open"},
    chaw={"arms": "down", "sy": 0.88, "eyes": "wide", "tilt": -8}, char={"arms": "down", "sy": 0.9, "eyes": "wide", "tilt": 12, "fx": "dust"},
)


def boss_poses_prov(suffix):
    phase = {"": 1, "_p2": 2, "_p3": 3}[suffix]
    out = {}
    for k, kw in POSES.items():
        kw = dict(kw)
        kw["phase"] = max(phase, kw.get("pile", 0) and 3 or phase)
        out[k] = draw_copro(**kw)
    return A.quantize_set(out, 44)


# ------------------------------------------------------------------ guijarro 32x48
def draw_guijarro(kind="idle"):
    im = Image.new("RGBA", (C.SW_ * 4, C.SH_ * 4), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    s = 4
    dy = 2 if kind == "walk" else 0
    if kind in ("d3",):
        for x, w in ((6, 8), (14, 7), (21, 5)):
            d.ellipse([x * s, (43 - w // 2) * s, (x + w) * s, 46 * s], fill=LIGHT + (255,), outline=OUT + (255,), width=s // 2)
        return im.resize((C.SW_, C.SH_), Image.BOX)
    sq = 0.85 if kind in ("aim", "hurt") else 1.0
    top = 20 + (28 - 28 * sq) + dy
    d.ellipse([4 * s, top * s, 28 * s, 45 * s], fill=LIGHT + (255,), outline=OUT + (255,), width=s // 2 + 1)
    d.ellipse([8 * s, (top + 3) * s, 24 * s, (top + 12) * s], fill=(190, 166, 136, 255))
    d.polygon([(13 * s, (top + 1) * s), (16 * s, (top - 5) * s), (19 * s, (top + 1) * s)], fill=MOSS + (255,), outline=MOSS_D + (255,))
    for ex in (12, 20):
        d.ellipse([(ex - 2) * s, (top + 13) * s, (ex + 2) * s, (top + 17) * s], fill=OUT + (255,))
        d.line([((ex - 3) * s, (top + 11) * s), ((ex + 2) * s, (top + 12) * s)], fill=OUT + (255,), width=s)
    d.arc([18 * s, (top + 20) * s, 28 * s, (top + 28) * s], 0, 300, fill=DARK + (255,), width=s)
    if kind in ("aim", "burst"):
        d.line([(8 * s, (top + 22) * s), (14 * s, (top + 34) * s)], fill=ORANGE + (255,), width=s)
        d.line([(20 * s, (top + 20) * s), (24 * s, (top + 32) * s)], fill=ORANGE + (255,), width=s)
    if kind == "burst":
        for (x, y) in ((2, 24), (28, 22), (4, 8), (27, 8)):
            d.polygon([(x * s, y * s), ((x + 3) * s, (y + 1) * s), ((x + 1) * s, (y + 4) * s)], fill=BASE + (255,), outline=OUT + (255,))
    if kind in ("d1", "d2"):
        d.line([(10 * s, (top + 4) * s), (22 * s, 44 * s)], fill=OUT + (255,), width=2 * s)
    return im.resize((C.SW_, C.SH_), Image.BOX)


def guijarro_poses_prov():
    names = ("idle", "walk", "aim", "burst", "hurt", "d1", "d2", "d3")
    return A.quantize_set({n: draw_guijarro(n) for n in names}, 28)


def cover():
    """Caratula PROVISORIA 320x180 (assets/sprites/ui/bosses/coprolito.png): salon de excavacion simple con el jefe delante."""
    im = Image.new("RGB", (320, 180), (38, 30, 28))
    d = ImageDraw.Draw(im)
    for y in range(180):  # fondo: tierra que sube de oscuro a calido
        t = y / 179.0
        d.line([(0, y), (320, y)], fill=(int(38 + 50 * t), int(30 + 36 * t), int(28 + 24 * t)))
    d.rectangle([0, 128, 320, 180], fill=(92, 72, 54))  # suelo de tierra
    for x in range(0, 320, 40):  # estratos y cuadricula de excavacion
        d.line([(x, 20), (x, 128)], fill=(60, 48, 40))
    for y in (46, 76, 104):
        d.line([(0, y), (320, y)], fill=(70, 56, 46))
    for (x, y) in ((30, 60), (270, 90), (60, 100), (250, 40)):  # amonitas incrustadas en la pared
        d.ellipse([x - 9, y - 9, x + 9, y + 9], outline=(124, 104, 82), width=2)
        d.ellipse([x - 4, y - 4, x + 4, y + 4], outline=(124, 104, 82), width=1)
    d.polygon([(250, 128), (275, 70), (300, 128)], fill=(110, 92, 70))  # un cono de tierra y una pala
    d.line([(60, 128), (80, 76)], fill=(150, 110, 70), width=3)
    d.polygon([(74, 70), (88, 74), (82, 84)], fill=(160, 160, 170))
    boss = boss_poses_prov("")["intro"]
    big = boss.resize((boss.width * 85 // 100, boss.height * 85 // 100), Image.BOX)
    im.paste(big, (160 - big.width // 2, 176 - big.height), big)
    out = C.ROOT / "assets/sprites/ui/bosses/coprolito.png"
    im.save(out)
    print("caratula provisoria", out)


def main():
    cover()
    C.DEST.mkdir(parents=True, exist_ok=True)
    for suf in C.VARIANTS:
        P = boss_poses_prov(suf)
        n = C.T._tres(C.boss_anims(P), C.DEST / f"coprolito_sheet{suf}.png", f"{C.RES}coprolito_sheet{suf}.png", C.TW, C.TH, 6,
                      C.DEST / f"coprolito_sprite_frames{suf}.tres")
        print("coprolito provisorio", suf or "_p1", n, "cuadros")
    C.guijarro_poses = guijarro_poses_prov
    C.build_guijarro()
    print("guijarro provisorio listo")


if __name__ == "__main__":
    if len(sys.argv) > 2 and sys.argv[1] == "preview":
        d = Path(sys.argv[2])
        d.mkdir(parents=True, exist_ok=True)
        for suf in C.VARIANTS:
            P = boss_poses_prov(suf)
            items = list(P.values())
            sh = Image.new("RGBA", (8 * W, 3 * H), (58, 56, 84, 255))
            for i, im in enumerate(items):
                sh.alpha_composite(im, ((i % 8) * W, (i // 8) * H))
            sh.convert("RGB").save(d / f"coprolito{suf}_prov_poses.png")
        g = guijarro_poses_prov()
        sh = Image.new("RGBA", (8 * C.SW_ * 4, C.SH_ * 4), (58, 56, 84, 255))
        for i, im in enumerate(g.values()):
            sh.alpha_composite(im.resize((C.SW_ * 4, C.SH_ * 4), Image.NEAREST), (i * C.SW_ * 4, 0))
        sh.convert("RGB").save(d / "guijarro_prov_x4.png")
    else:
        main()
