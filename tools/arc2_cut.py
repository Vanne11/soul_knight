"""Recorte de hojas de Gemini sobre fondo verde plano: quita el fondo y separa cada pose (componentes).

cells(path) -> lista de (indice, imagen RGBA recortada, caja) ordenada por filas (y) y luego por x.
debug(path, out) guarda la hoja con el indice de cada pose para elegir a mano (CELLS en gen_arcoiria_art2.py).
"""
import numpy as np
from PIL import Image, ImageDraw, ImageFilter


def key_mask(rgb: np.ndarray) -> np.ndarray:
    r, g, b = rgb[:, :, 0].astype(int), rgb[:, :, 1].astype(int), rgb[:, :, 2].astype(int)
    return (g > 110) & (g - np.maximum(r, b) > 70)


def cut_bg(im: Image.Image) -> Image.Image:
    """Quita el verde conectado a los bordes (no toca el verde interior del dibujo) y el halo."""
    a = np.array(im.convert("RGB"))
    m = key_mask(a)
    h, w = m.shape
    seen = np.zeros_like(m)
    stack = [(0, x) for x in range(w)] + [(h - 1, x) for x in range(w)] + [(y, 0) for y in range(h)] + [(y, w - 1) for y in range(h)]
    while stack:
        y, x = stack.pop()
        if y < 0 or x < 0 or y >= h or x >= w or seen[y, x] or not m[y, x]:
            continue
        seen[y, x] = True
        stack += [(y + 1, x), (y - 1, x), (y, x + 1), (y, x - 1)]
    # halo: verde mezclado con el borde
    soft = (a[:, :, 1].astype(int) > np.maximum(a[:, :, 0], a[:, :, 2]).astype(int) + 40)
    grow = np.array(Image.fromarray((seen * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(5))) > 0
    seen = seen | (grow & soft)
    tight = (a[:, :, 1].astype(int) > 190) & (a[:, :, 0] < 100) & (a[:, :, 2] < 100)  # agujeros cerrados (asa de la etiqueta)
    seen = seen | tight
    alpha = (~seen).astype(np.uint8) * 255
    alpha = np.array(Image.fromarray(alpha).filter(ImageFilter.MinFilter(3)))  # come 1 px de halo
    out = np.dstack([a, alpha])
    return Image.fromarray(out, "RGBA")


MASKS = {}


def components(alpha: np.ndarray, gap: int = 14, minsize: int = 400):
    """Cajas de las poses: componentes del alfa tras dilatar `gap` px (junta efectos sueltos con su pose)."""
    h, w = alpha.shape
    s = 4
    small = (np.array(Image.fromarray(alpha).resize((w // s, h // s), Image.BOX)) > 40)
    d = np.array(Image.fromarray(small.astype(np.uint8) * 255).filter(ImageFilter.MaxFilter(2 * (gap // s) + 1))) > 0
    lab = np.zeros(d.shape, int)
    n = 0
    boxes = []
    for y0 in range(d.shape[0]):
        for x0 in range(d.shape[1]):
            if d[y0, x0] and not lab[y0, x0]:
                n += 1
                st = [(y0, x0)]
                lab[y0, x0] = n
                ys, xs = [], []
                while st:
                    y, x = st.pop()
                    ys.append(y)
                    xs.append(x)
                    for yy, xx in ((y + 1, x), (y - 1, x), (y, x + 1), (y, x - 1)):
                        if 0 <= yy < d.shape[0] and 0 <= xx < d.shape[1] and d[yy, xx] and not lab[yy, xx]:
                            lab[yy, xx] = n
                            st.append((yy, xx))
                box = (min(xs) * s, min(ys) * s, (max(xs) + 1) * s, (max(ys) + 1) * s)
                if small[min(ys):max(ys) + 1, min(xs):max(xs) + 1].sum() * s * s >= minsize:
                    boxes.append(box)
                    MASKS[box] = (lab == n)
    return boxes


def cells(path, gap: int = 14, row_tol: float = 0.5):
    im = cut_bg(Image.open(path))
    al = np.array(im)[:, :, 3]
    boxes = components(al, gap)
    # filas: agrupa por centro y; dentro de cada fila, por x
    boxes.sort(key=lambda b: (b[1] + b[3]) / 2)
    rows = []
    for b in boxes:
        cy = (b[1] + b[3]) / 2
        hh = b[3] - b[1]
        if rows and abs(cy - rows[-1][0]) < hh * row_tol:
            rows[-1][1].append(b)
            rows[-1][0] = (rows[-1][0] * (len(rows[-1][1]) - 1) + cy) / len(rows[-1][1])
        else:
            rows.append([cy, [b]])
    out = []
    for _, bs in rows:
        for b in sorted(bs, key=lambda b: b[0]):
            c = im.crop(b)
            mk = MASKS.get(b)
            if mk is not None:  # solo los pixeles de ESTA pose (las cajas de poses vecinas se pisan)
                full = np.array(Image.fromarray(mk[b[1] // 4:b[3] // 4, b[0] // 4:b[2] // 4].astype(np.uint8) * 255).resize(c.size, Image.NEAREST)) > 0
                ca = np.array(c)
                ca[:, :, 3] = np.where(full, ca[:, :, 3], 0)
                c = Image.fromarray(ca, 'RGBA')
            out.append((len(out), c, b))
    return im, out


def debug(path, dest, gap: int = 14):
    im, cs = cells(path, gap)
    bg = Image.new("RGBA", im.size, (60, 60, 90, 255))
    bg.alpha_composite(im)
    d = ImageDraw.Draw(bg)
    for i, _, b in cs:
        d.rectangle(b, outline=(255, 255, 0, 255), width=2)
        d.text((b[0] + 4, b[1] + 2), str(i), fill=(255, 255, 255, 255))
    bg.convert("RGB").save(dest)
    return cs


def main_blob(im, gap: int = 24):
    """Se queda solo con la pose mas grande de un recorte por caja (quita pedazos de las poses vecinas)."""
    w, h = im.size
    pad = Image.new("RGBA", (w + (-w) % 4, h + (-h) % 4), (0, 0, 0, 0))
    pad.paste(im, (0, 0))
    al = np.array(pad)[:, :, 3]
    MASKS.clear()
    boxes = components(al, gap, minsize=50)
    if not boxes:
        return im
    best = max(boxes, key=lambda b: MASKS[b].sum())
    full = np.array(Image.fromarray(MASKS[best].astype(np.uint8) * 255).resize(pad.size, Image.NEAREST)) > 0
    a = np.array(pad)
    a[:, :, 3] = np.where(full, a[:, :, 3], 0)
    return Image.fromarray(a, "RGBA").crop((0, 0, w, h))
