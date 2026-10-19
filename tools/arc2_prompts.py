"""Prompts de las hojas de Gemini del arte definitivo de Arcoiria (ver gen_arcoiria_art2.py).

Una hoja = una llamada. Regla de contenido: el humor va contra el PREJUICIO (chisme, comentario,
mirada, etiqueta, armario), nunca contra personas LGBTIQ+.
"""
from arc2_gemini import STYLE

POSES7 = (
    "Columns left to right, the SAME character in 7 poses: (1) idle standing, grumpy; (2) walking step A; "
    "(3) walking step B (opposite stride); (4) attack wind-up, anticipation, leaning back and gathering force; "
    "(5) attack strike, lunging forward, mouth open; (6) hurt, flinching with squeezed eyes and a pained face; "
    "(7) defeated, deflating or collapsing with X eyes. "
)

COMMONS = (
    STYLE
    + "CHARACTER SPRITE SHEET with exactly 3 rows and 7 columns (21 sprites). Each row is one enemy of a pride-parade "
    "kingdom made of PREJUDICE, drawn as small grumpy gray-ish paper-thin walking objects with tiny legs (full body, "
    "same size across the row, about 2 head-heights tall). " + POSES7 +
    "ROW 1: 'Rumor Ambulante' - a lilac-gray ghost-like gossip blob with one huge pink ear on its side, little feet, "
    "whispers. ROW 2: 'Comentario Inoportuno' - a white speech bubble with a tail pointing down, a '?!' mark on its "
    "top, smug annoyed face, little legs; its attack pose has the bubble open mouth shouting. ROW 3: 'Mirada de Reojo' "
    "- a giant eyeball with a heavy half-closed eyelid, bushy eyebrow, a teal iris looking sideways with suspicion, "
    "small brown shoes. Colors for the three: mostly desaturated lavender, white and flesh pink with ONE saturated "
    "accent each. Draw them as a clean aligned grid on the green background."
)

PREJ_A = (
    STYLE
    + "CHARACTER SPRITE SHEET with exactly 2 rows. Each row is one enemy of a pride-parade kingdom made of PREJUDICE, "
    "a small grumpy walking object with tiny legs (full body, same size across the row). ROW 1 has 9 columns, ROW 2 "
    "has 9 columns. Columns left to right: (1) idle standing, grumpy; (2) walking step A; (3) walking step B "
    "(opposite stride); (4) attack wind-up, anticipation; (5) attack strike, lunging, mouth open; (6) hurt, flinching "
    "with squeezed eyes; (7) defeated, collapsing with X eyes; (8) and (9) are the special states described below. "
    "ROW 1: 'Es una fase' - a yellow crescent moon with a smug sleepy face, little golden sparkles, little yellow "
    "boots. Special (8): 'new moon' state, the moon is a dark navy disc with a faint outline, sparkles, eyes closed, "
    "almost invisible; (9): the same dark new-moon disc but flickering open one angry eye. ROW 2: 'El Armario' - a "
    "tall brown wooden wardrobe with an angry face on the door crack, a tiny rainbow pride flag peeking through the "
    "crack, little feet; its attack is doors flung open. Special (8): wardrobe OPEN, both doors wide open showing a "
    "joyful rainbow of hanging colorful clothes inside, with a glow; (9): wardrobe open slightly different frame "
    "with clothes swaying and little confetti. Same dark outline for all. Clean aligned grid."
)

