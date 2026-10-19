"""Prompts de las hojas de Gemini del arte definitivo de la Hoja de Parra, la Parra Entera y la hojita censora
(ver gen_parra_art2.py). Una hoja = una llamada. El humor es el de siempre: la censura es ridicula y pudorosa."""
from arc2_gemini import STYLE

_HOJA = (
    "THE BOSS 'Su Pudorosidad, la Hoja de Parra' (His Modesty, the Fig Leaf): a prissy, pompous, bright green "
    "grapevine leaf with five rounded lobes and visible lighter-green veins, standing upright on two thin olive "
    "stick legs with little yellow shoes. Her face is on the leaf: round golden-rimmed glasses, heavy lashes, "
    "smug eyelids, a small pink pursed mouth above a wide toothy smile made of a row of white pearl-like teeth "
    "like a pearl necklace; tiny leaf-lobe arms. A self-righteous censor, a prude with attitude. Bright leaf "
    "green with a darker green shadow, golden glasses, white teeth. Same character, same proportions and same "
    "colors as the reference image(s) (approved design). "
)

HOJA_A = (
    STYLE
    + "BOSS SPRITE SHEET with exactly 2 rows of 4 large poses (8 poses), the SAME big character at the same scale in "
    "each cell, full body visible, grounded. " + _HOJA +
    "Poses left to right, top row: (1) neutral idle, smug and prim, hands on hips; (2) walking step A, one leg "
    "forward; (3) walking step B, the opposite stride; (4) attack wind-up, leaning back, mouth wide open with the "
    "teeth gritted, lobes spread and gathering energy, a small black censor bar glowing near her. Bottom row: (5) "
    "attack release, lunging forward with arms thrown out, shouting, three black censor bars flying out from her; "
    "(6) tired and drained, slumped over and panting, glasses crooked, leaf drooping, sweat drop; (7) channeling a "
    "healing spell, eyes closed, serene, leaf lobes raised, a green glowing aura with tiny sparkles; (8) hurt, "
    "flinching backwards with squeezed eyes, glasses askew, a pained shocked face."
)

HOJA_B = (
    STYLE
    + "BOSS SPRITE SHEET with exactly 1 row of 4 large poses, the SAME character as the reference image (approved "
    "design: identical leaf, glasses, teeth, legs, colors and proportions, same art style), only the pose changes, "
    "same scale. " + _HOJA +
    "Poses left to right: (1) dramatic intro entrance, chin up, arms spread wide, triumphant and smug; (2) stunned "
    "and dizzy, eyes as swirls behind crooked glasses, tiny stars circling her, arms limp, teeth wobbling; (3) "
    "defeat part one: staggering and tipping over backwards, leaf curling at the edges, glasses flying off, "
    "surprised open mouth, edges starting to wilt yellow-brown; (4) defeat part two: lying flat and wilted on the "
    "ground like a dried crumpled brown-green leaf, X eyes, glasses cracked beside her, a little white flag of "
    "surrender, with a few loose green leaf pieces."
)

_PARRA = (
    "THE BOSS 'La Parra' (The Grapevine), the real final form of the Fig Leaf boss: a gigantic, ancient, rooted "
    "GRAPEVINE PLANT standing upright like a huge tree-monster, seen in a three-quarter top-down game view. A thick "
    "twisted brown vine trunk rising from big gnarled roots that grip the ground, long whip-like green tendrils "
    "with curly tips as arms, heavy bunches of purple grapes hanging, and a big crown of broad green grape leaves. "
    "The 'face' is the same big green leaf of the Hoja de Parra seen in the reference (golden round glasses, heavy "
    "lashes, a toothy smile of white pearl-like teeth, prim and menacing), set at the center front of the leafy "
    "crown. Tall and imposing and wide, about as wide as it is tall, with a strong readable silhouette. Menacing "
    "but funny, the same satirical universe: a prude censor plant. Palette: leaf greens, dark bark browns, grape "
    "purples, gold glasses, white teeth. "
)

PARRA_A = (
    STYLE
    + "BOSS SPRITE SHEET with exactly 2 rows of 4 huge poses (8 poses), the SAME enormous plant at the same scale "
    "in each cell, full body visible including the roots, nothing cropped. " + _PARRA +
    "Poses left to right, top row: (1) neutral idle, looming, tendrils swaying, smug toothy smile; (2) whip "
    "wind-up, one long tendril drawn far back over the crown like a coiled whip, the body leaning back, angry "
    "face; (3) whip strike, the tendril lashing far forward in a long curve with a snapping tip and motion lines, "
    "body lunging forward; (4) roots wind-up, the whole plant rearing, the roots lifting and glowing pale green "
    "at their tips, tremors. Bottom row: (5) roots erupt, thick sharp root spikes bursting up from the ground all "
    "around the base throwing soil, the plant shouting; (6) channeling a healing spell, eyes closed, serene, "
    "tendrils raised to the sky, a green glowing aura and floating sparkles, grapes glowing; (7) tired and "
    "drained, drooping, the crown sagging and panting, glasses crooked, sweat drop; (8) hurt, flinching and "
    "recoiling with squeezed eyes, glasses askew, a few leaves flying off."
)

PARRA_B = (
    STYLE
    + "BOSS SPRITE SHEET with exactly 1 row of 4 huge poses, the SAME enormous plant as the reference image "
    "(approved design: identical trunk, roots, tendrils, grape bunches, leaf face with glasses and teeth, same "
    "colors, proportions and art style), only the pose changes, same scale, full body visible, nothing cropped. "
    + _PARRA +
    "Poses left to right: (1) stunned and dizzy, eyes as swirls behind crooked glasses, tiny stars circling the "
    "crown, tendrils hanging limp, grapes dangling; (2) strangle attack, tendrils spread as wide as possible "
    "like a wall of vines reaching left and right across the whole picture, grim grin; (3) defeat part one: "
    "swaying and wilting, leaves yellowing and falling, grapes shriveling, glasses sliding off, shocked face, "
    "trunk bending; (4) defeat part two: collapsed and withered, a heap of dry brown vines, dead dull leaves and "
    "raisin-like shriveled grapes with the glasses cracked on top and X eyes on the face leaf, a tiny white flag "
    "of surrender."
)

HOJITA = (
    STYLE.replace("Characters face RIGHT in a three-quarter top-down game view. ", "")
    + "CHARACTER SPRITE SHEET with exactly 1 row of 8 small sprites, the SAME tiny minion at the same scale in each "
    "cell, full body, facing right in a three-quarter game view, very readable at a small size. THE MINION "
    "'Hojita Censora' (little censor leaf): a small bright green grapevine leaf sprout with five little lobes, "
    "same green and veins as the boss leaf in the reference image, with a thin black censor bar across its two "
    "angry white eyes, a small stern frowning mouth, and two tiny stick legs with little yellow shoes; a minion "
    "of the prude Fig Leaf boss. Poses left to right: (1) idle standing, stern; (2) moving step A, floating "
    "along with a small hop; (3) moving step B, the opposite stride; (4) planting a pixel patch (warning), "
    "crouching and slamming one lobe down, a small blocky mosaic square of colored pixels forming on the floor "
    "in front of it; (5) shooting, leaning back and spitting a small dark ink bullet forward from its open "
    "mouth, a puff; (6) hurt, flinching with squeezed eyes, the censor bar crooked; (7) dying part one, "
    "toppling backwards with the leaf curling; (8) dying part two, lying flat, wilted, dry brown-green leaf with "
    "an X on the censor bar."
)
