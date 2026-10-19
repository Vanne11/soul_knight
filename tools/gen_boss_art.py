"""Presentacion de jefes con Gemini: assets/sprites/ui/bosses/<jefe>.png (320x180 pixelada).

Uso: python3 tools/gen_boss_art.py [jefe ...]   (sin args = todos). Una llamada por imagen.
Los jefes con arte definitivo de Gemini (REFS) usan como referencia sus hojas originales en alta
resolucion (.claude/arte_fuente/, respaldo en ~/Videos/Rogue Reproductive/arte_gemini_original/) y
guardan el crudo como <jefe>_v2.png; los demas siguen con su sprite viejo hasta tener arte nuevo.
Modelo: GEMINI_IMAGE_MODEL=gemini-3.1-flash-image (el de gen_intro_art.py por defecto es el lite).
Reusa las funciones de gen_intro_art.py (key de ~/.kaggle/gemini_key, pixelado y paleta corta).
Sin texto dibujado: el nombre del jefe lo pone el juego, traducido.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import gen_intro_art as g

BOSSES = {
    "boss_cera": ("A dramatic boss reveal: the boss from the reference, a pink wax-jar creature with golden hot wax dripping "
                  "from its lid, a teal bow, lipstick lips and a wooden spatula raised like a weapon, steam rising, towering "
                  "menacingly in a dim jungle waxing parlor with melting candles, vines and orange glow. Low camera angle, "
                  "comic villain pose. "),
    "testiculo_primordial": ("A dramatic boss reveal: the boss from the reference, a giant wrinkly pink round one-eyed creature "
                             "with a tube on top, a golden band around its body and many little legs, towering inside a vast ancient Greek temple of white "
                             "columns with blue light rays. Low camera angle, intimidating but funny. "),
    "reina_ovaria": ("A dramatic boss reveal: the boss from the reference, a pink egg-shaped queen with cream spots, a golden "
                     "crown, a purple royal cape and thin arms raised in fury, in a throne room inside a pink mushroom-and-heart palace of "
                     "Vulvania with magenta curtains and petals flying. Low camera angle, regal and angry. "),
    "aduanero": ("A dramatic boss reveal: the boss from the reference, an orange bean-shaped customs officer with a purple cap, "
                 "mustache, blue tie, clipboard and a big red rubber stamp raised, standing at a grey steel border checkpoint "
                 "gate with yellow and black hazard stripes and spotlights. Low camera angle, bureaucratic menace. "),
    "hoja_de_parra": ("A dramatic boss reveal: the boss from the reference, a giant prim green fig leaf with a face, tiny round "
                      "glasses, a pearl necklace and thin legs, arms crossed in disapproval, looming in the grey Palace of "
                      "Censorship throne hall with black censor bars and pixelated mosaic squares floating around, dramatic "
                      "light rays. Low camera angle. "),
    "don_sildenafil": ("A dramatic boss reveal: the boss from the reference, a light-blue diamond-shaped pill gentleman with a "
                       "tiny black top hat with a red band, a golden monocle, smug grin, white gloves and blue boots, flexing "
                       "with blue energy crackling around him, on the stage of a fancy old pharmacy with glass jars, blister "
                       "packs and a big clock pointing to four o'clock. Low camera angle, overconfident and funny. "),
    "destine": ("A dramatic boss reveal: the boss from the reference, a grey stocky man-shaped censor with a grey top hat, a black "
                "censor bar over the eyes, a white lab coat whose hem is stained with rainbow colors, holding a giant paint "
                "roller dripping grey paint and a CENSURADO stamp, standing in a rainbow plaza that he is painting grey: half "
                "the colorful bunting, flags and tiles behind him are already drained to grey. Low camera angle, menacing but "
                "funny. "),
    "glandula": ("A dramatic boss reveal: the boss from the reference, a huge pink-brown walnut-shaped gland creature with a sealed "
                 "stitched mouth, tired heavy-lidded eyes with dark circles and a paper waiting-number ticket on its side, "
                 "sitting perfectly silent and calm in the middle of a dim hospital waiting room with rows of beige plastic chairs, "
                 "old magazines scattered on the floor, a ticket-number display and a faint warm saxophone-lit glow. Low camera angle, "
                 "quiet menace, deadpan comedy. "),
}


ART = ".claude/arte_fuente/"
## Jefes con arte definitivo: hojas de referencia (rutas desde la raiz del repo).
REFS = {
    "boss_cera": [ART + "cera/cera_raw/base.png", ART + "cera/cera_raw/strike.png"],
    "reina_ovaria": [ART + "ovaria/reina_a.png"],
    "testiculo_primordial": [ART + "testiculo/test_a.png"],
    "don_sildenafil": [ART + "sildenafil/sildenafil_a.png"],
    "hoja_de_parra": [ART + "parra/hoja_a.png"],
    "destine": [ART + "arcoiria/boss_a.png"],
}
NEW_LOOK = ("The boss MUST look exactly like the character in the attached reference sheet (same body, face, colors, "
            "outfit and accessories; it is a sheet of poses of ONE character): draw it once, big, in a single heroic pose. ")


def run(name):
    if name in REFS:
        prompt = NEW_LOOK + BOSSES[name] + g.CREATURES + "Do not write the boss name or any text. Dark vignette at the bottom third. "
        g.SCREENS[name] = (prompt, REFS[name])
        raw = g.RAW / f"{name}_v2.png"
        if not raw.exists():
            g.SCREENS[name + "_v2"] = g.SCREENS[name]
            raw = g.generate(name + "_v2")
        g.pixelate(raw, name)
        src = g.ROOT / f"assets/sprites/ui/screens/{name}.png"
        dst = g.ROOT / f"assets/sprites/ui/bosses/{name}.png"
        src.replace(dst)
        print("ok", name)
        return
    g.SHEETS[name] = ["enemies/%s_idle_00" % name]
    prompt = BOSSES[name] + g.CREATURES + "Do not write the boss name or any text. Dark vignette at the bottom third. "
    g.SCREENS[name] = (prompt, ["sheet:" + name])
    raw = g.RAW / f"{name}.png"
    if not raw.exists():
        raw = g.generate(name)
    g.pixelate(raw, name)
    # pixelate guarda en ui/screens: mover a ui/bosses
    src = g.ROOT / f"assets/sprites/ui/screens/{name}.png"
    dst = g.ROOT / f"assets/sprites/ui/bosses/{name}.png"
    dst.parent.mkdir(parents=True, exist_ok=True)
    src.replace(dst)
    print("ok", name)


if __name__ == "__main__":
    for n in sys.argv[1:] or BOSSES:
        run(n)
