"""Arte DEFINITIVO de EL ALGORITMO MODERADOR (jefe alternativo del Archivo Clasificado, Palacio) y del BOT DE REPORTE (esbirro) con Gemini.
Escribe en assets/sprites/enemies/palacio/algoritmo/ y palacio/bot_reporte/ (carpetas de assets/data/enemy_art.json).

Uso: python3 tools/gen_algoritmo_art.py gen [hoja ...]     llama a Gemini (una llamada por hoja, solo las que falten; con nombre, la rehace)
     python3 tools/gen_algoritmo_art.py build [parte ...]  recorta, pixela, interpola y escribe PNG + .tres (sin args = todo)
     python3 tools/gen_algoritmo_art.py preview DIR        hojas de contacto de las poses recortadas
Hojas (UNA imagen cada una, regla de Nico: nunca cuadro a cuadro), originales en .claude/arte_fuente/algoritmo/:
  alg_a alg_b alg_c (sano) + _p2 y _p3 de cada una (dano visible) + bot                (10 llamadas; tope 14)
Referencia de diseno: tools/_intro_raw/algoritmo_v2.png (caratula, fuera de git; ruta absoluta mas abajo).
Partes de build: algoritmo (176x184 -> algoritmo_sheet{,_p2,_p3}.png + algoritmo_sprite_frames{,_p2,_p3}.tres)
                 bot (32x48 -> bot_reporte_*_NN.png + bot_reporte_sprite_frames.tres)
"""
import sys
from pathlib import Path

import numpy as np  # noqa: F401
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import gen_testiculo_art as T  # noqa: E402
import arc2_gemini as GEM  # noqa: E402
import gen_arcoiria_art2 as A  # noqa: E402
import gen_aduanero_art as AD  # noqa: E402  (reutiliza _sin_rotulo / _sin_astillas: ningun texto llega al juego)
from arc2_gemini import STYLE  # noqa: E402

ROOT = GEM.ROOT
RAW = Path("/home/nick/Escritorio/Proyectos/soul_knight/.claude/arte_fuente/algoritmo")
GEM.RAW = RAW
T.RAW = RAW
COVER = Path("/home/nick/Escritorio/Proyectos/soul_knight/tools/_intro_raw/algoritmo_v2.png")
DEST = ROOT / "assets/sprites/enemies/palacio/algoritmo"
RES = "res://assets/sprites/enemies/palacio/algoritmo/"
SDEST = ROOT / "assets/sprites/enemies/palacio/bot_reporte"
SRES = "res://assets/sprites/enemies/palacio/bot_reporte/"

_NOTEXT = (" ABSOLUTELY NO TEXT: never write letters, numbers, words, captions, pose names, labels or signs anywhere in the image "
           "(the phone screen shows only the red eye, plain icons, simple shapes or glitch noise, never letters or digits); "
           "the bottom of every cell is empty green.")
