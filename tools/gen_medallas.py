#!/usr/bin/env python3
"""Genera assets/data/medallas.json y locale/medallas.csv (catalogo de MEDALLAS).

Fuente unica del catalogo: edita aqui y vuelve a correr
    python3 tools/gen_medallas.py && python3 tools/register_locales.py
Las condiciones las evalua src/autoloads/medallas.gd (ver su cabecera para los tipos).
Niveles: sonrojo (bronce) < destape (plata) < sin_pudor (oro); platino = Desnudo Integral.
"""
import csv
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def M(id, glifo, nivel, cond, nombre, desc, oculta=False):
    """nombre y desc: tuplas (es, en, fr)."""
    return dict(id=id, glifo=glifo, nivel=nivel, cond=cond, oculta=oculta, nombre=nombre, desc=desc)


# Jefes: id del script (boss_<id>.gd), nombre de la medalla, descripcion
JEFES = [
    ("cera", ("Depilación total", "Full Wax", "Épilation intégrale"),
     ("Vence a Doña Cera Caliente.", "Defeat Madame Hot Wax.", "Bats Madame Cire Chaude.")),
    ("afeitadora", ("Al ras", "Close Shave", "Rasé de près"),
     ("Vence a La Afeitadora Eléctrica.", "Defeat The Electric Shaver.", "Bats Le Rasoir Électrique.")),
    ("testiculo_primordial", ("Primordial, pero no eterno", "Primordial, Not Eternal", "Primordial, pas éternel"),
     ("Vence al Testículo Primordial.", "Defeat the Primordial Testicle.", "Bats le Testicule Primordial.")),
    ("don_sildenafil", ("Receta vencida", "Expired Prescription", "Ordonnance périmée"),
     ("Vence a Don Sildenafil.", "Defeat Don Sildenafil.", "Bats Monsieur Sildenafil.")),
    ("reina_ovaria", ("Viva la república", "Long Live the Republic", "Vive la République"),
     ("Vence a Su Majestad Ovaria II.", "Defeat Her Majesty Ovaria II.", "Bats Sa Majesté Ovaria II.")),
    ("diu_cosmico", ("Cósmico, pero no infalible", "Cosmic, Not Infallible", "Cosmique, pas infaillible"),
     ("Vence al DIU Cósmico.", "Defeat the Cosmic IUD.", "Bats le Stérilet Cosmique.")),
    ("aduanero", ("Nada que declarar", "Nothing to Declare", "Rien à déclarer"),
     ("Vence al Aduanero Hormonal.", "Defeat the Hormone Customs Officer.", "Bats le Douanier Hormonal.")),
    ("prostata", ("Ventanilla cerrada", "Window Closed", "Guichet fermé"),
     ("Vence a Doña Ventanilla.", "Defeat Ms. One-Stop.", "Bats Madame Guichet.")),
    ("hoja_de_parra", ("La hoja cae", "The Leaf Falls", "La feuille tombe"),
     ("Haz caer a Su Pudorosidad, la Hoja de Parra (o eso parece).",
      "Make Her Modesty, the Fig Leaf, fall (or so it seems).",
      "Fais tomber Sa Pudibonderie, la Feuille de Vigne (du moins, c'est ce qu'il semble).")),
    ("parra_entera", ("Raíz del problema", "Root of the Problem", "À la racine"),
     ("Vence a La Parra Entera.", "Defeat The Whole Vine.", "Bats La Parra Entière.")),
    ("algoritmo", ("Moderador moderado", "Moderator Moderated", "Modérateur modéré"),
     ("Vence al Algoritmo Moderador.", "Defeat the Moderator Algorithm.", "Bats l'Algorithme Modérateur.")),
    ("glandula", ("La callada habló", "The Quiet One Spoke", "La muette a parlé"),
     ("Vence a La Glándula Callada.", "Defeat The Silent Gland.", "Bats La Glande Muette.")),
    ("don_chequeo", ("Chequeo al chequeador", "Checking the Checker", "Bilan du bilan"),
     ("Vence a Don Chequeo.", "Defeat Mr. Check-Up.", "Bats Monsieur Bilan.")),
    ("regla", ("Ciclo cerrado", "Cycle Closed", "Cycle bouclé"),
     ("Vence a Doña Regla.", "Defeat Lady Period.", "Bats Madame Règles.")),
    ("destine", ("Colores a salvo", "Colors Saved", "Couleurs sauvées"),
     ("Vence a La Censura que Destiñe.", "Defeat The Censorship That Fades.", "Bats La Censure qui Déteint.")),
]

