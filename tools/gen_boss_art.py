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
    "afeitadora": ("A dramatic boss reveal: the boss from the reference, a blue electric shaver creature with a grey metal "
                   "foil head, angry little eyes, a green power light and a dangling power cord with a plug, buzzing with "
                   "electric sparks and flying hair clippings, standing in the rainy Pubic Jungle at night among tall grass "
                   "that it has shaved into a bald clearing. Low camera angle, aggressive and funny. "),
    "diu_cosmico": ("A dramatic boss reveal: the boss from the reference, a T-shaped copper IUD creature with orange copper "
                    "arms raised, a violet gem on top, a small stern face and thin legs, floating in a cosmic purple space "
                    "inside the Fallopian tubes with stars, swirling gravity rings and copper satellites orbiting it. Low "
                    "camera angle, mystic and funny. "),
    "regla": ("A dramatic boss reveal: the boss from the reference, Mrs. Ruler: a strict short lady creature with a hair bun, "
              "big round glasses and a red dress, holding a giant two-meter wooden measuring ruler and a calendar, standing "
              "inside the warm red Uterus chamber with soft walls, floating calendar pages and little clocks. Low camera "
              "angle, punctual and strict, funny. Respectful: no blood. "),
    "prostata": ("A dramatic boss reveal: DOÑA VENTANILLA, a grumpy middle-aged female bureaucrat creature that IS a "
                 "customer-service booth: a beige metal ticket-window booth with short stubby legs and arms, its glass "
                 "window is her face (bored half-closed eyes with cat-eye glasses on a beaded chain, red lipstick, chewing "
                 "gum), a half-lowered rolling metal shutter above the glass like a droopy eyelid, pink hair curlers on top of "
                 "the booth like a hairdo, a red take-a-number ticket dispenser on her side with a paper ticket hanging, "
                 "long painted nails holding a rubber stamp and a silver service bell. She stands at a border checkpoint "
                 "corridor between two territories with long waiting lines of tiny tired blob creatures holding paper "
                 "tickets, forms flying like snow, cold office lights. Low camera angle, bureaucratic menace, funny. "),
    "algoritmo": ("A dramatic boss reveal: the boss from the reference, a smartphone creature with an "
                  "antenna and a single giant red eye on its screen, tiny arms and legs, scanning the room with a red laser, "
                  "in a dark data-center hall of the Censorship Palace with server racks with blank blinking lights, flying grey pixel "
                  "squares and red prohibition symbols. Low camera angle, cold and creepy but funny. "),
    "don_chequeo": ("A dramatic boss reveal: DON CHEQUEO, the boss from the reference, a walnut-shaped male bureaucrat "
                    "creature with glasses, a grey tie, an ID badge and a clipboard with medical forms, pointing sternly at "
                    "a small examination booth with a curtain behind him, standing in a dim prostate-clinic waiting room "
                    "with rows of beige plastic chairs, a red take-a-number dispenser, a glowing number display showing only "
                    "digits, old magazines and tired patients waiting. Low camera angle, strict but funny: it is time for "
                    "your check-up. "),
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
    "don_chequeo": ["tools/_intro_raw/prostata_v2.png"],  # la nuez de la Ventanilla vieja (rama nuez-ventanilla-guardada)
    "hoja_de_parra": [ART + "parra/hoja_a.png"],
    "destine": [ART + "arcoiria/boss_a.png"],
}
NEW_LOOK = ("The boss MUST look exactly like the character in the attached reference sheet (same body, face, colors, "
            "outfit and accessories; it is a sheet of poses of ONE character): draw it once, big, in a single heroic pose. ")


## Rediseñados desde cero (Nico 2026-10-19): la Ventanilla deja de ser nuez (la nuez es la prostata, ya es la
## Glandula) y pasa a ser Doña Ventanilla, una casilla de atencion con patas, para el Perineo (frontera, tramites).
NEW_DESIGN = {"prostata"}


def _old_refs(name: str) -> list:
    """Jefes sin arte nuevo: su caratula vieja y su sprite idle como referencia del diseño."""
    import json
    idx = json.loads((g.ROOT / "assets/data/enemy_art.json").read_text())
    refs = []
    card = f"assets/sprites/ui/bosses/{name}.png"
    if (g.ROOT / card).exists():
        refs.append(card)
    spr = f"assets/sprites/enemies/{idx.get(name, '')}/{name}_idle_00.png"
    if (g.ROOT / spr).exists():
        refs.append(spr)
    return refs


## El Pacto de Silencio (reino sin humor, diseno_E3_silencio.md): sobria, sin chiste ni caricatura.
PACTO = ("Wide 16:9 retro pixel art illustration in the style of a serious 16-bit game cutscene: chunky pixels, dark "
         "outlines, very limited cold palette, solemn and quiet tone, NOT funny, no cartoon faces. No text, no letters, no "
         "UI. Full-bleed scene, no borders. A circle of seven faceless dark grey silhouettes sitting in chairs under a huge "
         "heavy curtain that hangs from the darkness above and swallows all sound; the silhouettes look down or away. Around "
         "the edge of the round room: two hanging bells, two cooking pots on a line and one large pane of glass, faintly lit. "
         "One thin cold beam of light from above. Grey stone floor. No weapons, no blood, no violence. Feeling: everyone "
         "knows and no one speaks. Dark vignette at the bottom third. ")


def run(name):
    if name == "pacto_silencio":
        raw = g.RAW / "pacto_silencio_v2.png"
        if not raw.exists():
            g.SCREENS["pacto_silencio_v2"] = ("", ["assets/sprites/silencio/pacto_idle_0.png"])
            style, g.STYLE = g.STYLE, PACTO
            try:
                raw = g.generate("pacto_silencio_v2")
            finally:
                g.STYLE = style
        g.pixelate(raw, name)
        (g.ROOT / f"assets/sprites/ui/screens/{name}.png").replace(g.ROOT / f"assets/sprites/ui/bosses/{name}.png")
        print("ok", name)
        return
    if name in NEW_DESIGN:  # diseño nuevo sin referencia (la caratula vieja ya no vale)
        raw = g.RAW / f"{name}_v3.png"
        if not raw.exists():
            g.SCREENS[name + "_v3"] = (BOSSES[name] + g.CREATURES + "ABSOLUTELY NO text, words, letters, signs with writing or labels anywhere in the image. Dark vignette at the bottom third. ", [])
            raw = g.generate(name + "_v3")
        g.pixelate(raw, name)
        (g.ROOT / f"assets/sprites/ui/screens/{name}.png").replace(g.ROOT / f"assets/sprites/ui/bosses/{name}.png")
        print("ok", name)
        return
    if name not in REFS and _old_refs(name):
        REFS[name] = _old_refs(name)
    if name in REFS:
        prompt = NEW_LOOK + BOSSES[name] + g.CREATURES + "ABSOLUTELY NO text, words, letters, signs with writing or labels anywhere in the image. Dark vignette at the bottom third. "
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
    prompt = BOSSES[name] + g.CREATURES + "ABSOLUTELY NO text, words, letters, signs with writing or labels anywhere in the image. Dark vignette at the bottom third. "
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
    for n in sys.argv[1:] or list(BOSSES) + ["pacto_silencio"]:
        run(n)