PREJ_B = (
    STYLE
    + "CHARACTER SPRITE SHEET with exactly 2 rows. Each row is one enemy of a pride-parade kingdom made of PREJUDICE, "
    "a small grumpy walking object with tiny legs (full body). ROW 1 'Y quien es el hombre?' - an oval body split "
    "vertically: LEFT half baby-blue with an upside-down question mark symbol, RIGHT half pink with a question mark "
    "symbol, one grumpy angry face across the middle, dark legs. ROW 1 has 9 columns: (1) idle, (2) walk step A, (3) "
    "walk step B, (4) attack wind-up, (5) attack strike, (6) hurt, (7) defeated with X eyes, (8) ONLY the LEFT blue "
    "half alone as an independent half-oval creature with its own face, one arm and one leg, idle; (9) ONLY the RIGHT "
    "pink half alone as an independent half-oval creature with its own face, idle. ROW 2 has 7 columns: 'La Etiqueta' "
    "- a yellow clothing price tag with a pink string loop on top, a barcode of black lines at the bottom, a grumpy "
    "judging face, tiny legs; (1) idle, (2) walk A, (3) walk B, (4) attack wind-up (flicking a sticky label), (5) "
    "attack strike (throwing the label), (6) hurt, (7) defeated, crumpled with X eyes. Clean aligned grid."
)

_BOSS = (
    "THE BOSS 'La Censura que destine' ('The Censorship that Fades'): a gray bureaucratic censor clerk, a tall chunky "
    "figure with a gray top hat, a black censor-bar over his eyes with two angry white eyes, a stitched zipper mouth, a "
    "light-gray lab coat whose bottom hem is stained with the six rainbow colors (red, orange, yellow, green, blue, "
    "violet) like bar-chart bars, big gray hands, one holding a giant gray paint ROLLER on a long orange wooden pole "
    "(dripping gray paint), the other holding a big rubber STAMP / seal that says CENSURADO-style bar marks (no real "
    "words). He drains color from everything. Gray palette with just the small rainbow hem. "
)

BOSS_A = (
    STYLE
    + "BOSS SPRITE SHEET with exactly 2 rows of 4 large poses (8 poses), the SAME big character at the same scale in "
    "each cell, full body visible, grounded. " + _BOSS +
    "Poses left to right, top row: (1) neutral idle, menacing and smug, roller resting by his side; (2) roller "
    "wind-up, leaning far back with the giant roller raised high over his head; (3) roller strike, lunging forward "
    "swinging the roller down hard, gray paint splashing; (4) stamp wind-up, raising the huge stamp overhead. "
    "Bottom row: (5) stamp strike, slamming the stamp forward, motion lines; (6) tired and drained, slumped and "
    "panting, hat crooked, the roller dragging, the rainbow hem dripping onto the floor; (7) channeling a healing "
    "spell, arms raised, eyes closed, a pale gray aura swirling around him; (8) hurt, flinching backwards with the "
    "black bar cracked and a pained face."
)

BOSS_B = (
    STYLE
    + "BOSS SPRITE SHEET with exactly 1 row of 4 large poses, the SAME character as the reference image (use it as "
    "the approved design: identical hat, censor bar, coat, rainbow hem, roller and stamp, same colors and "
    "proportions, same art style), only the pose changes, same scale. " + _BOSS +
    "Poses left to right: (1) dramatic intro entrance, arms spread wide, roller in one hand and stamp in the other, "
    "chin up; (2) charging forward at full speed, leaning way ahead, roller trailing behind, speed feeling; (3) "
    "stunned and dizzy, eyes as swirls under a crooked bar, small gray stars circling his hat, arms limp; (4) "
    "defeated, colorless gray figure melting and washing out into a gray puddle, the rainbow hem bursting into "
    "colorful paint splashes, the hat falling, X eyes."
)

ICONS = (
    STYLE.replace("Characters face RIGHT in a three-quarter top-down game view. ", "")
    + "ICON SHEET with exactly 1 row of 7 round medallion icons (inventory item icons, each a round glossy medallion "
    "with a thick dark outline and a white pictogram in the center), all the same size, bold simple pictograms that "
    "read at 24x24 pixels. Left to right: (1) RED medallion with a white heart (life); (2) ORANGE medallion with a "
    "white adhesive bandage (healing); (3) YELLOW medallion with a white sun with rays (light); (4) GREEN medallion "
    "with a white leaf (growth); (5) BLUE medallion with a white water drop with a tiny smiling face (calm); (6) "
    "VIOLET medallion with a white drop with a sparkle (magic); (7) a golden round medallion with a small waving "
    "rainbow pride flag of six stripes red-orange-yellow-green-blue-violet on a pole (complete flag synergy). "
    "Each icon medallion is separate on the green background."
)

