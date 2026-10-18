"""Ilustraciones del codice con Gemini: assets/sprites/codex/<id_entrada>.png (320x320, lamina de bestiario).

Uso: python3 tools/gen_codex_art.py [id ...]   (sin args = todas las que falten). Una llamada por imagen.
Reusa la key (~/.kaggle/gemini_key) y el modelo de gen_intro_art.py.
Si la API falla (cuota, red) se detiene: el juego sigue mostrando el sprite de siempre.
Guarda el original en tools/_codex_raw/ (ignorado) y escribe tools/codex_art_prompts.json
(id -> prompt completo + referencias) para regenerar una sola: REGEN=1 python3 tools/gen_codex_art.py ene_ego
Sin texto dibujado: el nombre lo pone el juego, traducido.
"""
import base64
import io
import json
import os
import sys
import urllib.error
import urllib.request
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import gen_intro_art as g
from PIL import Image

ROOT = g.ROOT
RAW = Path(__file__).resolve().parent / "_codex_raw"
OUT = ROOT / "assets/sprites/codex"
PROMPTS = Path(__file__).resolve().parent / "codex_art_prompts.json"
SIZE = 320

STYLE = (
    "Square vintage natural-history bestiary / encyclopedia plate, drawn as a funny cartoon: clean confident ink outlines, "
    "soft watercolor shading, warm aged-parchment background with a subtle darker vignette at the edges, a soft ground shadow. "
    "One single subject centered, filling about 70% of the frame, whole subject visible. Cute and humorous caricature with big "
    "round expressive eyes, bright saturated colors, in the same visual universe as the reference sprites. "
    "No text, no letters, no numbers, no captions, no labels, no frame, no border, no watermark. "
    "Family-friendly cartoon humor with cheeky innuendo only: nothing explicit, no nudity, no gore, no blood. "
)
CRE = ("IMPORTANT: no humans and no animals; the subject is a cute abstract creature or object exactly matching the design, "
       "colors and shapes of the reference sprite, just redrawn bigger with more detail and personality. ")
ITS = "This is a friendly, charming cartoon microbe mascot (a cute germ character), never disgusting, without any stigma. "


def I(ref, text, extra=""):
    return ([ref], text + " " + extra)


def E(variant, text, extra=""):
    return ([f"enemies/{variant}_idle_00"], text + " " + extra)


