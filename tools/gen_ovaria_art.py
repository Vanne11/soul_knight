"""Arte DEFINITIVO de SU MAJESTAD OVARIA II (jefa de Trompas), de sus huevos y de la Cria ovarica con Gemini.
Escribe en assets/sprites/enemies/vulvania/reina_ovaria/ (la carpeta de assets/data/enemy_art.json).

Uso: python3 tools/gen_ovaria_art.py gen [hoja ...]     llama a Gemini (una llamada por hoja, solo las que falten; con nombre, la rehace)
     python3 tools/gen_ovaria_art.py build [parte ...]  recorta, pixela, interpola y escribe PNG + .tres (sin args = todo)
     python3 tools/gen_ovaria_art.py preview DIR        hojas de contacto de las poses recortadas
Hojas (UNA imagen cada una, regla de Nico: nunca cuadro a cuadro), originales en .claude/arte_fuente/ovaria/:
  reina_a reina_b reina_p2 reina_p3 huevo cria          (6 llamadas; el resto del presupuesto de 18 queda para reintentos)
Partes de build: reina (160x180 -> reina_ovaria_sheet{,_p2,_p3}.png + reina_ovaria_sprite_frames{,_p2,_p3}.tres)
                 huevo (64x64 -> ovaria_huevo_sheet.png)   cria (32x48 -> cria_ovarica_*_NN.png + cria_ovarica_sprite_frames.tres)
Densidad: 1 pixel de arte = 1 unidad de juego (como el heroe de 32x48), reduccion con contornos conservados,
paleta corta fija por variante, SIN ampliar (NEAREST). Cuadros intermedios por script (xf), como Dona Cera.
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import arc2_cut as CUT  # noqa: E402
import arc2_gemini as GEM  # noqa: E402
import gen_arcoiria_art2 as A  # noqa: E402
import gen_parra_art2 as PA  # noqa: E402  (cut_bg estricto para fondo verde)
from arc2_gemini import STYLE  # noqa: E402

ROOT = GEM.ROOT
RAW = ROOT / ".claude/arte_fuente/ovaria"
GEM.RAW = RAW
DEST = ROOT / "assets/sprites/enemies/vulvania/reina_ovaria"
RES = "res://assets/sprites/enemies/vulvania/reina_ovaria/"
OLD = DEST / "reina_ovaria_idle_00.png"
CUT.cut_bg = PA.cut_bg  # los personajes de Ovaria son rosados: la clave verde estricta basta

# ------------------------------------------------------------------ prompts
_REINA = (
    "THE BOSS 'Su Majestad Ovaria II' (Her Majesty Ovaria the Second), queen of the fallopian tubes: a big plump "
    "pink OVAL egg-shaped body (an ovary) with a smug regal face: half-closed heavy-lidded eyes with long lashes, "
    "round blush cheeks and a small smirking smile. A tall spiky GOLD CROWN with cyan and pink gems sits on top. "
    "Several cream-white round FOLLICLE spots on her belly. Pink noodle arms with purple gloved hands, a purple "
    "royal gown skirt with a cream hem, tiny yellow shoes. A vain, theatrical, diva queen of the menstrual cycle. "
    "Same character, same proportions, same colors and same design as the reference image(s), but redrawn with much "
    "more detail, richer shading and a premium look. "
)
_ORDER = (
    " All poses are the SAME character at the SAME scale and the same camera, full body visible and grounded, "
    "feet at the bottom of each cell, a single big character per cell, no extra characters except the props named. "
)

PROMPTS = {
    "reina_a": (
        STYLE + "BOSS SPRITE SHEET with exactly 2 rows of 4 large poses (8 poses)." + _ORDER + _REINA +
        "Poses left to right, top row: (1) neutral idle, haughty, one hand on hip; (2) walking step, one foot "
        "forward, skirt swaying; (3) generic attack wind-up, leaning back, arms pulled in, pink energy gathering, "
        "gritted fierce face; (4) LAYING EGGS: crouched slightly, straining with a theatrical push, a small pink "
        "glowing egg dropping out below her skirt. Bottom row: (5) FOLLICLE WIND-UP: both arms raised high over "
        "her crown holding a big glossy pink water-balloon-like follicle ball; (6) FOLLICLE RELEASE: both arms "
        "thrown forward and down, lunging, hurling the balloon, motion lines; (7) CHANNELING A HEALING SPELL: eyes "
        "closed, serene, hands joined in front, a pink glowing aura with tiny sparkles and hearts; (8) HURT: "
        "flinching backwards, eyes squeezed, mouth open in an offended gasp, crown tilting."
    ),
    "reina_b": (
        STYLE + "BOSS SPRITE SHEET with exactly 2 rows of 4 large poses (8 poses), the SAME character as the "
        "reference image (approved design: identical egg body, crown, gown, colors, proportions, art style), only "
        "the pose changes." + _ORDER + _REINA +
        "Poses left to right, top row: (1) dramatic INTRO entrance, chin up, arms spread wide, triumphant and "
        "smug, crown gleaming; (2) EXHAUSTED: bent forward, hands on knees, panting, tongue out, sweat drops, "
        "crown crooked, deflated; (3) STUNNED and dizzy, swirly spiral eyes, tiny stars circling her head, arms "
        "limp, crown sliding off, tongue out; (4) SHOCKWAVE RELEASE: arms spread wide, mouth wide open in a big "
        "operatic scream, rings of pink energy radiating from her body. Bottom row, a theatrical DEATH in four "
        "steps: (5) clutching her chest with one hand, back of the hand on her forehead, a dramatic faint, crown "
        "flying up; (6) falling backwards, off-balance, eyes closed; (7) lying flat on her back on the ground, "
        "X eyes, arms spread, the crown rolling beside her; (8) the same lying pose with a cracked shell, a "
        "little white flag raised in one hand, tiny hearts and a tiny ghost floating up."
    ),
    "reina_p2": (
        STYLE + "BOSS SPRITE SHEET with exactly 2 rows of 4 large poses (8 poses). It is the DAMAGED PHASE 2 of "
        "the SAME character as the reference sheet: same poses in the same order and positions as the reference "
        "sheet's top row and bottom row, same design, but now clearly battle-damaged: a crack running across her "
        "oval body, a chipped crown with a missing spike, scuffed torn gown, one smeared eyelash, angrier "
        "narrowed eyes, a sweat drop, slightly deeper red-pink skin with darker shadows and a couple of cracked "
        "follicle spots." + _ORDER + _REINA +
        "Poses left to right, top row: (1) neutral idle, angrier; (2) walking step; (3) attack wind-up; (4) "
        "laying eggs. Bottom row: (5) follicle wind-up, balloon raised; (6) follicle release; (7) channeling a "
        "healing spell, eyes closed; (8) hurt, flinching."
    ),
    "reina_p3": (
        STYLE + "BOSS SPRITE SHEET with exactly 2 rows of 4 large poses (8 poses). It is the HEAVILY DAMAGED, "
        "ENRAGED PHASE 3 of the SAME character as the reference sheet: same poses in the same order as the "
        "reference sheet, same design, but desperate and furious: big cracks across the oval body leaking a "
        "bit of pale yolk, a broken half-melted crown with two spikes snapped off, tattered shredded gown, "
        "messy mascara running down her face in black streaks, wild bulging bloodshot angry eyes, gritted teeth, "
        "a darker, redder angry flushed skin tone, a faint red rage aura, a bandage patch on the belly."
        + _ORDER + _REINA +
        "Poses left to right, top row: (1) neutral idle, panting with rage; (2) walking step; (3) attack "
        "wind-up; (4) laying eggs. Bottom row: (5) follicle wind-up, balloon raised; (6) follicle release; (7) "
        "channeling a healing spell, eyes closed, painfully; (8) hurt, flinching."
    ),
    "huevo": (
        STYLE + "PROP SPRITE SHEET with exactly 1 row of 4 props (4 cells), all the same scale: "
        "(1) a plump glossy pale pink-cream EGG (an ovum), seen in three-quarter top-down view standing upright, a "
        "highlight on the shell and a faint dark-red nucleus glowing through the shell; (2) the same egg ABOUT TO "
        "HATCH: shaking, covered in cracks, a bright red-pink glow leaking through the cracks, tiny motion lines; "
        "(3) the same egg BROKEN: two cracked shell halves open with a gooey pink splash and shell shards "
        "flying, lying on the ground; (4) a BIG ROYAL EGG, the same egg design but twice as large, with a small "
        "gold crown on its top and gold bands around it, glossy and menacing." + _ORDER
    ),
    "cria": (
        STYLE + "ENEMY SPRITE SHEET with exactly 2 rows of 4 small poses (8 poses), the SAME tiny creature at the "
        "same scale in each cell." + _ORDER +
        "THE ENEMY 'Cria Ovarica' (Ovarian Hatchling): a small chubby baby version of the Queen, a tiny round "
        "pale pink egg-shaped chick with a cracked eggshell cap stuck on its head like a hat, big watery sad eyes, "
        "a wobbling mouth, tiny stubby arms and feet, cream spots, crying huge tears. Cute but pathetic, "
        "humorous. Palette: pink, cream, a touch of purple, light blue tears. Poses left to right, top row: (1) "
        "idle standing, sniffling; (2) walking step A; (3) walking step B; (4) wind-up for crying: head tilted back, "
        "mouth wide open, eyes squeezed, about to wail. Bottom row: (5) wailing, leaning forward, a big blue "
        "teardrop projectile flying out of its mouth; (6) hurt, flinching with a flattened body; (7) death part "
        "one: squashed and flattened, the eggshell cap flying off; (8) death part two: popped into a flat puddle "
        "with shell bits and a tiny ghost leaving."
    ),
}
GEN_ORDER = ["reina_a", "reina_b", "reina_p2", "reina_p3", "huevo", "cria"]


def _flat(path, k=4):
    im = Image.open(path).convert("RGBA")
    im = im.resize((im.width * k, im.height * k), Image.NEAREST)
    bg = Image.new("RGBA", im.size, (96, 96, 112, 255))
    bg.alpha_composite(im)
    return bg


def gen(names):
    portrait = Image.open(ROOT / "assets/sprites/ui/bosses/reina_ovaria.png")
    for n in names or GEN_ORDER:
        if (RAW / f"{n}.png").exists() and not names:
            continue
        if n == "reina_a":
            refs = ([_flat(OLD)] if OLD.exists() else []) + [portrait]
        else:
            refs = [Image.open(RAW / "reina_a.png")]
        GEM.generate(n, PROMPTS[n], aspect="16:9", size="2K", refs=refs)
        print("LLAMADA a Gemini:", n)


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "gen":
        gen(sys.argv[2:])
