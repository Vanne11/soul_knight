"""Arte DEFINITIVO de EL PACTO DE SILENCIO (jefe de Las Tierras del Silencio) con Gemini.
Escribe en assets/sprites/silencio/pacto/ (NO es carpeta de enemies: el jefe arma sus cuadros desde esa ruta).
TONO: sobrio, frio, SIN humor, SIN caras (siluetas), SIN sangre ni violencia. Estilo de la caratula
(tools/_intro_raw/pacto_silencio_v2.png, fuera de git), no el cartoon de los otros jefes.

Uso: python3 tools/gen_pacto_art.py gen [hoja ...]     llama a Gemini (una llamada por hoja, solo las que falten; con nombre, la rehace)
     python3 tools/gen_pacto_art.py build [parte ...]  recorta, pixela y escribe PNG + .tres (sin args = todo)
     python3 tools/gen_pacto_art.py preview DIR        hojas de contacto de las poses recortadas
Hojas (UNA imagen cada una, regla de Nico: nunca cuadro a cuadro), originales en .claude/arte_fuente/pacto/ (ruta ABSOLUTA
del repo principal: el worktree se borra):
  pacto_a pacto_c (la asamblea JUNTA) + ente (UNA silueta suelta); pacto_b y pacto_a_p2/_p3 salieron con otro estilo y NO se usan
  (fuente guardada). Las fases 2 y 3 salen de A y C con un virado frio y mas oscuro. 11 llamadas en total; tope 14.
Partes de build: bloque (224x184 -> pacto_sheet{,_p2,_p3}.png + pacto_sprite_frames{,_p2,_p3}.tres)
                 ente   (48x72  -> ente_sheet.png + ente_sprite_frames.tres)
Gemini cuela rotulos de texto aunque se prohiba: _sin_rotulo / _sin_astillas (de gen_aduanero_art.py) los quitan.
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
import gen_aduanero_art as AD  # noqa: E402  (_sin_rotulo, _sin_astillas)

ROOT = GEM.ROOT
RAW = Path("/home/nick/Escritorio/Proyectos/soul_knight/.claude/arte_fuente/pacto")
GEM.RAW = RAW
DEST = ROOT / "assets/sprites/silencio/pacto"
RES = "res://assets/sprites/silencio/pacto/"
REF = RAW / "_ref_pacto_v2_crop.png"
CUT.cut_bg = PA.cut_bg

STYLE_P = (
    "Sober premium indie pixel art with the mood of Dead Cells and Enter the Gungeon: crisp chunky pixels (low-res look, no "
    "anti-aliasing blur, no gradients), a clean 1-pixel near-black outline, flat cel shading with only two or three tones per "
    "surface, a RESTRICTED COLD palette (slate grey, desaturated indigo, dusty violet, pale cold blue light), abstract, quiet, "
    "serious and melancholic. NO humor, NO cartoon exaggeration, NO faces at all. Background: ONE perfectly flat solid pure "
    "green (#00FF00) with no ground, no cast shadows, no text, no labels, no grid lines, no borders. Every pose sits in its "
    "own cell with generous empty green space around it; poses never touch or overlap each other and nothing is cropped. "
    "Never use pure green (#00FF00) inside the artwork. ABSOLUTELY NO TEXT: never write letters, numbers, words, captions, "
    "pose names or labels anywhere; the bottom of every cell is empty green. No blood, no violence, no weapons, no injuries. "
)
_BLOCK = (
    "THE BOSS 'The Pact of Silence': ONE compact assembly of exactly SEVEN faceless smooth silhouettes in flat cool grey-lilac "
    "(like paper cut-outs: a plain rounded head and rounded shoulders, NO eyes, NO mouth, NO nose, NO hair, NO clothing details, "
    "no gender), human-sized, seated close together in a tight semicircle facing the viewer on plain grey stone chairs: four in "
    "the back row and three in the front row, shoulder to shoulder, so they read as ONE single mass. Above and behind them hangs a "
    "HEAVY dark indigo-violet velvet CURTAIN with vertical folds and a notched valance, like a canopy over the group, and a "
    "narrow beam of cold pale-blue light falls from above onto the middle silhouette. Same design, same proportions and the "
    "same colors as the reference image (the approved cover art), redrawn as a clean game sprite on flat green (ignore the "
    "dark room of the reference: only the assembly, its chairs and its curtain). IMPORTANT: this is a cut-out game sprite, NOT a "
    "scene: NO room, NO wall, NO floor, NO backdrop rectangle, NO frame around the cell. The curtain is only a compact canopy: a "
    "short wide curtain valance with a few hanging folds, no wider than the group plus a little margin and no taller than about "
    "half the height of the group, floating directly above and behind the silhouettes, with a notched dark edge; pure flat green "
    "must be visible all around the whole sprite and between the poses. The whole assembly with its curtain fits "
    "inside its cell and is shown at the SAME scale in every cell, with the chairs' base at the bottom of the cell. "
)
_BLOCK_PHASE = {
    "": "",
    "_p2": (
        "This is PHASE 2: the silhouettes sit tighter and closer together, the curtain is heavier and hangs lower with deeper dark "
        "folds, the light beam is colder, thinner and paler, the palette is darker and more desaturated. "
    ),
    "_p3": (
        "This is PHASE 3, the most oppressive: the silhouettes are pressed together almost fused into one grey mass, the curtain is "
        "very heavy and hangs low over their heads with almost-black folds and a thin sagging hem, the light beam is a thin icy "
        "pale-blue line, the palette is the darkest and coldest. "
    ),
}

PROMPTS = {
    "pacto_a": (
        STYLE_P + "BOSS SPRITE SHEET with exactly 3 rows of 3 large poses (9 poses), in reading order. " + _BLOCK +
        "Poses left to right, top row: (1) REST: sitting still, upright, the curtain hanging calm; (2) CURTAIN FALLING wind-up: the "
        "curtain valance sagging lower and gathering, the silhouettes shrinking a little under it; (3) CURTAIN FALLEN: the heavy "
        "curtain hanging low, covering them down to the shoulders, only the heads and shoulders peeking out. "
        "Middle row: (4) WHISPER wind-up: all seven heads tilt in toward each other, leaning toward the center; (5) WHISPER: all "
        "seven bodies and heads leaning forward together toward the right of the cell, a low murmuring posture; (6) EARS wind-up: "
        "the heads start to lower, shoulders rising. "
        "Bottom row: (7) EARS: all seven heads bowed low, both hands of each silhouette raised to the sides of the head covering "
        "where the ears would be; (8) LOOKING AWAY: every head and torso turned to the left, away from the viewer, as if ignoring "
        "something; (9) THE PACT CLOSES: all seven heads nod down together in unison, a faint cold glow along the front of the group."
    ),
    "pacto_b": (
        STYLE_P + "BOSS SPRITE SHEET with exactly 3 rows of 3 large poses (9 poses), in reading order, the SAME assembly as the "
        "reference image (approved design), only the pose changes. COPY THE EXACT LOOK of the reference: the curtain is a flat, tall, "
        "muted dark slate-indigo wall of straight vertical folds that reaches the TOP edge of the cell, with a rectangular dark "
        "notched opening behind the figures and a narrow dim pale-blue beam, exactly like the reference; NOT a theatre stage curtain, "
        "NO swags, NO tassels, NO scalloped valance, NO bright purple, NO bright cyan sky, NO tie-backs. " + _BLOCK +
        "Poses left to right, top row: (1) STUNNED: slumped and askew, the curtain crooked, the light beam flickering broken into "
        "pieces, heads drooping at different angles; (2) HURT: the whole assembly jolting back as one mass, shoulders pulled "
        "together, the curtain swaying; (3) INTRO: the curtain hanging a little higher than usual and the beam of light brighter, "
        "the silhouettes upright and still. "
        "Middle row: (4) SEPARATING: the seven silhouettes have stood up out of the chairs and are stepping apart from the block, "
        "clear gaps between each silhouette, standing upright, the empty chairs behind them, the dark curtain canopy hanging above; "
        "(5) STANDING APART: the seven silhouettes standing spread out wide, each separate with a big gap to the next, in front of "
        "the empty chairs, the curtain canopy above; (6) GATHERING: the seven standing silhouettes close together walking back "
        "toward their chairs, small gaps, the curtain canopy above. "
        "Bottom row: (7) END, step 1: the curtain lifting up, the seated silhouettes beginning to rise from their chairs; (8) END, "
        "step 2: all seven silhouettes standing up next to the chairs in two rows, the curtain raised high; (9) END, step 3: the "
        "seven standing silhouettes each holding a small warm yellow lantern light in their hands (the only warm color), the "
        "curtain fully raised, calm."
    ),
    "pacto_c": (
        STYLE_P + "BOSS SPRITE SHEET with exactly 3 rows of 3 large poses (9 poses), in reading order, the SAME assembly as the "
        "reference image (approved design), only the pose changes. " + _BLOCK +
        "Poses left to right, top row: (1) TIRED: slumped forward, all heads low, the curtain drooping, heavy breathing posture; "
        "(2) DOORS wind-up: the curtain splitting into two heavy panels that start to part, the silhouettes sitting very still; "
        "(3) DOORS: two heavy curtain panels hanging down at the left and right sides of the assembly leaving a gap in the middle. "
        "Middle row: (4) MURMUR: two or three silhouettes leaning their heads together toward each other, the rest still; (5) SHIFT: "
        "one silhouette shifting in its chair, the group slightly displaced to one side; (6) THE PACT CLOSES, second beat: all "
        "seven heads raised back up, upright, the faint cold glow stronger. "
        "Bottom row: (7) END, step 4: the seven silhouettes walking away to the sides, a few already outside the chairs, each holding "
        "a small warm yellow lantern light, the curtain raised high and bare; (8) END, step 5: only three silhouettes still near the "
        "chairs holding warm lantern lights, the rest gone, the empty chairs under the raised curtain; (9) END, step 6: ONLY the "
        "empty grey stone chairs under the raised curtain, the cold beam of light on the floor, no silhouettes."
    ),
    "ente": (
        STYLE_P + "CHARACTER SPRITE SHEET with exactly 3 rows of 3 poses (9 poses), in reading order, NO ground, NO floor tile, NO shadow patch under the feet (flat green all around), the SAME single character at "
        "the SAME scale in every cell, full body, standing on the ground (feet at the bottom of the cell), one per cell. "
        "THE CHARACTER: ONE faceless smooth silhouette in flat cool grey-lilac (like a paper cut-out: a plain rounded head, rounded "
        "shoulders, simple arms and legs, NO eyes, NO mouth, NO nose, NO hair, NO clothing details, no gender, human-sized and "
        "slim), the same kind of silhouette as the seated figures in the reference image but STANDING; viewed in a three-quarter "
        "top-down game view, facing RIGHT. Same colors as the reference. Poses: top row: (1) STANDING still, arms down; (2) WALKING "
        "step, left foot forward; (3) WALKING step, right foot forward. Middle row: (4) TURNING: the body half turned away, "
        "three-quarter back view; (5) LEANING in: the torso tilted forward toward the right as if bending to whisper; (6) CARRYING A "
        "LIGHT: holding a small lantern with a warm yellow light in one hand at hip height (the only warm color), standing calm. "
        "Bottom row: (7) BACK TO THE VIEWER: standing with the full back turned, looking away; (8) HEAD BOWED: standing with the "
        "head lowered; (9) HANDS TO HEAD: both hands raised to the sides of the head covering where the ears would be. "
    ),
}
GEN_ORDER = ["pacto_a", "pacto_c", "ente"]


def _raw(n):
    return Image.open(RAW / f"{n}.png")


def gen(names):
    ref = Image.open(REF)
    for n in names or GEN_ORDER:
        if (RAW / f"{n}.png").exists() and not names:
            continue
        if n in ("pacto_a", "ente"):
            refs = [ref]
        elif n in ("pacto_b", "pacto_c"):
            refs = [_raw("pacto_a")]
        else:  # fases: la hoja sana da el diseno y las poses
            refs = [_raw("pacto_a")] + ([_raw("pacto_a_p2")] if n.endswith("p3") else [])
        suf = "_p2" if n.endswith("_p2") else "_p3" if n.endswith("_p3") else ""
        prompt = PROMPTS[n.replace("_p2", "").replace("_p3", "")]
        if suf:
            prompt = prompt.replace("Poses left to right", _BLOCK_PHASE[suf] + "Same nine poses as the first reference sheet in the same order and positions. Poses left to right", 1)
        GEM.generate(n, prompt, aspect="4:3" if n != "ente" else "1:1", size="2K", refs=refs)
        print("LLAMADA a Gemini:", n)


# ------------------------------------------------------------------ recorte por rejilla 3x3
def _bg(path):
    im = PA.cut_bg(Image.open(path))
    a = np.array(im).astype(int)
    r, g, b = a[:, :, 0], a[:, :, 1], a[:, :, 2]
    green = (g > np.maximum(r, b) + 18) & (a[:, :, 3] > 0)
    a[:, :, 3] = np.where(green, 0, a[:, :, 3])
    return Image.fromarray(a.astype(np.uint8), "RGBA")


_LABEL_CUT = {"pacto_b": 0.89}  # Gemini escribe el nombre de la pose bajo cada celda: se descarta esa franja


def _grid(name, gap=60, ink=False):
    im = _bg(RAW / f"{name}.png")
    cw, ch = im.width / 3.0, im.height / 3.0
    out = {}
    for r in range(3):
        for c in range(3):
            mg = 0
            box = (max(0, int(c * cw) - mg), max(0, int(r * ch) - mg), min(im.width, int((c + 1) * cw) + mg), min(im.height, int((r + 1) * ch) + mg))
            if name in _LABEL_CUT:
                box = (box[0], box[1], box[2], int(r * ch + ch * _LABEL_CUT[name]))
            out[r * 3 + c] = AD._sin_rotulo(CUT.main_blob(im.crop(box), gap))
    return out


def _feet_x(im):
    a = np.array(im)[:, :, 3] > 128
    ys = np.nonzero(a.any(1))[0]
    lo = ys.max() - max(6, int(0.12 * (ys.max() - ys.min())))
    xs = np.nonzero(a[lo:].any(0))[0]
    return (xs.min() + xs.max()) / 2.0


def fit(raw, cw, ch, idle_h, ncol=36):
    """Todas las poses a la MISMA escala (idle -> idle_h), base abajo y centrada en la base; la que no cabe se encoge."""
    raw = {k: A.trim(v) for k, v in raw.items()}
    s = idle_h / raw["idle"].height
    out = {}
    for k, im in raw.items():
        m = min(1.0, (cw - 2) / (im.width * s), (ch - 1) / (im.height * s))
        fx = _feet_x(im)
        w, h = max(1, round(im.width * s * m)), max(1, round(im.height * s * m))
        sm = A.down(im, w, h)
        x0 = max(1, min(cw - w - 1, int(round(cw / 2 - fx * s * m))))
        cv = Image.new("RGBA", (cw, ch), (0, 0, 0, 0))
        cv.alpha_composite(sm, (x0, ch - h))
        out[k] = cv
    print("  escala", round(s, 3))
    return A.quantize_set(out, ncol)


def cool(im, amt):
    """Virado frio y oscuro para las fases 2 y 3 de las hojas B y C (el resto sale de Gemini)."""
    a = np.array(im).astype(np.float32)
    m = a[:, :, 3] > 0
    warm = (a[:, :, 0] > a[:, :, 2] + 25)  # las luces calidas del final no se enfrian
    k = np.array([1.0 - 0.18 * amt, 1.0 - 0.10 * amt, 1.0 - 0.02 * amt])
    for i in range(3):
        a[:, :, i] = np.where(m & ~warm, a[:, :, i] * k[i] * (1.0 - 0.12 * amt), a[:, :, i])
    return Image.fromarray(a.clip(0, 255).astype(np.uint8), "RGBA")


def harmonize(im, sat=0.45, val=0.88):
    """La hoja B salio con cortinas mas moradas y luz mas viva que la A: se baja la saturacion y el brillo (las luces calidas se respetan)."""
    a = np.array(im).astype(np.float32)
    m = a[:, :, 3] > 0
    warm = a[:, :, 0] > a[:, :, 2] + 25
    g = a[:, :, :3].mean(-1, keepdims=True)
    o = (g + (a[:, :, :3] - g) * sat) * val
    a[:, :, :3] = np.where((m & ~warm)[:, :, None], o, a[:, :, :3])
    return Image.fromarray(a.clip(0, 255).astype(np.uint8), "RGBA")


DW, DH = 224, 184
VARIANTS = {"": "pacto_a", "_p2": "pacto_a_p2", "_p3": "pacto_a_p3"}
_COOL = {"": 0.0, "_p2": 1.0, "_p3": 2.0}


def bloque_poses(suffix):
    """Poses del bloque. Las hojas A (ataques) y C (cansada, puertas, cura, fin) salen de Gemini; la B (aturdida, golpe, intro,
    separarse) se descarto (3 intentos con otro estilo): hurt/stun/intro se derivan por codigo y el separarse/juntarse usa la
    pose "vac" (sillas vacias bajo la cortina, de la hoja C) + las siluetas sueltas (hoja ente)."""
    xf = A.xf
    a = _grid("pacto_a")
    c = _grid("pacto_c")
    if suffix:  # fases 2 y 3: la misma hoja con un virado frio y mas oscuro (la luz se enfria, la cortina pesa mas)
        k = _COOL[suffix]
        a = {i: cool(v, k) for i, v in a.items()}
        c = {i: cool(v, k) for i, v in c.items()}
    raw = dict(idle=a[0], mw=a[1], mr=a[2], sw=a[3], sr=a[4], ow=a[5], orr=a[6], look=a[7], chan=a[8],
               tired=c[0], pw=c[1], pr=c[2], stir=c[3], shift=c[4], chan2=c[5], vac=c[8])
    P = fit(raw, DW, DH, 150)
    I = P["idle"]
    P["hurt"] = A.flash(xf(I, sx=0.98, sy=1.015, rot=-1.5, dx=-3), 0.22)
    P["stun"] = xf(P["tired"], rot=1.2, dx=2)
    P["intro"] = xf(I, sy=1.015)
    return P


def bloque_anims(P):
    xf = A.xf
    I = P["idle"]
    f = {}
    f["idle"] = [I, xf(I, sy=0.99), I, xf(I, sx=1.005, sy=0.995)]
    f["walk"] = [I, P["shift"], I, xf(I, dx=1, sy=0.99)]
    f["intro"] = [P["tired"], P["tired"], xf(P["intro"], sy=1.01), I]
    f["attack"] = [I, P["sw"]]
    f["release"] = [P["sr"], xf(P["sr"], dx=1)]
    f["attack_manto"] = [I, P["mw"]]
    f["release_manto"] = [P["mr"], xf(P["mr"], sy=0.99)]
    f["attack_susurro"] = [I, P["sw"]]
    f["release_susurro"] = [P["sr"], xf(P["sr"], dx=1), P["sr"]]
    f["attack_puerta"] = [I, P["pw"]]
    f["release_puerta"] = [P["pr"], xf(P["pr"], sy=0.99)]
    f["attack_oidos"] = [I, P["ow"]]
    f["release_oidos"] = [P["orr"], xf(P["orr"], sy=0.99)]
    f["attack_mirar_otro_lado"] = [I, P["look"]]
    f["release_mirar_otro_lado"] = [P["look"]]
    f["attack_nadie_dijo"] = [I, P["ow"], P["orr"]]
    f["release_nadie_dijo"] = [P["mr"], P["mr"]]
    f["recover_in"] = [P["tired"]]
    f["recover"] = [P["tired"], xf(P["tired"], sy=0.99), P["tired"], xf(P["tired"], sy=1.005)]
    f["stun_in"] = [P["hurt"], P["stun"]]
    f["tired"] = [P["stun"], xf(P["stun"], dy=1)]
    f["channel"] = [P["chan"], P["chan2"], P["chan"], P["chan2"]]
    f["hurt"] = [P["hurt"], P["hurt"], xf(P["hurt"], dx=-1)]
    f["brake"] = [I]
    f["blink"] = [I, I]
    f["idle_stir"] = [P["stir"], P["stir"], xf(P["stir"], sy=0.995), I]
    f["idle_impatient"] = [P["shift"], I, P["shift"], I]
    # separarse: sillas vacias bajo la cortina (las usa boss_pacto_silencio.gd; las siluetas son SilencioEnte)
    f["vacia"] = [P["vac"]]
    # fin sin violencia: golpe, se levantan las cabezas, la cortina queda alzada sobre las sillas vacias
    f["death"] = [P["hurt"], P["chan2"], P["vac"], P["vac"]]
    return f


META = {
    "idle": (3.0, True), "walk": (4.0, True), "intro": (2.5, False), "attack": (10.0, False), "release": (12.0, False),
    "tired": (5.0, True), "recover": (5.0, True), "recover_in": (10.0, False), "stun_in": (10.0, False),
    "channel": (2.0, True), "hurt": (10.0, False), "death": (1.4, False), "brake": (10.0, False), "blink": (12.0, False),
    "idle_stir": (3.5, False), "idle_impatient": (4.0, False), "vacia": (1.0, True),
}
for _n in ("manto", "susurro", "puerta", "oidos", "mirar_otro_lado", "nadie_dijo"):
    META["attack_" + _n] = (9.0, False)
    META["release_" + _n] = (10.0, False)


def write_frames(frames, cw, ch, name, suffix, cols=6, meta=META):
    uniq, index = [], {}
    for lst in frames.values():
        for im in lst:
            k = im.tobytes()
            if k not in index:
                index[k] = len(uniq)
                uniq.append(im)
    rows = (len(uniq) + cols - 1) // cols
    sheet = Image.new("RGBA", (cols * cw, rows * ch), (0, 0, 0, 0))
    for i, im in enumerate(uniq):
        sheet.alpha_composite(im, ((i % cols) * cw, (i // cols) * ch))
    DEST.mkdir(parents=True, exist_ok=True)
    sheet.save(DEST / f"{name}_sheet{suffix}.png")
    L = ['[gd_resource type="SpriteFrames" load_steps=%d format=3]' % (len(uniq) + 2), "",
         f'[ext_resource type="Texture2D" path="{RES}{name}_sheet{suffix}.png" id="1_sheet"]', ""]
    for i in range(len(uniq)):
        L += [f'[sub_resource type="AtlasTexture" id="f{i}"]', 'atlas = ExtResource("1_sheet")',
              f"region = Rect2({(i % cols) * cw}, {(i // cols) * ch}, {cw}, {ch})", ""]
    anim = []
    for n, lst in frames.items():
        fr = ", ".join('{\n"duration": 1.0,\n"texture": SubResource("f%d")\n}' % index[im.tobytes()] for im in lst)
        sp, loop = meta.get(n, (10.0, False))
        anim.append('{\n"frames": [%s],\n"loop": %s,\n"name": &"%s",\n"speed": %.1f\n}' % (fr, "true" if loop else "false", n, sp))
    L += ["[resource]", "animations = [" + ", ".join(anim) + "]", ""]
    (DEST / f"{name}_sprite_frames{suffix}.tres").write_text("\n".join(L))
    print(name, suffix or "_p1", len(uniq), "cuadros")


def build_bloque():
    for suf in VARIANTS:
        write_frames(bloque_anims(bloque_poses(suf)), DW, DH, "pacto", suf)


# ------------------------------------------------------------------ ente suelto 48x72
EW, EH = 48, 72


def ente_poses():
    g = _grid("ente", gap=30)
    raw = dict(idle=g[0], wa=g[1], wb=g[2], turn=g[3], lean=g[4], light=g[5], away=g[6], bow=g[7], ears=g[8])
    return fit(raw, EW, EH, 66, ncol=24)


def ente_anims(P):
    xf = A.xf
    I = P["idle"]
    return {"idle": [I, xf(I, sy=0.985)], "walk": [P["wa"], I, P["wb"], I], "turn": [P["turn"]], "lean": [P["lean"]],
            "light": [P["light"], xf(P["light"], sy=0.985)], "away": [P["away"]], "bow": [P["bow"]], "ears": [P["ears"]]}


ENTE_META = {"idle": (2.5, True), "walk": (6.0, True), "light": (2.5, True), "turn": (1.0, False), "lean": (1.0, False),
             "away": (1.0, False), "bow": (1.0, False), "ears": (1.0, False)}


def build_ente():
    write_frames(ente_anims(ente_poses()), EW, EH, "ente", "", cols=6, meta=ENTE_META)


# ------------------------------------------------------------------ hoja de contacto
def _sheet(items, cw, ch, cols, k, bg=(30, 30, 42, 255)):
    rows = (len(items) + cols - 1) // cols
    sh = Image.new("RGBA", (cols * cw * k, rows * ch * k), bg)
    for i, (_, im) in enumerate(items):
        big = im.resize((im.width * k, im.height * k), Image.NEAREST)
        sh.alpha_composite(big, ((i % cols) * cw * k + (cw * k - big.width) // 2, (i // cols) * ch * k + (ch * k - big.height)))
    return sh


def preview(dest):
    dest = Path(dest)
    dest.mkdir(parents=True, exist_ok=True)
    tiles = []
    for suf in VARIANTS:
        for k, im in bloque_poses(suf).items():
            tiles.append((f"pacto{suf} {k}", im))
    ente = list(ente_poses().items())
    _sheet(tiles, DW, DH, 9, 1).convert("RGB").save(dest / "pacto_poses_x1.png")
    _sheet(tiles, DW, DH, 9, 3).convert("RGB").save(dest / "pacto_poses_x3.png")
    _sheet(ente, EW, EH, 9, 1).convert("RGB").save(dest / "ente_x1.png")
    _sheet(ente, EW, EH, 9, 3).convert("RGB").save(dest / "ente_x3.png")


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "build"
    args = sys.argv[2:]
    if cmd == "gen":
        gen(args)
    elif cmd == "build":
        parts = args or ["bloque", "ente"]
        if "bloque" in parts:
            build_bloque()
        if "ente" in parts:
            build_ente()
    elif cmd == "preview":
        preview(args[0] if args else ".")