# id de entrada -> (sprites de referencia, descripcion del sujeto)
ENTRIES = {
    # --- enemigos de los pisos
    "ene_barra": E("barra_negra", "A grumpy black censorship bar creature with tiny legs, looking tired of its job, one arm raised to cover something.", CRE),
    "ene_calambre": E("calambre", "A small angry yellow zigzag lightning bolt creature crackling with sparks.", CRE),
    "ene_clamidia": E("clamidia", "A shy, polite little germ that tiptoes almost invisible, innocent 'I did nothing' face, slightly translucent.", CRE + ITS),
    "ene_correa": E("correa", "A leather leash creature with a hook end, lunging forward as if to drag someone.", CRE),
    "ene_dedo": E("dedo", "A giant finger wearing a latex glove, creeping sneakily with a patient smirk.", CRE),
    "ene_dildo_electrico": E("dildo_electrico", "A cartoon plug-in gadget creature with a frayed cord and crackling blue electricity, out of warranty and furious.", CRE),
    "ene_ego": E("ego_inflado", "A pompous inflated balloon in a tie, puffing itself up boastfully with a swollen ego grin.", CRE),
    "ene_especulo": E("especulo", "A cold clinical metal speculum instrument with beak-like jaws, opening wide, escaped from the doctor's office.", CRE),
    "ene_esperma": E("espermatozoide", "A cheerful white tadpole-like swimmer with a long blue wavy tail, glowing, about to dash forward.", CRE),
    "ene_espinilla": E("espinilla", "A red swollen pimple creature trembling and about to burst, pretending to be innocent.", CRE),
    "ene_esposas": E("esposas", "A pair of furry pink handcuffs creature with a dangling chain, snapping shut with a click.", CRE),
    "ene_gonorrea": E("gonorrea", "A leaky dripping little germ leaving a trail of droplets behind, watering the ground like a gardener.", CRE + ITS),
    "ene_gran_candado": E("gran_candado", "A huge stern padlock guardian, shackle closed, solid and nearly invulnerable, a tiny shiny keyhole eye.", CRE),
    "ene_granito": E("granito", "A resentful red pimple about to burst, swelling and glowing, with a grudge in its eyes.", CRE),
    "ene_gran_urologo": E("gran_urologo", "A whole giant hand in a latex glove with every finger eager to help, a calm professional look.", CRE),
    "ene_hemorroide": E("hemorroide", "A border-guard hemorrhoid blob wearing a guard cap and a yellow-black hazard stripe, standing stubbornly in the way.", CRE),
    "ene_herpes": E("herpes", "A persistent little germ with a blister, coming back with a smug 'did you miss me?' face.", CRE + ITS),
    "ene_huincha": E("huincha", "A yellow measuring tape creature with an inspector attitude, unrolling itself with a smile.", CRE),
    "ene_inspector": E("inspector_fluidos", "A test tube wearing an official cap, bureaucratic and important, checking a clipboard.", CRE),
    "ene_jaula": E("jaula", "A prison cage creature with bars and tiny legs, about to pounce and trap someone.", CRE),
    "ene_ladilla": E("ladilla", "A small organized green crab-like louse with big eyes, a union worker with a tiny helmet.", CRE),
    "ene_mito_himen": E("mito_himen", "A fussy bureaucrat official with a big rubber stamp, protected by a flimsy membrane shield that cracks at the first hit.", CRE),
    "ene_mito_mano": E("mito_mano", "A climbing hand creature that is growing silly hairs on its fingers, looking worried and ridiculous.", CRE),
    "ene_mito_marcha": E("mito_marcha", "A charging creature that suddenly slams into reverse with a screeching skid, leaving two tiny tadpoles behind in surprise.", CRE),
    "ene_mordaza": E("mordaza", "A ball-gag shaped creature with a leather strap, throwing silent muffled balls, wearing a 'shh' attitude.", CRE),
    "ene_ovulo": E("ovulo", "A round proud pale-pink egg wearing a tiny golden crown, rolling regally, noble expression.", CRE),
    "ene_pelo": E("pelo_encarnado", "An ingrown curly hair creature, irritated and full of resentment, twisted into a spiral.", CRE),
    "ene_pelusa": E("pelusa_perineal", "A grey floating fluff ball with a little cockade badge, convinced it is an important dust bunny.", CRE),
    "ene_pixel": E("pixel_censura", "A blurry mosaic censorship pixel block with eyes, hovering in front of something to hide it.", CRE),
    "ene_sello": E("sello", "A rubber stamp creature with legs, stamping marks on everything, fanning stamps around.", CRE),
    "ene_shibari": E("shibari", "A rope master creature made of knotted red rope, casting rope nets, calm and artistic.", CRE),
    "ene_sifilis": E("sifilis", "The great imitator germ wearing a mustache-and-glasses disguise as another creature, sneaky grin.", CRE + ITS),
    "ene_sonda": E("sonda", "A thin fast slender probe creature aiming a red laser line, ready to dash like a spear.", CRE),
    "ene_testiculo": E("testiculo", "A wrinkly pink round creature with a single half-closed eye, judging everyone with ancient disappointment.", CRE),
    "ene_trompa": E("trompa", "A fallopian tube creature with fringed fimbriae used as hands, spitting a fan of shots, argumentative expression.", CRE),
    "ene_venda": E("venda", "A black blindfold cloth creature, flying and wrapping around eyes, mischievous.", CRE),
    "ene_vesicula": E("vesicula", "A pear-shaped gallbladder gland full of green bile and unspoken words, grumpy, keeping its distance.", CRE),
    "ene_vph": E("vph", "A cauliflower-shaped wart germ with little legs and a head-of-the-family attitude, small warts running around its ankles.", CRE + ITS),
    # --- jefes (y alternativos)
    "boss_1": E("boss_cera", "The boss: a pink cooking-pot creature dripping hot golden wax, with a blue bow and steam, holding a wooden ladle like a weapon, melting candles around.", CRE),
    "boss_2": E("testiculo_primordial", "The boss: a giant ancient wrinkly pink round one-eyed creature with a curly tuft on top and tentacle-like legs, solemn and intimidating but funny.", CRE),
    "boss_3": E("reina_ovaria", "The boss: a pink egg-shaped queen with spots, a golden crown, purple dress and thin arms raised in fury.", CRE),
    "boss_4": E("aduanero", "The boss: an orange bean-shaped customs officer with a purple cap, mustache, blue tie, clipboard and a big red rubber stamp raised.", CRE),
    "boss_5": E("hoja_de_parra", "The boss: a giant prim green fig leaf with a face, tiny round glasses and a pearl necklace, thin legs, arms crossed in disapproval.", CRE),
    "boss_alt_1": E("afeitadora", "The boss: an electric shaver creature with spinning blades, mean grin, buzzing, hairs flying.", CRE),
    "boss_alt_2": E("don_viagra", "The boss: Don Viagra, a smug blue diamond-shaped pill gentleman with a mustache and a cape, heroic pose.", CRE),
    "boss_alt_3": E("diu_cosmico", "The boss: a cosmic IUD, a T-shaped copper device floating among stars and nebula, serene and godlike.", CRE),
    "boss_alt_4": E("prostata", "The boss: a bureaucrat prostate, a walnut-shaped gland in a tie sitting behind a desk with paperwork stamps.", CRE),
    "boss_alt_5": E("algoritmo", "The boss: a moderator algorithm, a cold floating screen-and-gears creature with a blinking red eye that flags everything, bureaucratic menace.", CRE),
    # --- protagonistas
    "char_pitocles": (["player/pitocles/portrait"], "The hero Pitocles: a pink capsule-shaped creature with a golden Greek hoplite helmet with red crest and a round shield, heroic and a bit goofy. " + CRE),
    "char_vulvalquiria": (["player/vulvalquiria/portrait"], "The hero Vulvalquiria: a magenta bean-shaped valkyrie with a winged Viking helmet, spear and shield, fierce and proud. " + CRE),
    "char_ornitorrinco": (["player/ornitorrinco/portrait"], "The hero Ornitorrinco: a teal platypus with a straw hat, sensing electricity with its bill, laid-back and clever. Matching the reference exactly. "),
    # --- objetos
    "condom_lore": (["items/relic_condom"], "A shiny golden legendary relic: a glowing condom in its wrapper, sparkling like a holy artifact on a small cushion, flames and slime bouncing off it comically. Wholesome, nothing explicit. "),
    "menstrual_cup_lore": (["items/menstrual_cup"], "A reinforced menstrual cup shown proudly like a knight's shield, eco-friendly leaf motif, absorbing a cartoon impact with a 'bonk' star. "),
    "viagra_lore": (["items/relic_viagra"], "A mystical voodoo blue diamond pill floating with magic purple smoke and a tiny skull charm. Cheeky, nothing explicit. "),
    "lube_lore": (["items/relic_lube"], "A quantum lubricant bottle floating with swirling galaxy-colored gel, slipping and sliding through space, cheerful sparkles. "),
    # --- lugares (sin referencia: escena)
    "loc_penelandia": ([], "A landscape plate of Penelandia, a blue and gold kingdom of ancient Greek columns and tall elongated towers, all slightly inflated and vertical, banners flying, tiny pink capsule citizens with golden helmets. " + CRE),
    "loc_vulvania": ([], "A landscape plate of Vulvania, a pink and magenta kingdom of curvy organic palaces with petals, flowers, hearts and cyclical gardens, tiny magenta bean citizens with winged helmets and round egg creatures with crowns. " + CRE),
    "loc_selva": ([], "A landscape plate of the Pubic Jungle: a dense, damp, curly jungle of tangled dark curly vines and wiry fronds, a tiny green louse creature peeking out, nobody has trimmed it since the censorship. Humorous, nothing explicit. " + CRE),
    "loc_perineo": ([], "A landscape plate of the Perineum: a narrow bleak border strip of land between a blue Greek-column kingdom on the left and a pink flowery kingdom on the right, hazard stripes, a lone guard post and dust bunnies, nobody lives here. " + CRE),
    "loc_palacio": ([], "A landscape plate of the Palace of Censorship: a huge grey perfectly tidy palace where every painting has black bars, statues wear bathrobes, mosaic pixel squares float around, a giant fig leaf banner above. " + CRE),
    # --- codice 2: objetos, tragos, reliquias, armas y lore sin lamina
    "absinthe_lore": I("items/absinthe", "A cartoon bottle of green absinthe with a tiny glowing green fairy floating out of the neck whispering secrets into the viewer's ear, swirly hypnotic eyes, wisps of green mist. "),
    "bandages_lore": I("items/bandages", "A roll of slightly suspicious used bandages with a worried face, faint stink lines and a few tiny flies circling, sheepish 'better not ask' expression. "),
    "birth_control_lore": I("items/relic_birth_control", "A round blister pack of contraceptive pills as a sensible, prim and slightly boring relic wearing tiny reading glasses, pills lined up neatly like obedient soldiers, a calendar-like pattern. Wholesome. "),
    "bloody_key_lore": I("items/key_bloody", "An ornate old key dripping glossy ruby-red paint-like drops, with a faintly worried face, as if cursed and a bit dramatic. "),
    "chocolate_bar_lore": I("items/chocolate_bar", "A chocolate bar half unwrapped with a dreamy hormonal-craving face, hearts floating around, a small crumb trail, irresistible and smug. "),
    "coffee_lore": I("items/coffee", "A steaming cup of coffee with a smug morning-liar face, jittery shaking lines, wide caffeinated eyes, steam forming a fake smile. "),
    "coin_lore": I("items/coin", "A bashful golden coin stamped with a fig leaf on its face, blushing, covering itself shyly with a tiny hand. "),
    "crystal_key_lore": I("items/key_crystal", "A beautiful crystal key with a crack running through it, sparkling prisms, a sad perfectionist expression, tiny shards falling off. "),
    "drunk_secret": I("items/whiskey", "A shameful small wooden door slightly ajar with a glowing keyhole, a bottle of whiskey leaning against it, a blushing hungover face on the door, a mirror glint inside, 'door of shame' mood. "),
    "elites": ([], "An ordinary little creature that got a swollen ego: wearing a big golden crown, a glowing red ring aura around it and floating colored affix orbs (a speed swirl, a blue shield bubble, a spiky ring) orbiting it, smug proud pose. " + CRE),
    "energy_drink_lore": I("items/energy_drink", "A can of energy drink with tiny feathered angel wings flapping frantically, bulging eyes, a racing heart pulsing out of the can and lightning sparks. "),
    "estrogen_lore": I("items/relic_estrogen", "A pink glowing relic of estrogen from the kingdom of Vulvania: a regal vial with a heart-shaped crystal, flowers and petals swirling around, elegant and radiant. Nothing explicit. "),
    "flashbang_lore": I("items/grenade_flashbang", "A flashbang grenade bursting with a blinding white flash, wearing little sunglasses and a gleeful grin, radial light rays, a cowering vampire-like shadow in the corner shielding eyes. "),
    "golden_pistol_lore": I("items/pistol_golden", "A shiny golden pistol on a velvet cushion looking vain and pompous, glittering, next to a modest humble lead bullet that is the true hero with a tiny cape. "),
    "grenade_lore": I("items/grenade_frag", "A frag grenade with a pin ring dangling and a cheeky wink, colorful fireworks exploding in the background, a tiny lit fuse, 'don't stay to watch the fireworks' mood. "),
    "hormonas_contrabando": I("items/hormone_testosterona", "A shady smuggler's suitcase opened to reveal glass vials of hormones, one blue and one pink, with handwritten tags (blank, no text), a trench coat flap and a flashlight beam, black market feel. Nothing explicit. "),
    "intoxication_mechanic": I("items/absinthe", "A toxicity gauge shaped like a tall glass thermometer filled with swirling green liquid rising in three stages, a wobbly cartoon face, dizzy spiral eyes and floating bubbles, tipsy stars. No text. "),
    "liver_lore": I("items/relic_liver", "A big brown cartoon liver organ relic with a weary traumatized face, bags under its eyes, a tiny bottle in one hand, a faint halo of trauma lines, 'has seen terrible things'. Cute and non-gory. "),
    "master_key_secret": I("items/key_master", "A grand mysterious door covered with dozens of different locks and chains, a single glowing golden master key in front of it turning in one keyhole, light seeping through the cracks, ominous and funny. "),
    "mead_lore": I("items/mead", "A rustic wooden mug and a clay jug of honey mead with golden honey dripping, a bee wearing a tiny elephant-like memory ribbon on its leg and an expression of never forgetting. "),
    "medkit_lore": I("items/medkit", "A sturdy first-aid medkit box with a red cross on it, open with neatly packed supplies, a determined heroic face, ready to save the day. "),
    "morning_after_pill_lore": I("items/morning_after_pill", "A single small pill on a pedestal with a gentle halo and a relieved 'second chance' smile, a rewinding clock with no numbers behind it, soft golden light. Wholesome. "),
    "mystery_fluid_lore": I("items/mystery_fluid", "A mysterious flask of swirling multicolored fluid with a big question mark made of bubbles inside, a dubious cork, wobbling nervously, rolling die-like sparkles around it, russian-roulette mood. "),
    "prostate_lore": I("items/relic_prostate", "A walnut-shaped prostate gland relic glowing with forbidden enlightenment, a third eye of light on its forehead, lotus meditation pose, golden rays and swirling cosmic wisdom. Nothing explicit. "),
    "rifle_lore": I("items/rifle_reproductive", "A quirky long rifle with a pink baby-bottle-like barrel and a bullet-and-heart emblem, one tiny cute baby bean peeking out of the muzzle among confetti, cheeky, a bestiary specimen. "),
    "rum_lore": I("items/rum", "A pirate rum bottle wearing a tiny tricorn hat and an eyepatch, with a parrot on top, a treasure-map swirl and a tear of regret rolling down, swashbuckling. "),
    "shotgun_lore": I("items/shotgun_pelvic", "A burly pelvic shotgun with a wide pink-bone-shaped stock, cheeky confident face, a cloud of pellets and cartoon smoke from the barrel, heroic stance. Nothing explicit. "),
    "sinergias_lore": I("items/shotgun_pelvic", "Three colorful glowing jigsaw puzzle pieces fitting together perfectly in the center: one shaped like a weapon, one like a small item, one like a blessing with a halo, radiant sparkles where they lock, a happy 'click' star. No text. "),
    "steroid_lore": I("items/relic_steroid", "A comically over-muscled red vial relic with huge cartoon biceps and an angry vein-popping face, steam from the ears, tiny dumbbell, 'roid rage' mood. Nothing explicit. "),
    "stimulant_lore": I("items/stimulant_combat", "A combat stimulant injector pen with a lightning-bolt emblem, jittery speed lines, a smug credit card tied to it by a string and a tiny bill collector clock waiting behind. "),
    "syringe_lore": I("items/syringe_adrenaline", "An adrenaline syringe plunging toward a cute beating heart with lightning, defibrillator-like electric sparks, a heroic hospital-drama pose. Non-gory. "),
    "tequila_lore": I("items/tequila", "A tequila bottle with a sombrero, a tiny shot glass called a caballito beside it with a lime wedge and a salt rim, a smug lying face saying 'just one', a cartoon worm winking. "),
    "testosterone_lore": I("items/relic_testosterone", "A blue glowing relic of testosterone from the kingdom of Penelandia: a mighty vial with a Greek column shape and a lightning emblem, heroic and a bit exaggerated, golden laurel leaves around. Nothing explicit. "),
    "trap_lore": I("items/trap_bear", "A big steel bear trap with jagged teeth snapping shut, a surprised and apologetic face, a small yellow impact starburst with no lettering, tiny bandage on its jaw, hazard vibe. Non-gory. "),
    "vodka_lore": I("items/vodka", "A crystal-clear vodka bottle posing as innocent water with a halo and a very obvious fake innocent smile, a sneaky devil tail behind it, ice crystals. "),
    "whiskey_lore": I("items/whiskey", "A whiskey bottle in disguise wearing a fake mustache and glasses, with a suspicious label shape (no text), amber glow, a sly grin, a barrel in the background. "),
}