_ALG = (
    "THE BOSS 'El Algoritmo Moderador' (the Moderator Algorithm, an automatic content-censoring machine): a SMARTPHONE-shaped "
    "robot with a rounded dark-grey body, a thin red-tipped ANTENNA on top, a light-blue SCREEN that shows ONE giant white "
    "EYEBALL with a big red iris and a black pupil and stern black eyebrows (the eye is its face), a small grey home-button bar "
    "under the screen, two thin grey stick ARMS with tiny hands and two short grey stick LEGS with small flat feet. Cold, "
    "uncanny, deadpan but funny, family friendly. Palette: dark grey, slate blue-grey, light blue, white, red, black. "
    "Same character, same proportions, same colors and same design as the reference image, but redrawn with much more detail, "
    "richer shading and a premium look. "
)
_ORDER = (
    " LAYOUT (critical): the image is an empty flat green canvas holding EXACTLY 8 characters in a strict grid of 2 rows and 4 "
    "columns, never 3 rows and never a different count. The background is ONLY flat pure green: do NOT draw the server room, "
    "racks, floor tiles or any scenery from the reference (the reference is only a character cut-out). Do NOT draw a ground "
    "shadow. All poses are the SAME character at the SAME scale and the same camera, full body visible, standing on the ground (feet at "
    "the bottom of the cell), a single big character per cell, no extra characters except the props named. Extra effects (red "
    "beams, pixels, sparks) stay very close to the body and inside the cell." + _NOTEXT
)
_DMG2 = (
    "It is the DAMAGED PHASE 2 of the SAME character as the reference sheet: same poses in the same order and positions, same "
    "design, but clearly battle-worn: the screen is cracked with a spider-web crack across a corner, a few dead black pixels and "
    "a stuck colored pixel line on the screen, the antenna is slightly bent, scratches and a dent on the casing, the eye is "
    "bloodshot and a bit twitchy, a small spark, darker shadows. "
)
_DMG3 = (
    "It is the HEAVILY DAMAGED, ENRAGED PHASE 3 of the SAME character as the reference sheet: same poses in the same order, same "
    "design, but breaking down: the screen is shattered with big cracks and missing glass shards, large patches of dead pixels "
    "and glitch bars, the antenna is snapped and bent hard to one side dangling, a torn-off corner of the casing showing "
    "wires, sparks and smoke puffs, the red eye is angrier, wider and glowing, one arm cracked and taped. "
)
_POSES_A = (
    "Poses left to right, top row: (1) neutral IDLE standing, the eye looking straight ahead scanning, arms at the sides; (2) WALK "
    "frame 1: stepping forward to the right, left foot forward, body tilted a little; (3) WALK frame 2: passing pose, body "
    "bobbing slightly higher; (4) WALK frame 3: right foot forward, tilted the other way. Bottom row: (5) SCAN WIND-UP: leaning "
    "back, arms spread wide, the eye wide and glowing red, a thin red scan line starting to appear on the screen; (6) SCAN "
    "RELEASE: leaning forward, firing a bright thin red LASER beam sweeping out from the eye to the right with motion arc "
    "lines; (7) REPORT WIND-UP: one arm raised pointing a finger, the screen showing the red eye with a small red crosshair "
    "reticle on the pupil, narrowed eyebrows; (8) REPORT RELEASE: leaning forward, arm thrust out pointing, the crosshair "
    "reticle on the eye locked on target, a red flash, small impact lines."
)
_POSES_B = (
    "Poses left to right, top row: (1) dramatic INTRO: powering on, the screen just lit up bright, the antenna lit red, arms "
    "raised slightly, a few small blue pixel sparks around; (2) EXHAUSTED: the battery is low, slumped and sagging forward, the "
    "screen dim with the eye half-closed and a tiny empty low battery icon in a corner (just a rectangle with one red bar, no "
    "text), arms drooping, a sweat drop; (3) STUNNED and dizzy: tilted and wobbling, the screen full of colorful glitch "
    "stripes and static noise with the eye spiraling, tiny sparks and stars circling; (4) CHANNELING A HEALING: serene, the "
    "screen showing the eye closed with a horizontal LOADING BAR filling with a green fill under it, a soft cyan glow aura, "
    "arms open, tiny sparkles rising. Bottom row: (5) flinching pose: tilted back, the screen eye squeezed into a wince, the "
    "antenna wobbling, a small spray of pixel debris; then a theatrical DEATH in 3 steps: (6) shaking, the screen flickering "
    "with glitch bars, the antenna bending, sparks; (7) collapse: falling backwards, the screen turning a flat BLUE ERROR "
    "screen with only a simple sad-face shape made of two dots and a curved line (no letters), pixels bursting out; (8) lying "
    "flat on its back, the screen dark and cracked with a faded dim glow, X shaped dead pixels, the antenna snapped beside "
    "it, a tiny wisp of smoke."
)
_POSES_C = (
    "Poses left to right, top row: (1) GENERIC ATTACK WIND-UP: leaning back, the arms raised, the eye glaring, small spam "
    "envelope and notification-bubble icons gathering around; (2) GENERIC ATTACK RELEASE: leaning forward, flinging a fan of "
    "small notification bubbles and red dots forward to the right with motion lines; (3) PATTERN DETECTED WIND-UP: the whole "
    "screen flashing a red ALERT state: a bright red background with a big white warning triangle containing a simple "
    "exclamation mark shape (no letters), the eye small in a corner, the antenna blinking red, a finger raised; (4) PREDICTION "
    "RELEASE: the screen shows the giant eye fixed hard to one side with a tiny crosshair, the eye locked on a point, one arm "
    "pointing forward to the right, calm and eerily confident. Bottom row: (5) SENSITIVE CONTENT WIND-UP: both hands raised "
    "making a big square frame, the screen showing the eye, large square mosaic pixel blocks of grey and white starting to "
    "appear around it; (6) SENSITIVE CONTENT RELEASE: arms slammed forward, a big square of chunky blurry pixelated mosaic "
    "blocks projected to the right in front of it; (7) CALL-THE-BOTS WIND-UP: one hand raised to the antenna, the antenna "
    "glowing, the screen showing the eye with two tiny wifi signal arcs, leaning back; (8) CALL-THE-BOTS RELEASE: one arm "
    "thrown forward in a beckoning flick, the antenna sending out wifi signal arcs, two tiny grey round bot silhouettes "
    "appearing, a small puff of pixels."
)
_BOT = (
    "ENEMY SPRITE SHEET with exactly 2 rows of 4 small poses (8 poses), the SAME tiny creature at the same scale in each cell. "
    "THE ENEMY 'Bot de reporte' (a small report-bot minion of the Moderator Algorithm boss): a small round-ish floating "
    "grey drone about a quarter the size of the boss, a rounded grey body like a small hovering speech-bubble-shaped chassis, "
    "ONE big glassy RED camera eye in the middle with a black pupil and a white highlight, a tiny antenna with a red dot on "
    "top, two tiny stub arms, and a short hovering stub underneath (it floats, no legs), a little flag icon on its side. "
    "Cute, cold and bureaucratic, humorous. Palette: dark grey, slate blue-grey, light blue, white, red. Same design family "
    "as the boss in the reference image. Poses left to right, top row: (1) idle floating, eye looking forward; (2) drifting "
    "frame, tilted a little, the eye looking to the side; (3) AIMING pose: still, the red eye wide and glowing with a "
    "tiny red crosshair reticle on the pupil, warm red aura; (4) REPORTING pose: leaning forward firing a flash, a red "
    "flag icon popped up, small impact star. Bottom row: (5) flinching pose: eye squeezed shut, the antenna askew, a few "
    "pixel scraps; (6) death part one: shaking, sparks, glitch lines; (7) death part two: falling backwards, pixels "
    "bursting; (8) death part three: lying flat, X eye, a tiny puff of smoke."
) + _ORDER