FLOOR = (
    STYLE.replace("Characters face RIGHT in a three-quarter top-down game view. ", "")
    + "TILESET SHEET of FLOOR SLABS, seen straight from above (top-down): a grid of exactly 4 columns x 3 rows = 12 "
    "separate SQUARE paving slabs of the same size, each slab a complete square tile with a thin darker grout "
    "joint line around its edge and a gentle bevel (light top-left, dark bottom-right). Theme: a festive pride "
    "parade plaza of the kingdom of Arcoiria - glazed ceramic and terrazzo slabs in a soft rainbow palette (rose, "
    "peach, butter yellow, mint, sky blue, lavender) with low-contrast confetti speckles. Every slab must have "
    "CLEAR LIGHTNESS differences so that it still reads in grayscale. Rows 1-2 (8 slabs): plain slabs in different "
    "pastel colors with different subtle speckle and hairline cracks. Row 3 (4 slabs): ornate slabs: (a) a six-color "
    "star, (b) a heart, (c) a small rainbow arc, (d) confetti burst. Keep decoration away from the edges of the "
    "slab, no shadows outside the slab. Slabs separated by green gap."
)

MOTIF = (
    STYLE.replace("Characters face RIGHT in a three-quarter top-down game view. ", "")
    + "ONE single large square floor MOSAIC MEDALLION seen straight from above, filling most of the image: a "
    "circular ceremonial rosette of a pride-parade plaza, concentric rings in the six rainbow colors (red, orange, "
    "yellow, green, blue, violet) around a central star, with a ring of small triangle bunting flags, glazed tile "
    "mosaic with grout, light top-left. The medallion is centered, circular, on a square cream-colored stone ground "
    "that fills the entire square image to all four edges (NO green background for this one). Symmetric, high "
    "contrast, readable in grayscale."
)

WALL = (
    STYLE.replace("Characters face RIGHT in a three-quarter top-down game view. ", "")
    + "WALL TILESET SHEET for a top-down 3/4 view dungeon: a clean grid of 3 columns x 2 rows, 6 separate pieces "
    "on green. Theme: the festive parade-street of the kingdom of Arcoiria, plaster and brick walls painted in "
    "rainbow stripes with bunting. (1) Wall FRONT FACE piece, a wide square 1:1 panel: plastered wall painted with "
    "horizontal rainbow stripes in soft saturated bands, with a baseboard at the bottom and a cornice at the top; "
    "(2) a second wall FRONT FACE variant: warm brick with painted bunting garland line; (3) wall TOP CAP piece "
    "seen from above, square: a flat roof/parapet top of cream stone with small colored tile trim; (4) a hanging "
    "BUNTING banner of triangle flags in six colors, vertical-ish, narrow; (5) a MURAL panel, framed painting of a "
    "sunny rainbow over hills, portrait; (6) a round porthole WINDOW with colored stained glass in six wedge "
    "colors, brass frame. Each piece fully inside its cell, flat front view."
)

DECOR = (
    STYLE
    + "PROPS SHEET of 8 separate decor objects for a festive pride-parade street (tiny game props, 3/4 top-down "
    "view, each fully inside its own cell, 4 columns x 2 rows): (1) a short string of triangle bunting flags on two "
    "tiny poles, six colors; (2) an ornate street LANTERN lamppost with a warm glowing rainbow-glass lantern; (3) a "
    "round flower planter pot with colorful flowers; (4) a crumpled gray censorship poster half-torn off a wall "
    "revealing a colorful mural underneath (no readable text); (5) a small float cart with confetti and balloons; "
    "(6) a rainbow-colored beach umbrella closed lying; (7) a big 'drum' bass drum with a rainbow stripe; (8) a "
    "stack of gift boxes with ribbons. Strong dark outlines."
)
