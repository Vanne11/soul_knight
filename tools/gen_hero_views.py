#!/usr/bin/env python3
"""Genera por codigo las vistas extra de los tres heroes a partir de sus cuadros existentes.

Uso: python3 tools/gen_hero_views.py [--preview ruta.png]

Escribe en assets/sprites/player/<heroe>/ (y regenera sprite_frames.tres de cada uno):
  walkup_00..05, idleup_00..03   vista de ESPALDAS (al caminar hacia arriba)
  walkdown_00..05, idledown_00..03   vista de FRENTE (solo el Ornitorrinco: Pitocles y
                                 Vulvalquiria ya se dibujaron de frente y reusan walk/idle)
  camera_00..03                  "mirar a camara": gesto propio de cada heroe
  gesture_00..03                 gesto de espera (pule el casco / se acomoda la trenza /
                                 el Ornitorrinco mira alrededor y grazna)
Los cuadros base (idle/walk/attack/dash/hurt/death) NO se tocan. Despues de correrlo,
conviene correr tools/gen_hand_anchors.py (anclas de mano de las animaciones nuevas).
Todo es determinista (sin IA): editar pixeles de los cuadros del propio juego.
"""
import sys
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
PLAYER = ROOT / "assets/sprites/player"
HEROES = ["pitocles", "vulvalquiria", "ornitorrinco"]


def hexc(s):
    return (int(s[1:3], 16), int(s[3:5], 16), int(s[5:7], 16), 255)


BLACK = hexc("#0d0b0f")


def load(h, name):
    return Image.open(PLAYER / h / f"{name}.png").convert("RGBA")


def put(img, x, y, c):
    if 0 <= x < img.width and 0 <= y < img.height:
        img.putpixel((x, y), c)


def opaque(img, x, y):
    return 0 <= x < img.width and 0 <= y < img.height and img.getpixel((x, y))[3] > 128


def rect(img, x0, y0, x1, y1, c):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            put(img, x, y, c)


def clear(img, x0, y0, x1, y1):
    rect(img, x0, y0, x1, y1, (0, 0, 0, 0))


def top_row(img, x0=0, x1=31):
    for y in range(img.height):
        for x in range(x0, x1 + 1):
            if opaque(img, x, y):
                return y
    return 0


def shifted(img, dx, dy):
    out = Image.new("RGBA", img.size, (0, 0, 0, 0))
    out.paste(img, (dx, dy), img)
    return out


def shear_rows(img, y0, y1, fn):
    """Desplaza cada fila y0..y1 horizontalmente fn(y) pixeles (inclinar la cabeza)."""
    out = img.copy()
    clear(out, 0, y0, 31, y1)
    for y in range(y0, y1 + 1):
        d = fn(y)
        for x in range(32):
            if opaque(img, x, y):
                put(out, x + d, y, img.getpixel((x, y)))
    return out


# ---------------------------------------------------------------- PITOCLES
P = {k: hexc(v) for k, v in dict(
    out="#0d0b0f", skin="#ff9f9a", skinl="#fbb4ab", skind="#a4686a", gold="#ffc93c",
    goldl="#fbd267", goldd="#a48132", goldk="#a46f32", white="#fff1d6", red="#ff4848",
    redl="#fb7570", redd="#a43439").items()}


def pitocles_back(img):
    dy = top_row(img) - 5
    out = img.copy()
    # cogote del casco: la cara desaparece bajo el bronce
    for y in range(22, 28):
        for x in range(9, 24):
            if opaque(out, x, y + dy):
                put(out, x, y + dy, P["gold"] if y < 26 else (P["goldl"] if y == 26 else P["goldd"]))
    for y in range(28, 34):  # nuca: sin boca
        for x in range(10, 24):
            if opaque(out, x, y + dy) and out.getpixel((x, y + dy)) in (P["out"], P["white"]):
                put(out, x, y + dy, P["skin"])
    # cresta de cola de caballo que cuelga por detras
    for i, y in enumerate(range(21 + dy, 26 + dy)):
        put(out, 17, y, P["red"] if i % 2 == 0 else P["redd"])
        put(out, 16, y, P["redl"])
    return out