PROMPTS = {}
for _k, _p in (("a", _POSES_A), ("b", _POSES_B), ("c", _POSES_C)):
    _lead = "BOSS SPRITE SHEET with exactly 2 rows of 4 large poses (8 poses)."
    PROMPTS[f"alg_{_k}"] = STYLE + _lead + _ORDER + _ALG + _p
    PROMPTS[f"alg_{_k}_p2"] = STYLE + _lead + " " + _DMG2 + _ORDER + _ALG + _p
    PROMPTS[f"alg_{_k}_p3"] = STYLE + _lead + " " + _DMG3 + _ORDER + _ALG + _p
_MATCH = (
    " STYLE MATCH (critical): keep EXACTLY the silhouette, proportions, screen size, eye size and antenna of the reference "
    "sheet, the same chunky pixel size and 1-pixel dark outline, the same pose composition in every cell; only add the damage "
    "described. No glossy plastic highlights, no smooth airbrushed shading. Do NOT write pose names or any caption."
)
for _n in list(PROMPTS):
    if _n.endswith("_p2") or _n.endswith("_p3"):
        PROMPTS[_n] += _MATCH
for _n in ("alg_b", "alg_c"):
    PROMPTS[_n] += (
        " STYLE MATCH (critical): the reference sheet(s) show the approved look. Copy it EXACTLY: the same flat matte dark-grey "
        "casing, the same light-blue screen, the same red eye, the same chunky pixel size and 1-pixel dark outline. No glossy "
        "plastic highlights, no smooth airbrushed shading. Do NOT write pose names or any caption."
    )