def ref_part(ref):
    sp = Image.open(ROOT / f"assets/sprites/{ref}.png").convert("RGBA")
    if sp.getbbox():
        sp = sp.crop(sp.getbbox())
    k = max(1, 240 // max(sp.width, sp.height))
    sp = sp.resize((sp.width * k, sp.height * k), Image.NEAREST)
    bg = Image.new("RGB", (256, 256), (40, 40, 48))
    bg.paste(sp, ((256 - sp.width) // 2, (256 - sp.height) // 2), sp)
    buf = io.BytesIO()
    bg.save(buf, "PNG")
    return {"inlineData": {"mimeType": "image/png", "data": base64.b64encode(buf.getvalue()).decode()}}


def prompt_of(i):
    return STYLE + ENTRIES[i][1]


def generate(i):
    refs = ENTRIES[i][0]
    body = {
        "contents": [{"parts": [ref_part(r) for r in refs] + [{"text": prompt_of(i)}]}],
        "generationConfig": {"responseModalities": ["IMAGE"], "imageConfig": {"aspectRatio": "1:1"}},
    }
    req = urllib.request.Request(
        f"https://generativelanguage.googleapis.com/v1beta/models/{g.MODEL}:generateContent",
        data=json.dumps(body).encode(),
        headers={"Content-Type": "application/json", "x-goog-api-key": g.key()},
    )
    with urllib.request.urlopen(req, timeout=180) as r:
        data = json.load(r)
    for part in data["candidates"][0]["content"]["parts"]:
        if "inlineData" in part:
            RAW.mkdir(exist_ok=True)
            out = RAW / f"{i}.png"
            out.write_bytes(base64.b64decode(part["inlineData"]["data"]))
            return out
    raise RuntimeError(f"{i}: sin imagen: {json.dumps(data)[:300]}")


def finish(raw, i):
    im = Image.open(raw).convert("RGB")
    w, h = im.size
    s = min(w, h)
    im = im.crop(((w - s) // 2, (h - s) // 2, (w - s) // 2 + s, (h - s) // 2 + s)).resize((SIZE, SIZE), Image.LANCZOS)
    OUT.mkdir(parents=True, exist_ok=True)
    im.save(OUT / f"{i}.png", optimize=True)


def write_registry():
    PROMPTS.write_text(json.dumps(
        {i: {"refs": ENTRIES[i][0], "prompt": prompt_of(i)} for i in ENTRIES},
        ensure_ascii=False, indent=1), encoding="utf-8")


if __name__ == "__main__":
    write_registry()
    for i in sys.argv[1:] or list(ENTRIES):
        raw = RAW / f"{i}.png"
        if not raw.exists() or os.environ.get("REGEN"):
            try:
                raw = generate(i)
            except urllib.error.HTTPError as ex:  # cuota o red: no insistir, el juego usa el sprite
                print("FALLO (API)", i, ex)
                break
            except Exception as ex:  # el modelo no devolvio imagen (filtro): se salta esa entrada
                print("SIN IMAGEN", i, ex)
                continue
            print("generada", i, flush=True)
        finish(raw, i)
