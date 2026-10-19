"""Arte de EL TEMPLO DE ANUBIS (reino de ruinas egipcias de la Puerta Trasera) con Gemini: decorado + Frasquito Magico.
Maximo 3 llamadas en total (Nico tiene poco saldo): hoja "decorado" (8 objetos) y hoja "frasquito" (enemigo, 8 poses).

Uso: python3 tools/gen_anubis_art.py gen [hoja ...]    UNA llamada por hoja (solo las que falten)
     python3 tools/gen_anubis_art.py build            recorta, pixela y escribe PNG (+ .tres del enemigo)
Originales en el repo principal .claude/arte_fuente/anubis/ (respaldo en ~/Vídeos/Rogue Reproductive/arte_gemini_original/anubis/).
"""
import shutil
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import gen_pt_contenido_art as PT  # noqa: E402  (maquinaria de enemigos)
import gen_aduanero_art as AD  # noqa: E402  (_sin_rotulo / _sin_astillas)
import gen_testiculo_art as T  # noqa: E402
import arc2_gemini as GEM  # noqa: E402
import gen_arcoiria_art2 as A  # noqa: E402
from arc2_gemini import STYLE  # noqa: E402

ROOT = GEM.ROOT
RAW = Path("/home/nick/Escritorio/Proyectos/soul_knight/.claude/arte_fuente/anubis")
BACKUP = Path.home() / "Vídeos/Rogue Reproductive/arte_gemini_original/anubis"
GEM.RAW = RAW
T.RAW = RAW
DECOR = ROOT / "assets/sprites/environment/decor"

_NOTEXT = (" ABSOLUTELY NO TEXT: never write letters, numbers, words, captions or labels anywhere in the image (hieroglyphs must be "
           "purely decorative pictograms: eyes, birds, wavy water lines, ankh crosses, beetles, no real letters); the bottom of every "
           "cell is empty green.")

FRASQUITO = dict(
    size=(32, 48), idle_h=38,
    body=("THE ENEMY 'Frasquito Magico' (Little Magic Vial): a small squat brown-amber glass VIAL bottle with a screw cap, a plain blank "
          "cream label (no text) with only a small cartoon lightning-wisp icon, a dizzy sly grin with spiral half-lidded eyes, tiny thin "
          "arms and tiny feet, a thin curl of pale yellow-green fumes always rising from the open cap. Mischievous, not scary, a bit "
          "swirly. Palette: amber brown glass, cream label, pale lime-yellow vapor, dark outline."),
    aviso="the cap popped open, a big swirling spiral of pale yellow-green vapor gathering above it, the eyes spinning, body trembling",
    ataque="breathing out a big wavy cloud of pale vapor toward the front, body leaning back, wavy lines in the air",
    m1="wobbling dizzily with spiral eyes, the cap spinning off", m2="tipping over with the last wisps of vapor curling out",
    m3="an empty tipped-over vial lying on its side with a small faint vapor wisp and a tiny star")
PT.ENEMIES["frasquito"] = FRASQUITO

DECOR_PROMPT = (
    "ENVIRONMENT PROP SHEET with exactly 2 rows of 4 items (8 items), each item alone in its own cell, same camera, standing on the "
    "ground (feet at the bottom of the cell), nothing else in the cell. THEME: a ruined ancient Egyptian temple that was dug up as an "
    "archaeological excavation, with a silly bathroom-humor twist, sandy beige, ochre, turquoise and gold palette. Items left to right, "
    "top row: (1) a tall stone STATUE OF ANUBIS: a standing figure with a black jackal head with tall pointed ears, gold collar and "
    "kilt, arms by its sides holding a golden ankh, on a small sandstone plinth, front-facing, stern and noble, weathered; (2) an upright "
    "golden SARCOPHAGUS standing on its end, painted pharaoh face with blue-gold striped headdress and crossed arms, only decorative "
    "stripes on the body; (3) a tall sandstone COLUMN with a lotus-bud capital, one side broken, painted turquoise bands; (4) a tall "
    "sandstone STELE slab with rows of mute pictogram hieroglyphs (eyes, birds, water waves, ankhs, beetles). Bottom row: (5) a standing "
    "MUMMY made of white TOILET PAPER rolls wrapped around a person-shaped figure, a few loose paper tails hanging, two sleepy cartoon "
    "eyes peeking out, comedic; (6) a tall clay AMPHORA jar in terracotta with turquoise and gold painted bands and two small handles; "
    "(7) a WIDE horizontal stone panel (lintel inscription) covered in rows of mute pictogram hieroglyphs in turquoise and gold, "
    "the longest item of the sheet; (8) a fallen broken sandstone column lying on its side on the sand with a few rubble chunks. "
    "Humorous, family-friendly, nothing explicit." + _NOTEXT
)
FRASQUITO_PROMPT = (STYLE + "ENEMY SPRITE SHEET with exactly 2 rows of 4 small poses (8 poses)." + PT._ORDER + FRASQUITO["body"] + PT._TONE
                    + PT._POSES.format(**{k: FRASQUITO[k] for k in ("aviso", "ataque", "m1", "m2", "m3")}))
PROMPTS = {"decorado": STYLE.replace("Characters face RIGHT in a three-quarter top-down game view. ", "") + DECOR_PROMPT,
           "frasquito": FRASQUITO_PROMPT}


def gen(names):
    for n in names or list(PROMPTS):
        if (RAW / f"{n}.png").exists() and not names:
            continue
        print("LLAMADA a Gemini:", n, flush=True)
        GEM.generate(n, PROMPTS[n], aspect="16:9", size="2K")
        BACKUP.mkdir(parents=True, exist_ok=True)
        shutil.copy(RAW / f"{n}.png", BACKUP / f"{n}.png")


# nombre del archivo -> (indice en la hoja, alto objetivo px, ancho maximo px)
DECOR_ITEMS = {
    "anubis_statue": (0, 78, 44), "anubis_sarcofago": (1, 54, 30), "anubis_column": (2, 50, 30), "anubis_stele": (3, 48, 30),
    "anubis_momia": (4, 44, 26), "anubis_amphora": (5, 38, 24), "anubis_inscripcion": (6, 28, 96), "anubis_column_fallen": (7, 24, 72),
}


def build_decor():
    g = {k: AD._sin_rotulo(v) for k, v in T._grid("decorado", 30, 40).items()}
    for name, (i, h, wmax) in DECOR_ITEMS.items():
        im = A.trim(g[i])
        s = min(h / im.height, wmax / im.width)
        w, hh = max(1, round(im.width * s)), max(1, round(im.height * s))
        out = A.down(im, w, hh)
        out = A.quantize_set({0: out}, 32)[0]
        out.save(DECOR / f"{name}.png")
        print(name, out.size)


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "build"
    if cmd == "gen":
        gen(sys.argv[2:])
    else:
        build_decor()
        PT.build_enemy("frasquito")