PROMPTS["alg_b"] += (
    " IMPORTANT: keep the phone body EXACTLY like the references (a boxy rounded rectangle with a flat grey bar under the screen, "
    "NOT a round home button, NOT an iPhone, NOT a thin bezel), the same thick dark-grey casing. Draw NO black divider lines "
    "between the cells and NO frames: only flat green between poses. The loading bar is just an empty rounded bar with a green "
    "fill and has NO caption, NO word and NO letters near it anywhere."
)
PROMPTS["alg_a_p3"] += (
    " Keep the phone body EXACTLY like the references: a boxy rounded rectangle with a thick dark-grey casing and a flat grey bar "
    "under the screen, NOT a round home button, NOT an iPhone; the same light-blue screen with the big white eyeball and red iris "
    "(cracked, not replaced), the same antenna. The scan laser beam and every effect must stay fully inside its own cell, "
    "never touching the image border."
)
PROMPTS["bot"] = STYLE + _BOT
GEN_ORDER = ["alg_a", "alg_b", "alg_c", "alg_a_p2", "alg_b_p2", "alg_c_p2", "alg_a_p3", "alg_b_p3", "alg_c_p3", "bot"]


def _cover(box=None):
    """Referencia: el telefono de la caratula recortado sobre verde plano (sin el cuarto de servidores de fondo)."""
    return Image.open(RAW / "ref_verde.png").convert("RGB")


def gen(names):
    boss_ref = _cover((510, 120, 870, 600))
    for n in names or GEN_ORDER:
        if (RAW / f"{n}.png").exists() and not names:
            continue
        if n == "alg_a":
            refs = [boss_ref]
        elif n in ("alg_b", "alg_c", "bot"):
            refs = [boss_ref, Image.open(RAW / "alg_a.png")]
            if n == "alg_b":
                refs.append(Image.open(RAW / "alg_c.png"))
        else:
            base, suf = n.rsplit("_", 1)
            refs = [Image.open(RAW / f"{base}.png")]
            if base != "alg_a":
                refs.append(Image.open(RAW / f"alg_a_{suf}.png"))
            elif suf == "p3":
                refs.append(Image.open(RAW / "alg_a_p2.png"))
        GEM.generate(n, PROMPTS[n], aspect="16:9", size="2K", refs=refs)
        print("LLAMADA a Gemini:", n)


# ------------------------------------------------------------------ jefe 176x184
TW, TH = T.TW, T.TH


def _grid(name, gap=40, blob_gap=60):
    return {k: AD._sin_rotulo(v) for k, v in T._grid(name, gap, blob_gap).items()}


VARIANTS = {"": ("alg_a", "alg_b", "alg_c"), "_p2": ("alg_a_p2", "alg_b_p2", "alg_c_p2"), "_p3": ("alg_a_p3", "alg_b_p3", "alg_c_p3")}


def boss_poses(suffix):
    na, nb, nc = VARIANTS[suffix]
    a, b, c = _grid(na), _grid(nb), _grid(nc)
    raw = dict(idle=a[0], w1=a[1], w2=a[2], w3=a[3], escw=a[4], escr=a[5], repw=a[6], repr=a[7],
               intro=b[0], tired=b[1], stun=b[2], channel=b[3], hurt=b[4], x1=b[5], x2=b[6], x3=b[7],
               fanw=c[0], fanr=c[1], patw=c[2], patr=c[3], pixw=c[4], pixr=c[5], botw=c[6], botr=c[7])
    return T.fit(raw, TW, TH, 150)


