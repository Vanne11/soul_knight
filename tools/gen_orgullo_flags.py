#!/usr/bin/env python3
"""Iconos pixel art (48x32) de las banderas del Orgullo para el codice: assets/sprites/codex/orgullo/<id>.png.

Colores en hex segun las fuentes citadas en datos_orgullo.md (los marcados REVISAR alli son los
valores de uso comun, no oficiales). Uso: python3 tools/gen_orgullo_flags.py
"""
from pathlib import Path
from PIL import Image, ImageDraw

OUT = Path(__file__).resolve().parent.parent / "assets/sprites/codex/orgullo"
W, H = 48, 32
EDGE = "#1a0b26"
SIX = ["#E40303", "#FF8C00", "#FFED00", "#008026", "#004DFF", "#750787"]

# franjas iguales, de arriba abajo
FLAGS = {
    "bandera_arcoiris": ["#FF69B4", "#FF0000", "#FF8E00", "#FFFF00", "#008E00", "#00C0C0", "#400098", "#8E008E"],
    "bandera_trans": ["#5BCEFA", "#F5A9B8", "#FFFFFF", "#F5A9B8", "#5BCEFA"],
    "bandera_lesbica": ["#D52D00", "#EF7627", "#FF9A56", "#FFFFFF", "#D162A4", "#B55690", "#A30262"],
    "bandera_pan": ["#FF218C", "#FFD800", "#21B1FF"],
    "bandera_asexual": ["#000000", "#A3A3A3", "#FFFFFF", "#800080"],
    "bandera_nobinaria": ["#FCF434", "#FFFFFF", "#9C59D1", "#2C2C2C"],
}
IDS = list(FLAGS) + ["bandera_bi", "bandera_intersex", "bandera_progress", "bandera_intersex_inclusiva"]


def stripes(d, colors):
    n = len(colors)
    for i, c in enumerate(colors):
        d.rectangle([0, round(i * H / n), W - 1, round((i + 1) * H / n) - 1], fill=c)


def make(fid):
    img = Image.new("RGB", (W, H), "#000000")
    d = ImageDraw.Draw(img)
    if fid in FLAGS:
        stripes(d, FLAGS[fid])
    elif fid == "bandera_bi":
        # 2/5 magenta, 1/5 lila, 2/5 azul
        d.rectangle([0, 0, W - 1, 12], fill="#D60270")
        d.rectangle([0, 13, W - 1, 18], fill="#9B4F96")
        d.rectangle([0, 19, W - 1, H - 1], fill="#0038A8")
    elif fid == "bandera_intersex":
        d.rectangle([0, 0, W - 1, H - 1], fill="#FFD800")
        d.ellipse([16, 6, 31, 25], outline="#7902AA", width=3)
    else:
        stripes(d, SIX)
        # cuna a la izquierda: blanco, rosa, celeste, marron, negro (de afuera hacia adentro)
        for i, c in enumerate(["#FFFFFF", "#F5A9B8", "#5BCEFA", "#613915", "#000000"]):
            k = 22 - i * 4
            d.polygon([(0, 16 - k), (k * 0.7, 15.5), (0, 15 + k)], fill=c)
        if fid == "bandera_intersex_inclusiva":
            # triangulo amarillo con circulo morado
            d.polygon([(0, 8), (11, 15.5), (0, 23)], fill="#FFD800")
            d.ellipse([1, 12, 7, 19], outline="#7902AA", width=1)
    d.rectangle([0, 0, W - 1, H - 1], outline=EDGE)
    return img


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for fid in IDS:
        make(fid).save(OUT / f"{fid}.png")
        print("ok", fid)


if __name__ == "__main__":
    main()
