"""Hojas de contacto y GIFs de las capturas de boss_anim_preview.gd.

Uso: python3 tools/preview/contact_sheet.py <carpeta_capturas> <carpeta_salida>
Genera por grupo (intro, idle, walk, atk_*, tired, channel, hurt, phaseN_*, death) una tira con sus cuadros,
una hoja general 'hoja_despues.png', GIFs animados por grupo y 'antes_vs_despues.png' con las animaciones
viejas (cuadros de .claude_tmp/cera_old) al lado de las nuevas.
"""
import re
import sys
from pathlib import Path

from PIL import Image, ImageDraw

src, dst = Path(sys.argv[1]), Path(sys.argv[2])
dst.mkdir(parents=True, exist_ok=True)
groups = {}
for f in sorted(src.glob("*.png")):
    m = re.match(r"(.+)_(\d\d)\.png$", f.name)
    groups.setdefault(m.group(1), []).append(f)

CELL = (220, 190)


def crop(f):
    im = Image.open(f).convert("RGB")
    im = im.crop((60, 30, 600, 560))
    return im.resize((CELL[0] * 2 // 2, int(CELL[0] * 2 // 2 * im.height / im.width)))


def strip(name, files, per_row=8):
    ims = [crop(f) for f in files]
    w, h = ims[0].size
    rows = (len(ims) + per_row - 1) // per_row
    sh = Image.new("RGB", (w * min(per_row, len(ims)), h * rows + 18), (30, 30, 36))
    ImageDraw.Draw(sh).text((4, 3), name, fill=(255, 230, 150))
    for i, im in enumerate(ims):
        sh.paste(im, ((i % per_row) * w, 18 + (i // per_row) * h))
    return sh, ims


sheets = []
for name, files in groups.items():
    sh, ims = strip(name, files)
    sh.save(dst / f"tira_{name}.png")
    ims[0].save(dst / f"anim_{name}.gif", save_all=True, append_images=ims[1:], duration=110, loop=0)
    sheets.append(sh)
W = max(s.width for s in sheets)
H = sum(s.height for s in sheets)
big = Image.new("RGB", (W, H), (30, 30, 36))
y = 0
for s in sheets:
    big.paste(s, (0, y))
    y += s.height
big.save(dst / "hoja_despues.png")

# antes vs despues: cuadros viejos (x4) al lado de la tira nueva equivalente
old = Path(".claude_tmp/cera_old")
if old.exists():
    rows = [("idle (antes 1 cuadro)", "idle_00", "idle"), ("walk (antes 4)", "walk_00 walk_01 walk_02 walk_03", "walk"),
            ("attack (antes 3, el mismo para todo)", "attack_00 attack_01 attack_02", "atk_tiron"),
            ("hurt (antes 2)", "hurt_00 hurt_01", "hurt"), ("death (antes 4)", "death_00 death_01 death_02 death_03", "death")]
    cw = 8 * crop(groups["idle"][0]).width
    out = Image.new("RGB", (cw + 8, 10), (30, 30, 36))
    tiles = []
    for title, olds, new in rows:
        oims = []
        for o in olds.split():
            im = Image.open(old / f"boss_cera_{o}.png").convert("RGBA")
            bg = Image.new("RGBA", im.size, (82, 77, 92, 255))
            bg.alpha_composite(im)
            oims.append(bg.convert("RGB").resize((im.width * 2, im.height * 2), Image.NEAREST))
        ow = sum(i.width for i in oims)
        nsh, _ = strip("DESPUES: " + new, groups[new])
        h = max(max(i.height for i in oims) + 18, nsh.height)
        t = Image.new("RGB", (ow + nsh.width + 20, h), (30, 30, 36))
        ImageDraw.Draw(t).text((4, 3), "ANTES: " + title, fill=(255, 150, 150))
        x = 0
        for i in oims:
            t.paste(i, (x, 18))
            x += i.width
        t.paste(nsh, (ow + 20, 0))
        tiles.append(t)
    W = max(t.width for t in tiles)
    big = Image.new("RGB", (W, sum(t.height for t in tiles)), (30, 30, 36))
    y = 0
    for t in tiles:
        big.paste(t, (0, y))
        y += t.height
    big.save(dst / "antes_vs_despues.png")
print("ok", len(groups), "grupos")