C = []
for jid, nom, desc in JEFES:
    cond = {"tipo": "jefe", "id": jid}
    if jid == "hoja_de_parra":
        cond = {"tipo": "evento", "id": "hoja_cae"}  # la 1a forma cae (la Parra entera es otra medalla)
    C.append(M("jefe_" + jid, "jefe", "sonrojo", cond, nom, desc))

# Variantes de los jefes emblematicos: sin recibir dano (Destape) y con Pudor alto (Sin Pudor)
SIN_DANO = [
    ("cera", ("Cera sin quemaduras", "Wax Without Burns", "Cire sans brûlures"),
     "Vence a Doña Cera Caliente sin recibir daño.", "Defeat Madame Hot Wax without taking damage.",
     "Bats Madame Cire Chaude sans subir de dégâts."),
    ("parra_entera", ("Podada sin un rasguño", "Pruned Without a Scratch", "Taillée sans une égratignure"),
     "Vence a La Parra Entera sin recibir daño.", "Defeat The Whole Vine without taking damage.",
     "Bats La Parra Entière sans subir de dégâts."),
    ("destine", ("Ni una mancha", "Not a Smudge", "Pas une tache"),
     "Vence a La Censura que Destiñe sin recibir daño.", "Defeat The Censorship That Fades without taking damage.",
     "Bats La Censure qui Déteint sans subir de dégâts."),
]
for jid, nom, d_es, d_en, d_fr in SIN_DANO:
    C.append(M("jefe_%s_intacto" % jid, "jefe", "destape", {"tipo": "jefe", "id": jid, "sin_dano": True}, nom, (d_es, d_en, d_fr)))
PUDOR = [
    ("cera", ("Caliente y sin pudor", "Hot and Shameless", "Chaude et sans pudeur"),
     "Vence a Doña Cera Caliente con Censura 5 o más.", "Defeat Madame Hot Wax at Censorship 5 or higher.",
     "Bats Madame Cire Chaude avec Censure 5 ou plus."),
    ("parra_entera", ("Sin hojas de parra", "No Fig Leaves", "Sans feuille de vigne"),
     "Vence a La Parra Entera con Censura 5 o más.", "Defeat The Whole Vine at Censorship 5 or higher.",
     "Bats La Parra Entière avec Censure 5 ou plus."),
    ("destine", ("Color a pesar de todo", "Colorful Despite Everything", "En couleurs malgré tout"),
     "Vence a La Censura que Destiñe con Censura 5 o más.", "Defeat The Censorship That Fades at Censorship 5 or higher.",
     "Bats La Censure qui Déteint avec Censure 5 ou plus."),
]
for jid, nom, d_es, d_en, d_fr in PUDOR:
    C.append(M("jefe_%s_pudor" % jid, "jefe", "sin_pudor", {"tipo": "jefe", "id": jid, "pudor_min": 5}, nom, (d_es, d_en, d_fr)))
C.append(M("jefes_intocable", "jefe", "sin_pudor", {"tipo": "jefes_sin_dano", "n": 5},
           ("Intocable", "Untouchable", "Intouchable"),
           ("Vence a 5 jefes distintos sin recibir daño.", "Defeat 5 different bosses without taking damage.",
            "Bats 5 boss différents sans subir de dégâts.")))

# Reinos liberados
C.append(M("reinos_3", "reino", "sonrojo", {"tipo": "reinos", "n": 3},
           ("Turista del cuerpo", "Body Tourist", "Touriste du corps"),
           ("Libera 3 reinos.", "Free 3 kingdoms.", "Libère 3 royaumes.")))
