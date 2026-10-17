"""Calcula donde esta la mano de cada heroe en cada cuadro de animacion.

Uso: python3 tools/gen_hand_anchors.py [--preview carpeta]
Escribe assets/data/hand_anchors.json: {personaje: {animacion: [[x, y], ...]}} en pixeles
del cuadro (origen arriba a la izquierda, mirando a la derecha). player.gd cuelga el arma
de ese punto en cada cuadro, asi sigue el vaiven del caminar y el golpe del ataque.
La mano es el pixel opaco mas adelantado (derecha) en la franja de los brazos; se
promedia la altura de ese borde para no engancharse en un pixel suelto.
"""
import json
import sys
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
PLAYER = ROOT / "assets/sprites/player"
OUT = ROOT / "assets/data/hand_anchors.json"
ANIMS = ["idle", "walk", "attack", "dash", "hurt", "death"]
# Franja vertical de los brazos (fraccion de la altura del cuadro) por personaje: por
# encima quedan pico, trenzas y casco; por debajo, las piernas.
BAND = {"pitocles": (0.62, 0.88), "vulvalquiria": (0.55, 0.80), "ornitorrinco": (0.68, 0.86)}


def anchor(img: Image.Image, band) -> list:
    a = img.split()[3]
    w, h = img.size
    y0, y1 = int(h * band[0]), int(h * band[1])
    best_x, rows = -1, []
    for y in range(y0, y1):
        xs = [x for x in range(w) if a.getpixel((x, y)) > 128]
        if not xs:
            continue
        x = max(xs)
        if x > best_x:
            best_x, rows = x, [y]
        elif x == best_x:
            rows.append(y)
    if best_x < 0:
        return [w // 2 + 6, int(h * 0.7)]
    # un pixel hacia dentro: el arma se agarra con el puno, no con su borde
    return [best_x - 1, round(sum(rows) / len(rows))]


def main():
    preview = None
    if "--preview" in sys.argv:
        preview = Path(sys.argv[sys.argv.index("--preview") + 1])
        preview.mkdir(parents=True, exist_ok=True)
    data = {}
    for ch_dir in sorted(p for p in PLAYER.iterdir() if p.is_dir()):
        ch = ch_dir.name
        band = BAND.get(ch, (0.6, 0.85))
        data[ch] = {}
        sheet = []
        for an in ANIMS:
            frames = sorted(ch_dir.glob(f"{an}_[0-9][0-9].png"))
            pts = []
            for f in frames:
                img = Image.open(f).convert("RGBA")
                p = anchor(img, band)
                pts.append(p)
                if preview:
                    big = img.resize((img.width * 4, img.height * 4), Image.NEAREST)
                    d = ImageDraw.Draw(big)
                    cx, cy = p[0] * 4 + 2, p[1] * 4 + 2
                    d.ellipse([cx - 4, cy - 4, cx + 4, cy + 4], outline=(0, 255, 0, 255), width=2)
                    sheet.append(big)
            if pts:
                data[ch][an] = pts
        if preview and sheet:
            c = Image.new("RGBA", (sum(s.width + 4 for s in sheet), sheet[0].height), (60, 60, 70, 255))
            x = 0
            for s in sheet:
                c.paste(s, (x, 0), s)
                x += s.width + 4
            c.save(preview / f"manos_{ch}.png")
    OUT.write_text(json.dumps(data, indent=1))
    print("listo:", OUT.relative_to(ROOT), {k: sum(len(v) for v in d.values()) for k, d in data.items()})


if __name__ == "__main__":
    main()