def pitocles_arms_crossed(img, raise_brow=False):
    out = img.copy()
    clear(out, 25, 31, 29, 41)  # brazo derecho suelto
    # antebrazos cruzados sobre el pecho
    for x in range(10, 24):
        put(out, x, 35, BLACK)
        put(out, x, 36, P["skin"] if x % 5 else P["skinl"])
        put(out, x, 37, P["skind"])
        put(out, x, 38, BLACK)
    for y in (35, 36, 37, 38):
        put(out, 9, y, BLACK)
        put(out, 24, y, BLACK)
    put(out, 8, 36, P["skinl"])
    put(out, 25, 36, P["skinl"])
    if raise_brow:
        for x in range(20, 24):
            put(out, x, 21, BLACK)
        for x in range(14, 18):  # el otro ojo, mirando de reojo y harto
            put(out, x, 24, P["skind"])
    return out


def pitocles_polish(img, f):
    """Gesto: pule el casco con un trapo (brazo arriba, frotando; destello al final)."""
    out = img.copy()
    clear(out, 25, 31, 29, 41)
    sway = (0, 1, 2, 1)[f]
    # brazo que sube por el costado hasta el casco
    for y in range(18, 37):
        put(out, 25, y, BLACK)
        put(out, 26, y, P["skin"])
        put(out, 27, y, P["skin"])
        put(out, 28, y, P["skind"] if y > 22 else P["skin"])
        put(out, 29, y, BLACK)
    rect(out, 25, 16, 28, 17, P["skinl"])  # puno
    # trapo sobre el casco
    for x in range(21 + sway, 26 + sway):
        put(out, x, 14, P["white"])
        put(out, x, 15, P["white"])
    put(out, 20 + sway, 14, BLACK)
    if f == 3:  # destello
        for (x, y) in ((17, 8), (16, 9), (18, 9), (17, 10), (15, 8), (19, 8)):
            put(out, x, y, P["white"])
    return out


# ---------------------------------------------------------------- VULVALQUIRIA
V = {k: hexc(v) for k, v in dict(
    body="#e444b6", bodyl="#e872bf", bodyd="#94327b", gold="#fbd267", goldd="#d9a94a",
    belt="#93d0f4", pink="#fbb5c0", pinkd="#ffa0b8", out="#0d0b0f", dark="#7c2c69").items()}


def vulva_back(img):
    dy = top_row(img, 14, 18) - 12
    out = img.copy()
    for y in range(22, 31):  # sin cara
        for x in range(9, 23):
            if opaque(out, x, y + dy) and out.getpixel((x, y + dy)) not in (V["body"], V["bodyl"]):
                put(out, x, y + dy, V["body"])
    for y in range(31, 38):  # sin panza
        for x in range(12, 20):
            if opaque(out, x, y + dy):
                put(out, x, y + dy, V["body"])
    for y in range(38, 40):
        for x in range(14, 18):
            if opaque(out, x, y + dy) and out.getpixel((x, y + dy)) not in (BLACK,):
                put(out, x, y + dy, V["bodyl"])
    # trenza central
    for i, y in enumerate(range(21, 37)):
        a, b = (V["gold"], V["goldd"]) if i % 2 == 0 else (V["goldd"], V["gold"])
        put(out, 14, y + dy, a)
        put(out, 15, y + dy, b)
        put(out, 16, y + dy, a)
        put(out, 13, y + dy, BLACK)
        put(out, 17, y + dy, BLACK)
    for x in (14, 15, 16):
        put(out, x, 37 + dy, V["belt"])
        put(out, x, 38 + dy, BLACK)
    return out


