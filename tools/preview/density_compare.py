"""Heroe | Cera vieja (80x120 a scale 1.5) | Cera nueva (156x180 a scale 1.0), a la escala real del juego
y ampliados todos x3 con vecino mas cercano para verlos. Uso: python3 tools/preview/density_compare.py <salida.png>"""
import sys
from pathlib import Path
from PIL import Image, ImageDraw

hero = Image.open("assets/sprites/player/pitocles/idle_00.png").convert("RGBA")
old = Image.open(".claude_tmp/cera_old/boss_cera_idle_00.png").convert("RGBA")
old = old.resize((old.width * 3 // 2, old.height * 3 // 2), Image.NEAREST)  # scale 1.5 del .tscn
new = Image.open(".claude_tmp/cera_pose_idle.png").convert("RGBA")
Z = 3
items = [("Heroe (32x48, scale 1)", hero), ("Cera vieja (80x120 x1.5)", old), ("Cera nueva (156x180, scale 1)", new)]
W = sum(i.width for _, i in items) * Z + 40 * (len(items) + 1)
H = max(i.height for _, i in items) * Z + 70
sh = Image.new("RGBA", (W, H), (82, 77, 92, 255))
d = ImageDraw.Draw(sh)
x = 40
for name, im in items:
    big = im.resize((im.width * Z, im.height * Z), Image.NEAREST)
    sh.alpha_composite(big, (x, H - 20 - big.height))
    d.text((x, 8), name, fill=(255, 240, 200, 255))
    x += big.width + 40
sh.convert("RGB").save(sys.argv[1])
