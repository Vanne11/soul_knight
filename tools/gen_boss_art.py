"""Presentacion de jefes con Gemini: assets/sprites/ui/bosses/<jefe>.png (320x180 pixelada).

Uso: python3 tools/gen_boss_art.py [jefe ...]   (sin args = los cinco). Una llamada por imagen.
Reusa las funciones de gen_intro_art.py (key de ~/.kaggle/gemini_key, pixelado y paleta corta).
Sin texto dibujado: el nombre del jefe lo pone el juego, traducido.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import gen_intro_art as g

BOSSES = {
    "boss_cera": ("A dramatic boss reveal: the boss from the reference, a pink cooking-pot creature dripping hot golden wax with "
                  "a blue bow and steam, holding a wooden ladle like a weapon, towering menacingly in a dim jungle waxing parlor "
                  "with melting candles, vines and orange glow. Low camera angle, comic villain pose. "),
    "testiculo_primordial": ("A dramatic boss reveal: the boss from the reference, a giant wrinkly pink round one-eyed creature "
                             "with a curly tuft on top and tentacle-like legs, towering inside a vast ancient Greek temple of white "
                             "columns with blue light rays. Low camera angle, intimidating but funny. "),
    "reina_ovaria": ("A dramatic boss reveal: the boss from the reference, a pink egg-shaped queen with spots, a golden crown, "
                     "purple dress and thin arms raised in fury, in a throne room inside a pink mushroom-and-heart palace of "
                     "Vulvania with magenta curtains and petals flying. Low camera angle, regal and angry. "),
    "aduanero": ("A dramatic boss reveal: the boss from the reference, an orange bean-shaped customs officer with a purple cap, "
                 "mustache, blue tie, clipboard and a big red rubber stamp raised, standing at a grey steel border checkpoint "
                 "gate with yellow and black hazard stripes and spotlights. Low camera angle, bureaucratic menace. "),
    "hoja_de_parra": ("A dramatic boss reveal: the boss from the reference, a giant prim green fig leaf with a face, tiny round "
                      "glasses, a pearl necklace and thin legs, arms crossed in disapproval, looming in the grey Palace of "
                      "Censorship throne hall with black censor bars and pixelated mosaic squares floating around, dramatic "
                      "light rays. Low camera angle. "),
    "glandula": ("A dramatic boss reveal: the boss from the reference, a huge pink-brown walnut-shaped gland creature with a sealed "
                 "stitched mouth, tired heavy-lidded eyes with dark circles and a paper waiting-number ticket on its side, "
                 "sitting perfectly silent and calm in the middle of a dim hospital waiting room with rows of beige plastic chairs, "
                 "old magazines scattered on the floor, a ticket-number display and a faint warm saxophone-lit glow. Low camera angle, "
                 "quiet menace, deadpan comedy. "),
}


def run(name):
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
