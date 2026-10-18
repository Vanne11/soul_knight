"""Pasada de limpieza y 'acabado indie premium' sobre las poses pixeladas de Cera (156x180).

Lo llama gen_boss_anim_art.pixelate_set. Pasos:
 1. rampas de color con cambio de matiz (sombras hacia violeta/rojo, luces hacia amarillo/crema);
 2. quita islas sueltas de 1-3 px y pixeles huerfanos de ruido (conserva brillos de los ojos);
 3. contorno selectivo: negro-ciruela solo en la silueta exterior; por dentro el contorno toma una
    version oscura del color vecino (rosa -> ciruela, cera -> marron rojizo, moño -> azul noche);
 4. luz arriba-izquierda: borde alto/izquierdo de cada forma mas claro, borde bajo/derecho mas oscuro,
    y brillo especular en la cera.
"""
import numpy as np

# rampas luz -> sombra (cada paso cambia de matiz, no solo de brillo)
PINK = [(255, 178, 214), (255, 118, 186), (246, 75, 163), (208, 56, 148), (154, 42, 124), (104, 32, 98)]
GOLD = [(255, 247, 196), (255, 224, 112), (255, 192, 52), (232, 142, 40), (176, 92, 50), (112, 52, 62)]
TEAL = [(150, 238, 242), (66, 214, 232), (40, 154, 196), (36, 98, 148), (32, 56, 108)]
CREAM = [(255, 252, 236), (255, 238, 206), (238, 200, 172), (200, 152, 156), (150, 104, 134)]
WOOD = [(208, 138, 78), (164, 96, 58), (116, 64, 54), (74, 40, 54)]
GREY = [(235, 240, 244), (190, 196, 214), (134, 138, 160), (84, 84, 112)]
MISC = [(255, 255, 255), (255, 72, 72), (255, 150, 70), (96, 20, 64), (140, 220, 255), (255, 240, 150)]
SIL = (22, 12, 30)  # silueta exterior: casi negro con matiz ciruela
DARK = [(13, 11, 15), (28, 24, 34), (38, 20, 45), SIL]
FAMILIES = {"pink": PINK, "gold": GOLD, "teal": TEAL, "cream": CREAM, "wood": WOOD, "grey": GREY}
PALETTE = [c for f in FAMILIES.values() for c in f] + MISC + DARK
FAM_OF = {c: n for n, f in FAMILIES.items() for c in f}
# color del contorno interior segun la familia del vecino
INNER = {"pink": PINK[5], "gold": GOLD[5], "teal": TEAL[4], "cream": CREAM[4], "wood": WOOD[3], "grey": GREY[3]}


def _is_dark(c):
    return c in DARK


def remap(a):
    pal = np.array(PALETTE, dtype=np.int32)
    rgb = a[:, :, :3].astype(np.int32)
    d = ((rgb[:, :, None, :] - pal[None, None, :, :]) ** 2 * np.array([2, 4, 3])).sum(-1)
    q = pal[d.argmin(-1)].astype(np.uint8)
    alpha = np.where(a[:, :, 3] >= 110, 255, 0).astype(np.uint8)
    return np.dstack([q, alpha])


def _nb4(h, w, y, x):
    return [(y - 1, x), (y + 1, x), (y, x - 1), (y, x + 1)]


def finish(a):
    """a: array RGBA (h, w, 4) ya reducido. Devuelve el acabado."""
    a = remap(a)
    h, w = a.shape[:2]

    def at(y, x):
        if 0 <= y < h and 0 <= x < w and a[y, x, 3]:
            return tuple(int(v) for v in a[y, x, :3])
        return None

    # 1) islas pequenas de alfa (8-vecinos)
    seen = np.zeros((h, w), bool)
    for y in range(h):
        for x in range(w):
            if a[y, x, 3] and not seen[y, x]:
                comp, st = [], [(y, x)]
                seen[y, x] = True
                while st:
                    cy, cx = st.pop()
                    comp.append((cy, cx))
                    for dy in (-1, 0, 1):
                        for dx in (-1, 0, 1):
                            ny, nx = cy + dy, cx + dx
                            if 0 <= ny < h and 0 <= nx < w and a[ny, nx, 3] and not seen[ny, nx]:
                                seen[ny, nx] = True
                                st.append((ny, nx))
                if len(comp) < 4:
                    for cy, cx in comp:
                        a[cy, cx, 3] = 0
    # 2) huerfanos: pixel sin ningun vecino (4) de su color, parecido al color dominante alrededor
    for _ in range(2):
        for y in range(h):
            for x in range(w):
                c = at(y, x)
                if c is None:
                    continue
                if any(at(*p) == c for p in _nb4(h, w, y, x)):
                    continue
                cnt = {}
                for dy in (-1, 0, 1):
                    for dx in (-1, 0, 1):
                        n = at(y + dy, x + dx)
                        if n is not None and (dy or dx):
                            cnt[n] = cnt.get(n, 0) + 1
                if not cnt:
                    continue
                m = max(cnt, key=cnt.get)
                dist = sum((c[i] - m[i]) ** 2 for i in range(3)) ** 0.5
                if cnt[m] >= 4 and dist < 110 and not (c == (255, 255, 255)):
                    a[y, x, :3] = m
    # 3) contorno selectivo
    new = a.copy()
    for y in range(h):
        for x in range(w):
            c = at(y, x)
            if c is None or not _is_dark(c):
                continue
            outside = any(not (0 <= py < h and 0 <= px < w) or not a[py, px, 3] for py, px in _nb4(h, w, y, x))
            if outside:
                new[y, x, :3] = SIL
                continue
            fam = {}
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    n = at(y + dy, x + dx)
                    if n in FAM_OF and n != (255, 255, 255):
                        fam[FAM_OF[n]] = fam.get(FAM_OF[n], 0) + 1
            if fam:
                f = max(fam, key=fam.get)
                if f not in ("grey",) and fam[f] >= 3:
                    new[y, x, :3] = INNER[f]
    a = new
    # 4) luz arriba-izquierda: bordes claros arriba/izquierda, oscuros abajo/derecha (1 px)
    new = a.copy()

    def fam_idx(c):
        f = FAM_OF.get(c)
        return (f, FAMILIES[f].index(c)) if f else (None, -1)

    for y in range(h):
        for x in range(w):
            c = at(y, x)
            f, i = fam_idx(c) if c else (None, -1)
            if f not in ("pink", "gold", "cream"):
                continue
            ramp = FAMILIES[f]
            up, left, down, right = at(y - 1, x), at(y, x - 1), at(y + 1, x), at(y, x + 1)
            edge_ul = (up is not None and _is_dark(up)) or (left is not None and _is_dark(left))
            edge_dr = (down is not None and _is_dark(down)) or (right is not None and _is_dark(right))
            mid = 2 if f != "cream" else 1
            if edge_ul and not edge_dr and i == mid:
                new[y, x, :3] = ramp[mid - 1]
            elif edge_dr and not edge_ul and i == mid:
                new[y, x, :3] = ramp[mid + 1]
    a = new
    # brillo especular de la cera: parches claros en los bordes altos de las gotas/borde dorado
    for y in range(1, h - 1):
        for x in range(1, w - 2):
            c = at(y, x)
            if c in (GOLD[1], GOLD[2]) and at(y - 1, x) is not None and _is_dark(at(y - 1, x)) and at(y, x + 1) in (GOLD[1], GOLD[2]):
                a[y, x, :3] = GOLD[0]
    return a