C.append(M("reinos_6", "reino", "destape", {"tipo": "reinos", "n": 6},
           ("Mochilero anatómico", "Anatomical Backpacker", "Routard anatomique"),
           ("Libera 6 reinos.", "Free 6 kingdoms.", "Libère 6 royaumes.")))
C.append(M("reinos_8", "reino", "sin_pudor", {"tipo": "reinos", "n": 8},
           ("Mapa sin tapar", "Uncovered Map", "Carte dévoilée"),
           ("Libera los 8 reinos.", "Free all 8 kingdoms.", "Libère les 8 royaumes.")))

# Final del juego
C.append(M("final_primero", "heroe", "sonrojo", {"tipo": "victoria"},
           ("Final feliz", "Happy Ending", "Fin heureuse"),
           ("Termina el juego por primera vez.", "Finish the game for the first time.", "Termine le jeu pour la première fois.")))
HEROES = [
    ("pitocles", "Pitocles", ("Penacho en alto", "Plume Held High", "Panache en l'air")),
    ("vulvalquiria", "Vulvalquiria", ("Trenzas al viento", "Braids in the Wind", "Tresses au vent")),
    ("ornitorrinco", "Ornitorrinco", ("Nadie sabe qué es", "Nobody Knows What It Is", "Personne ne sait ce que c'est")),
]
for hid, hn, nom in HEROES:
    C.append(M("final_" + hid, "heroe", "destape", {"tipo": "victoria", "heroe": hid}, nom,
               ("Termina el juego con %s." % hn, "Finish the game with %s." % hn, "Termine le jeu avec %s." % hn)))
C.append(M("final_trio", "heroe", "sin_pudor", {"tipo": "victoria_heroes", "n": 3},
           ("Elenco completo", "Full Cast", "Distribution complète"),
           ("Termina el juego con los 3 héroes.", "Finish the game with all 3 heroes.", "Termine le jeu avec les 3 héros.")))
C.append(M("final_pudor5", "heroe", "destape", {"tipo": "victoria", "pudor_min": 5},
           ("Bajo vigilancia", "Under Watch", "Sous surveillance"),
           ("Termina el juego con Censura 5 o más.", "Finish the game at Censorship 5 or higher.", "Termine le jeu avec Censure 5 ou plus.")))
C.append(M("final_pudor10", "heroe", "sin_pudor", {"tipo": "victoria", "pudor_min": 10},
           ("Censura máxima, pudor cero", "Max Censorship, Zero Shame", "Censure max, pudeur zéro"),
           ("Termina el juego con Censura 10.", "Finish the game at Censorship 10.", "Termine le jeu avec Censure 10.")))

# Codice
for pct, niv, nom in [(25, "sonrojo", ("Curioso", "Curious", "Curieux")),
                      (50, "destape", ("Rata de biblioteca", "Bookworm", "Rat de bibliothèque")),
                      (100, "sin_pudor", ("Libro abierto", "Open Book", "Livre ouvert"))]:
    C.append(M("codice_%d" % pct, "codice", niv, {"tipo": "codice", "pct": pct}, nom,
               ("Completa el %d%% del códice." % pct, "Complete %d%% of the codex." % pct, "Complète %d %% du codex." % pct)))

# Mapa de las banderas (src/arcoiria/banderas.gd): las 10 banderas del Orgullo, escondidas por los reinos
C.append(M("banderas_todas", "codice", "sin_pudor", {"tipo": "banderas"},
           ("Orgullo en todos los colores", "Pride in Every Color", "Fierté de toutes les couleurs"),
           ("Encuentra las 10 banderas del Mapa de las banderas.", "Find all 10 flags in the Flag Map.",
            "Trouve les 10 drapeaux de la Carte des drapeaux.")))