def boss_anims(P):
    xf = A.xf
    I = P["idle"]
    f = {}
    f["idle"] = [I, xf(I, sy=0.985), I, xf(I, sx=1.01, sy=0.99)]
    f["walk"] = [P["w1"], xf(P["w2"], dy=-1), P["w3"], xf(P["w2"], dy=-1)]
    f["intro"] = [P["intro"], P["intro"], xf(P["intro"], sy=1.02), I]
    f["attack"] = f["attack_fan"] = f["attack_notificaciones"] = [I, xf(P["fanw"], rot=-2), P["fanw"]]
    f["release"] = f["release_fan"] = f["release_notificaciones"] = [P["fanr"], xf(P["fanr"], dx=2), xf(P["fanr"], dy=1)]
    f["attack_escaneo"] = [I, xf(P["escw"], sy=0.98), P["escw"], xf(P["escw"], dy=-1)]
    f["release_escaneo"] = [P["escr"], xf(P["escr"], dx=2), P["escr"], xf(P["escr"], dx=-1)]
    f["attack_reportado"] = [I, xf(P["repw"], sy=0.98), P["repw"]]
    f["release_reportado"] = [P["repr"], xf(P["repr"], dx=2), P["repr"]]
    # PATRON DETECTADO (alerta roja) y la prediccion (ojo fijo en un punto)
    f["attack_prediccion"] = [I, xf(P["patw"], sy=0.98), P["patw"], xf(P["patw"], dy=-1), P["patw"]]
    f["release_prediccion"] = [P["patr"], xf(P["patr"], dx=2), P["patr"]]
    f["attack_pixelado"] = f["attack_bloqueo"] = [I, xf(P["pixw"], sy=0.98), P["pixw"], xf(P["pixw"], dy=-1)]
    f["release_pixelado"] = f["release_bloqueo"] = [P["pixr"], xf(P["pixr"], dx=2), P["pixr"]]
    f["attack_bots"] = [I, xf(P["botw"], sy=0.98), P["botw"]]
    f["release_bots"] = [P["botr"], xf(P["botr"], dx=2), P["botr"]]
    f["tired"] = [P["stun"], xf(P["stun"], dy=1)]  # aturdido: pantalla con glitch (distinto del agotamiento)
    f["recover_in"] = [P["tired"]]
    f["recover"] = [P["tired"], xf(P["tired"], sy=0.985), P["tired"], xf(P["tired"], dy=1, sy=0.99)]  # agotado: bateria baja
    f["stun_in"] = [P["hurt"], P["stun"]]
    f["channel"] = [P["channel"], xf(P["channel"], dy=-2), P["channel"], xf(P["channel"], dy=-1)]
    f["hurt"] = [P["hurt"], P["hurt"], xf(P["hurt"], dx=-1)]
    f["brake"] = [I, xf(I, sy=0.98)]
    f["blink"] = [I, I]
    f["idle_stir"] = [xf(I, rot=-2), xf(I, rot=2), I]
    f["idle_impatient"] = [xf(I, dy=-2), I, xf(I, dy=-2), I]
    f["death"] = [P["hurt"], P["x1"], xf(P["x1"], dx=1), P["x2"], xf(P["x2"], dx=-1), P["x3"], P["x3"]]
    return f


T.META.update({"idle": (4.0, True)})
for _n in ("escaneo", "reportado", "prediccion", "pixelado", "bloqueo", "bots", "notificaciones"):
    T.META["attack_" + _n] = (12.0, False)
    T.META["release_" + _n] = (14.0, False)


def build_algoritmo():
    DEST.mkdir(parents=True, exist_ok=True)
    for suf in VARIANTS:
        n = T._tres(boss_anims(boss_poses(suf)), DEST / f"algoritmo_sheet{suf}.png", f"{RES}algoritmo_sheet{suf}.png", TW, TH, 6,
                    DEST / f"algoritmo_sprite_frames{suf}.tres")
        print("algoritmo", suf or "_p1", n, "cuadros")
    for old in DEST.glob("algoritmo_*_[0-9][0-9].png*"):
        old.unlink()  # cuadros sueltos del arte provisorio: ahora todo va en la hoja


# ------------------------------------------------------------------ bot 32x48
SW_, SH_ = 32, 48


def bot_poses():
    g = _grid("bot", 30, 40)
    raw = dict(zip(("idle", "walk", "aim", "mark", "hurt", "d1", "d2", "d3"), (g[i] for i in range(8))))
    raw = {k: A.trim(v) for k, v in raw.items()}
    s = 40.0 / raw["idle"].height
    out = {}
    for k, v in raw.items():
        s_k = 40.0 / v.height if k == "walk" else s
        m = min(1.0, 30.0 / (v.width * s_k), 47.0 / (v.height * s_k))
        fx = T._feet_x(v)
        w, h = max(1, round(v.width * s_k * m)), max(1, round(v.height * s_k * m))
        cv = Image.new("RGBA", (SW_, SH_), (0, 0, 0, 0))
        x0 = max(0, min(SW_ - w, int(round(SW_ / 2 - fx * s_k * m))))
        cv.alpha_composite(A.down(v, w, h), (x0, SH_ - h - 1))
        out[k] = cv
    print("  bot escala", round(s, 3))
    return A.quantize_set(out, 40)