def vulva_hips(img, brow=False):
    out = img.copy()
    # codos hacia afuera, manos en la cintura
    clear(out, 3, 28, 8, 40)
    clear(out, 24, 28, 29, 40)
    for (cx, sgn) in ((7, -1), (24, 1)):
        for k in range(4):
            y = 30 + k
            x = cx + sgn * (3 - k // 2 if k < 3 else 1)
            x = cx + sgn * (2 if k < 2 else 1)
        # brazo: forma de V invertida (codo afuera)
        pts = [(cx + sgn * 3, 29), (cx + sgn * 4, 30), (cx + sgn * 4, 31), (cx + sgn * 3, 32),
               (cx + sgn * 2, 33), (cx + sgn * 1, 34)]
        for (x, y) in pts:
            put(out, x, y, V["body"])
            put(out, x + sgn, y, BLACK)
            put(out, x - sgn, y, V["bodyl"])
            put(out, x, y - 1, BLACK) if y == 29 else None
        put(out, cx + sgn * 1, 34, V["pink"])
    if brow:
        for x in range(19, 23):
            put(out, x, 21, BLACK)
        for x in range(11, 14):
            put(out, x, 23, V["bodyd"])
    return out


def vulva_braid(img, f):
    """Gesto: se acomoda la trenza (la mano sube hasta el mechon, que se balancea)."""
    out = img.copy()
    clear(out, 24, 28, 29, 40)
    sway = (0, 1, 1, 0)[f]
    ytop = (30, 27, 24, 27)[f]
    for y in range(ytop, 36):  # brazo derecho levantado
        put(out, 25, y, BLACK)
        put(out, 26, y, V["body"])
        put(out, 27, y, V["bodyl"])
        put(out, 28, y, BLACK)
    put(out, 26, ytop - 1, BLACK)
    put(out, 27, ytop - 1, BLACK)
    put(out, 26, ytop, V["pink"])
    put(out, 27, ytop, V["pink"])
    # mechon dorado que cae junto a la mano
    for y in range(ytop, ytop + 6):
        put(out, 24 + sway, y, V["gold"] if y % 2 else V["goldd"])
    return out


# ---------------------------------------------------------------- ORNITORRINCO
O = {k: hexc(v) for k, v in dict(
    body="#5c968c", bodyl="#86aea1", bodyd="#426362", belly="#d6dac4", bellyd="#dedec9",
    beak="#ff8a3c", beakl="#fba567", beakd="#8d502f", nostril="#a45c32", white="#fff1d6",
    tail="#d68046", taill="#de9e6e", taild="#8b5638", out="#0d0b0f").items()}


def platy_clean(img, dy):
    """Quita pico, cola y facciones del perfil; deja cuerpo, sombrero y piernas."""
    out = img.copy()
    clear(out, 0, 30 + dy, 9, 44 + dy)  # cola
    for y in range(19 + dy, 31 + dy):  # cara y pico
        for x in range(9, 31):
            if opaque(out, x, y):
                c = out.getpixel((x, y))
                if x >= 20 or c in (O["white"], O["out"], O["beak"], O["beakl"]):
                    out.putpixel((x, y), (0, 0, 0, 0) if x >= 21 else O["body"])
    # la cabeza vuelve a cerrarse a la derecha con contorno (cara ancha de frente)
    for y in range(21 + dy, 30 + dy):
        put(out, 20, y, O["body"])
        put(out, 21, y, BLACK)
        put(out, 9, y, O["body"])
        put(out, 8, y, BLACK)
    for x in range(8, 22):
        pass
    return out


def platy_mirror_arm(img, dy):
    """Copia el brazo derecho (x>=24) al lado izquierdo para la vista de frente/espalda."""
    out = img.copy()
    for y in range(30 + dy, 42 + dy):
        for x in range(23, 31):
            if opaque(img, x, y):
                mx = 31 - x
                if not opaque(out, mx, y):
                    put(out, mx, y, img.getpixel((x, y)))
    return out


def platy_front(img, look=0, open_beak=False, tilt=0):
    dy = top_row(img, 14, 18) - 11
    out = platy_clean(img, dy)
    out = platy_mirror_arm(out, dy)
    # barriga de frente
    for y in range(31 + dy, 40 + dy):
        for x in range(12, 20):
            if opaque(out, x, y):
                put(out, x, y, O["belly"] if (x + y) % 7 else O["bellyd"])
    # ojos al frente
    for ex in (11, 17):
        for yy in range(21, 24):
            for xx in range(ex, ex + 3):
                put(out, xx + look, yy + dy, O["white"])
        put(out, ex + 1 + look, 22 + dy, BLACK)
        put(out, ex + 1 + look, 23 + dy, BLACK)
        put(out, ex + look, 20 + dy, BLACK)
        put(out, ex + 1 + look, 20 + dy, BLACK)
        put(out, ex + 2 + look, 20 + dy, BLACK)
    # pico plano y ancho, centrado
    rows = [(12, 18, O["beakl"]), (11, 19, O["beak"]), (11, 19, O["beak"]), (12, 18, O["beakd"])]
    for i, (a, b, c) in enumerate(rows):
        y = 25 + i + dy
        for x in range(a + look, b + 1 + look):
            put(out, x, y, c)
        put(out, a - 1 + look, y, BLACK)
        put(out, b + 1 + look, y, BLACK)
    for x in range(12 + look, 19 + look):
        put(out, x, 24 + dy, BLACK)
        put(out, x, 29 + dy, BLACK)
    put(out, 13 + look, 26 + dy, O["nostril"])
    put(out, 17 + look, 26 + dy, O["nostril"])
    if open_beak:
        for x in range(13 + look, 18 + look):
            put(out, x, 27 + dy, BLACK)
            put(out, x, 28 + dy, O["beakd"])
    if tilt:
        out = shear_rows(out, 11 + dy, 30 + dy, lambda y: round((27 + dy - y) * tilt))
    return out


def platy_back(img):
    dy = top_row(img, 14, 18) - 11
    out = platy_clean(img, dy)
    out = platy_mirror_arm(out, dy)
    for y in range(31 + dy, 41 + dy):  # espalda: sin barriga
        for x in range(10, 22):
            if opaque(out, x, y) and out.getpixel((x, y)) in (O["belly"], O["bellyd"], O["bodyl"], O["bodyd"], O["body"]):
                put(out, x, y, O["body"] if (x + y) % 5 else O["bodyl"])
    # cola de castor grande, cuadriculada, cayendo por la espalda
    for y in range(33 + dy, 43 + dy):
        w = 5 if y < 41 + dy else 3
        for x in range(16 - w, 16 + w):
            put(out, x, y, O["tail"] if (x + y) % 3 else O["taill"])
        put(out, 16 - w - 1, y, BLACK)
        put(out, 16 + w, y, BLACK)
    for x in range(12, 20):
        put(out, x, 43 + dy, BLACK)
        put(out, x, 32 + dy, O["taild"])
    return out


# ---------------------------------------------------------------- generacion
def save(h, name, img):
    img.save(PLAYER / h / f"{name}.png")


def build():
    out = {h: {} for h in HEROES}
    walks = [load("pitocles", f"walk_{i:02d}") for i in range(6)]
    # pitocles
    for i in range(6):
        out["pitocles"][f"walkup_{i:02d}"] = pitocles_back(walks[i])
    for i in range(4):
        out["pitocles"][f"idleup_{i:02d}"] = pitocles_back(load("pitocles", f"idle_{i:02d}"))
    b = load("pitocles", "idle_00")
    c1 = pitocles_arms_crossed(b)
    c2 = pitocles_arms_crossed(b, True)
    out["pitocles"]["camera_00"] = b
    out["pitocles"]["camera_01"] = c1
    out["pitocles"]["camera_02"] = c2
    out["pitocles"]["camera_03"] = shifted(c2, 0, 1)
    for f in range(4):
        out["pitocles"][f"gesture_{f:02d}"] = pitocles_polish(b, f)
    # vulvalquiria
    for i in range(6):
        out["vulvalquiria"][f"walkup_{i:02d}"] = vulva_back(load("vulvalquiria", f"walk_{i:02d}"))
    for i in range(4):
        out["vulvalquiria"][f"idleup_{i:02d}"] = vulva_back(load("vulvalquiria", f"idle_{i:02d}"))
    b = load("vulvalquiria", "idle_00")
    h1 = vulva_hips(b)
    h2 = vulva_hips(b, True)
    out["vulvalquiria"]["camera_00"] = b
    out["vulvalquiria"]["camera_01"] = h1
    out["vulvalquiria"]["camera_02"] = h2
    out["vulvalquiria"]["camera_03"] = shifted(h2, 0, 1)
    for f in range(4):
        out["vulvalquiria"][f"gesture_{f:02d}"] = vulva_braid(b, f)
    # ornitorrinco
    for i in range(6):
        w = load("ornitorrinco", f"walk_{i:02d}")
        out["ornitorrinco"][f"walkdown_{i:02d}"] = platy_front(w)
        out["ornitorrinco"][f"walkup_{i:02d}"] = platy_back(w)
    for i in range(4):
        w = load("ornitorrinco", f"idle_{i:02d}")
        out["ornitorrinco"][f"idledown_{i:02d}"] = platy_front(w)
        out["ornitorrinco"][f"idleup_{i:02d}"] = platy_back(w)
    b = load("ornitorrinco", "idle_00")
    out["ornitorrinco"]["camera_00"] = platy_front(b)
    out["ornitorrinco"]["camera_01"] = platy_front(b, tilt=0.12)
    out["ornitorrinco"]["camera_02"] = platy_front(b, tilt=0.22)
    out["ornitorrinco"]["camera_03"] = platy_front(b, tilt=0.22, open_beak=True)
    out["ornitorrinco"]["gesture_00"] = platy_front(b, look=-2)
    out["ornitorrinco"]["gesture_01"] = platy_front(b)
    out["ornitorrinco"]["gesture_02"] = platy_front(b, look=2)
    out["ornitorrinco"]["gesture_03"] = platy_front(b, open_beak=True)
    return out


# animacion: (cuadros, velocidad, loop). Los nombres de cuadro son archivos del heroe.
def anim_table(h):
    n = lambda p, k: [f"{p}_{i:02d}" for i in range(k)]
    t = {
        "idle": (n("idle", 4), 6.0, True),
        "walk": (n("walk", 6), 10.0, True),
        "attack": (n("attack", 4), 14.0, False),
        "dash": (n("dash", 3), 12.0, True),
        "hurt": (n("hurt", 3), 10.0, False),
        "death": (n("death", 6), 8.0, False),
        "walk_up": (n("walkup", 6), 10.0, True),
        "idle_up": (n("idleup", 4), 6.0, True),
        "camera": (["camera_00", "camera_01", "camera_02", "camera_03", "camera_03", "camera_02", "camera_03"], 5.0, False),
        "gesture": (n("gesture", 4), 5.0, True),
    }
    if h == "ornitorrinco":
        t["walk_down"] = (n("walkdown", 6), 10.0, True)
        t["idle_down"] = (n("idledown", 4), 6.0, True)
    else:  # ya estan de frente: reusan los cuadros de siempre
        t["walk_down"] = (n("walk", 6), 10.0, True)
        t["idle_down"] = (n("idle", 4), 6.0, True)
    return t


def read_base_anims(h):
    """Velocidades/loops reales de las animaciones existentes (para no cambiarlas)."""
    import re
    txt = (PLAYER / h / "sprite_frames.tres").read_text()
    res = {}
    for m in re.finditer(r'"loop": (true|false),\n"name": &"(\w+)",\n"speed": ([\d.]+)', txt):
        res[m.group(2)] = (m.group(1) == "true", float(m.group(3)))
    return res


def write_tres(h):
    base = read_base_anims(h)
    table = anim_table(h)
    for k, (loop, spd) in base.items():
        if k in table:
            fr, _, _ = table[k]
            table[k] = (fr, spd, loop)
    names = []
    for fr, _, _ in table.values():
        for f in fr:
            if f not in names:
                names.append(f)
    ids = {f: f"{i + 1}_{f.replace('_', '')}" for i, f in enumerate(names)}
    lines = ["[gd_resource type=\"SpriteFrames\" format=3]", ""]
    for f in names:
        lines.append(f'[ext_resource type="Texture2D" path="res://assets/sprites/player/{h}/{f}.png" id="{ids[f]}"]')
    lines += ["", "[resource]", "animations = [" ]
    blocks = []
    for name, (fr, spd, loop) in table.items():
        fl = ", ".join('{\n"duration": 1.0,\n"texture": ExtResource("%s")\n}' % ids[f] for f in fr)
        blocks.append('{\n"frames": [%s],\n"loop": %s,\n"name": &"%s",\n"speed": %.1f\n}' % (fl, "true" if loop else "false", name, spd))
    lines.append(", ".join(blocks) + "]")
    (PLAYER / h / "sprite_frames.tres").write_text("\n".join(lines) + "\n")


def preview(frames, path):
    names = ["walkup_00", "walkup_03", "idleup_00", "camera_01", "camera_02", "camera_03",
             "gesture_00", "gesture_01", "gesture_02", "gesture_03"]
    sheet = Image.new("RGBA", (32 * 12 * 1, 48 * 3 * 1 + 48), (70, 70, 84, 255))
    for r, h in enumerate(HEROES):
        x = 0
        extra = ["walkdown_00", "walkdown_03"] if h == "ornitorrinco" else ["walk_00", "walk_03"]
        for nme in extra + names:
            im = frames[h].get(nme) or load(h, nme)
            sheet.alpha_composite(im, (x * 32, r * 48))
            x += 1
    sheet.resize((sheet.width * 4, sheet.height * 4), Image.NEAREST).save(path)


def main():
    frames = build()
    for h, d in frames.items():
        for name, img in d.items():
            save(h, name, img)
        write_tres(h)
    if "--preview" in sys.argv:
        preview(frames, sys.argv[sys.argv.index("--preview") + 1])
    print("ok")


if __name__ == "__main__":
    main()