# Acertijos
for n, niv, nom in [(1, "sonrojo", ("Primera pista", "First Clue", "Premier indice")),
                    (10, "destape", ("Mente abierta", "Open Mind", "Esprit ouvert")),
                    (30, "sin_pudor", ("Esfinge jubilada", "Retired Sphinx", "Sphinx à la retraite"))]:
    d = (("Resuelve %d acertijo." if n == 1 else "Resuelve %d acertijos.") % n,
         "Solve %d puzzle%s." % (n, "" if n == 1 else "s"),
         "Résous %d énigme%s." % (n, "" if n == 1 else "s"))
    C.append(M("acertijos_%d" % n, "acertijo", niv, {"tipo": "contador", "nombre": "acertijos", "n": n}, nom, d))

# Pactos
C.append(M("pacto_menor", "pacto", "sonrojo", {"tipo": "evento", "id": "pacto_menor"},
           ("Letra chica", "Fine Print", "Petits caractères"),
           ("Cierra un pacto con la Hoja de Parra.", "Seal a pact with the Fig Leaf.", "Scelle un pacte avec la Feuille de Vigne.")))
C.append(M("pacto_mayor", "pacto", "destape", {"tipo": "evento", "id": "pacto_mayor"},
           ("Con maldición incluida", "Curse Included", "Malédiction incluse"),
           ("Sella un pacto mayor.", "Seal a major pact.", "Scelle un pacte majeur.")))

# Partida del dia
C.append(M("dia_jugar", "dia", "sonrojo", {"tipo": "evento", "id": "dia_jugar"},
           ("Cita de hoy", "Date of the Day", "Rendez-vous du jour"),
           ("Empieza la partida del día.", "Start the daily run.", "Commence la partie du jour.")))
C.append(M("dia_ganar", "dia", "destape", {"tipo": "victoria", "dia": True},
           ("Día ganado", "Day Won", "Jour gagné"),
           ("Gana la partida del día.", "Win the daily run.", "Gagne la partie du jour.")))

# Secretas
C.append(M("secreta_monte", "secreta", "sonrojo", {"tipo": "evento", "id": "monte_venus"},
           ("Vista desde la cima", "View from the Top", "Vue du sommet"),
           ("Llega a la cima del Monte de Venus.", "Reach the summit of Mount Venus.", "Atteins le sommet du Mont de Vénus."), True))
C.append(M("secreta_utero", "secreta", "destape", {"tipo": "evento", "id": "enter_utero"},
           ("Primera consulta", "First Appointment", "Première consultation"),
           ("Entra al Útero.", "Enter the Womb.", "Entre dans l'Utérus."), True))

C.append(M("secreta_anubis", "secreta", "destape", {"tipo": "evento", "id": "templo_anubis_puerta"},
           ("Siempre con protección", "Always Protected", "Toujours protégé·e"),
           ("Abre la puerta trasera del Perineo.", "Open the Perineum's back door.", "Ouvre la porte de derrière du Périnée."), True))

# Humor
C.append(M("humor_muerte", "humor", "sonrojo", {"tipo": "contador", "nombre": "muertes", "n": 1},
           ("Rojo de vergüenza", "Red with Embarrassment", "Rouge de honte"),
           ("Pierde tu primera partida.", "Lose your first run.", "Perds ta première partie.")))
C.append(M("humor_muertes_20", "humor", "destape", {"tipo": "contador", "nombre": "muertes", "n": 20},
           ("Cabeza dura", "Hard Head", "Tête dure"),
           ("Pierde 20 partidas.", "Lose 20 runs.", "Perds 20 parties.")))
C.append(M("humor_partidas_10", "humor", "sonrojo", {"tipo": "contador", "nombre": "partidas", "n": 10},
           ("Una más y me voy", "One More and I'm Out", "Une dernière et j'arrête"),
           ("Empieza 10 partidas.", "Start 10 runs.", "Commence 10 parties.")))

C.append(M("humor_masilla", "humor", "sonrojo", {"tipo": "contador", "nombre": "masillados", "n": 10},
           ("Con cariño", "With Love", "Avec tendresse"),
           ("Pega a 10 enemigos con masilla. Se lanza con cariño.", "Stick 10 enemies with body filler. Throw with love.",
            "Colle 10 ennemis avec du mastic. À lancer avec tendresse."), True))