def build_bot():
    P = bot_poses()
    xf = A.xf
    I = P["idle"]
    f = {"idle": [I, xf(I, dy=-1), I, xf(I, dy=1)], "walk": [P["walk"], I, xf(P["walk"], dy=-1), I],
         "attack": [P["aim"], xf(P["aim"], dx=1), P["aim"], xf(P["aim"], dx=-1)], "mark": [P["mark"], xf(P["mark"], dy=1)],
         "hurt": [P["hurt"], A.flash(P["hurt"], 0.5)], "death": [P["d1"], P["d2"], P["d3"], P["d3"]]}
    speeds = {"idle": (5.0, True), "walk": (8.0, True), "attack": (16.0, True), "mark": (10.0, True), "hurt": (10.0, False), "death": (8.0, False)}
    SDEST.mkdir(parents=True, exist_ok=True)
    for old in SDEST.glob("bot_reporte_*"):
        old.unlink()
    res, anim = [], []
    for n, lst in f.items():
        fr = []
        for i, im in enumerate(lst):
            im.save(SDEST / f"bot_reporte_{n}_{i:02d}.png")
            rid = f"{n}{i}"
            res.append(f'[ext_resource type="Texture2D" path="{SRES}bot_reporte_{n}_{i:02d}.png" id="{rid}"]')
            fr.append('{\n"duration": 1.0,\n"texture": ExtResource("%s")\n}' % rid)
        sp, loop = speeds[n]
        anim.append('{\n"frames": [%s],\n"loop": %s,\n"name": &"%s",\n"speed": %.1f\n}' % (", ".join(fr), "true" if loop else "false", n, sp))
    (SDEST / "bot_reporte_sprite_frames.tres").write_text(
        '[gd_resource type="SpriteFrames" format=3]\n\n' + "\n".join(res) + "\n\n[resource]\nanimations = [" + ", ".join(anim) + "]\n")


# ------------------------------------------------------------------ hoja de contacto
def preview(dest):
    dest = Path(dest)
    dest.mkdir(parents=True, exist_ok=True)
    BG = (58, 56, 84, 255)

    def sheet(items, cw, ch, cols, k):
        rows = (len(items) + cols - 1) // cols
        sh = Image.new("RGBA", (cols * cw * k, rows * ch * k), BG)
        for i, (_, im) in enumerate(items):
            big = im.resize((im.width * k, im.height * k), Image.NEAREST)
            sh.alpha_composite(big, ((i % cols) * cw * k + (cw * k - big.width) // 2, (i // cols) * ch * k + (ch * k - big.height)))
        return sh
    for suf in VARIANTS:
        tiles = list(boss_poses(suf).items())
        sheet(tiles, TW, TH, 8, 1).convert("RGB").save(dest / f"algoritmo{suf}_poses_x1.png")
        sheet(tiles, TW, TH, 6, 2).convert("RGB").save(dest / f"algoritmo{suf}_poses_x2.png")
        sheet(tiles, TW, TH, 4, 3).convert("RGB").save(dest / f"algoritmo{suf}_poses_x3.png")
    sat = list(bot_poses().items())
    sheet(sat, SW_, SH_, 8, 1).convert("RGB").save(dest / "bot_x1.png")
    sheet(sat, SW_, SH_, 8, 4).convert("RGB").save(dest / "bot_x4.png")


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "build"
    args = sys.argv[2:]
    if cmd == "gen":
        gen(args)
    elif cmd == "build":
        parts = args or ["algoritmo", "bot"]
        if "algoritmo" in parts:
            build_algoritmo()
        if "bot" in parts:
            build_bot()
    elif cmd == "preview":
        preview(args[0] if args else ".")