# Platino
C.append(M("desnudo_integral", "final", "platino", {"tipo": "todas"},
           ("Desnudo Integral", "Full Monty", "Nu Intégral"),
           ("¡Desnudaste el juego! Consigue todas las demás medallas.", "You stripped the game bare! Earn every other medal.",
            "Tu as mis le jeu à nu ! Obtiens toutes les autres médailles.")))

NIVELES = {
    "sonrojo": ("Sonrojo", "Blush", "Rougeur"),
    "destape": ("Destape", "Exposed", "Dévoilé"),
    "sin_pudor": ("Sin Pudor", "Shameless", "Sans Pudeur"),
    "platino": ("Desnudo Integral", "Full Monty", "Nu Intégral"),
}
UI = [
    ("MEDAL_MENU_BTN", ("MEDALLAS", "MEDALS", "MÉDAILLES")),
    ("MEDAL_TITLE", ("MEDALLAS (%d/%d)", "MEDALS (%d/%d)", "MÉDAILLES (%d/%d)")),
    ("MEDAL_TOAST_HEAD", ("MEDALLA: %s", "MEDAL: %s", "MÉDAILLE : %s")),
    ("MEDAL_SECRET_NAME", ("???", "???", "???")),
    ("MEDAL_SECRET_DESC", ("Medalla secreta: se descubre jugando.", "Secret medal: discover it by playing.", "Médaille secrète : à découvrir en jouant.")),
    ("MEDAL_HINT", ("Pasa el cursor sobre una medalla para ver qué hay que hacer.", "Hover over a medal to see what it takes.", "Survole une médaille pour voir ce qu'il faut faire.")),
    ("MEDAL_PROGRESS", ("Hacia Desnudo Integral: %d/%d", "Toward Full Monty: %d/%d", "Vers Nu Intégral : %d/%d")),
    ("MEDAL_COUNT_LINE", ("%s: %d/%d", "%s: %d/%d", "%s : %d/%d")),
    ("MEDAL_LOCKED", ("Bloqueada", "Locked", "Verrouillée")),
    ("MEDAL_FINALE_TITLE", ("DESNUDO INTEGRAL", "FULL MONTY", "NU INTÉGRAL")),
    ("MEDAL_FINALE_SUB", ("¡Desnudaste el juego!", "You stripped the game bare!", "Tu as mis le jeu à nu !")),
    ("MEDAL_FINALE_CONT", ("Pulsa para seguir", "Press to continue", "Appuie pour continuer")),
]


def main():
    ids = [m["id"] for m in C]
    assert len(ids) == len(set(ids)), "ids repetidos"
    data = []
    rows = []
    for k, (es, en, fr) in UI:
        rows.append([k, es, en, "", fr])
    for k, v in NIVELES.items():
        rows.append(["MEDAL_LEVEL_" + k.upper(), v[0], v[1], "", v[2]])
    for m in C:
        nk = "MEDAL_%s_NAME" % m["id"].upper()
        dk = "MEDAL_%s_DESC" % m["id"].upper()
        rows.append([nk, m["nombre"][0], m["nombre"][1], "", m["nombre"][2]])
        rows.append([dk, m["desc"][0], m["desc"][1], "", m["desc"][2]])
        data.append({"id": m["id"], "nombre_key": nk, "desc_key": dk, "nivel": m["nivel"],
                     "condicion": m["cond"], "oculta": m["oculta"], "icono": m["glifo"]})
    out = ROOT / "assets/data/medallas.json"
    out.write_text(json.dumps({"_nota": "Generado por tools/gen_medallas.py; condiciones en src/autoloads/medallas.gd",
                               "medallas": data}, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    with (ROOT / "locale/medallas.csv").open("w", newline="", encoding="utf-8") as fh:
        w = csv.writer(fh, lineterminator="\n")
        w.writerow(["keys", "es", "en", "es_ES", "fr"])
        w.writerows(rows)
    print(len(data), "medallas,", len(rows), "textos")


if __name__ == "__main__":
    main()
