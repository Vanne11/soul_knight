"""Iconos 24x24 de los objetos de la etapa 3b (toallas, tampon, lado pene, latigo, latex, jaula).

Uso: python3 tools/gen_item_art_3b.py [id ...]   (sin args = todos)
Mismo estilo que tools/gen_item_art.py (primitivas de Pillow + contorno automatico #0d0b0f).
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from gen_item_art import OUT, _c, _new, _outline  # noqa: E402


def art_towel_mesh():
    im, d = _new()
    body, shade = _c(246, 246, 252), _c(196, 202, 224)
    d.polygon([(2, 9), (8, 9), (8, 15), (2, 14)], fill=shade)            # alas
    d.polygon([(21, 9), (15, 9), (15, 15), (21, 14)], fill=shade)
    d.rounded_rectangle([7, 2, 16, 21], radius=4, fill=body)             # cuerpo
    d.rectangle([9, 5, 14, 18], fill=_c(214, 222, 240))                  # zona absorbente
    for y in range(5, 19):                                               # la malla: rejilla de puntos
        for x in range(9, 15):
            if (x + y) % 2 == 0:
                d.point((x, y), fill=_c(120, 140, 190))
    d.line([(8, 4), (15, 4)], fill=_c(255, 255, 255))
    d.line([(8, 19), (15, 19)], fill=shade)
    d.point([(4, 11), (19, 11)], fill=_c(150, 156, 190))                  # broche de las alas
    return _outline(im)


def art_towel_cotton():
    im, d = _new()
    body, shade = _c(255, 247, 232), _c(224, 204, 170)
    d.polygon([(2, 9), (8, 9), (8, 15), (2, 14)], fill=shade)
    d.polygon([(21, 9), (15, 9), (15, 15), (21, 14)], fill=shade)
    d.rounded_rectangle([7, 2, 16, 21], radius=4, fill=body)
    for y in range(5, 19, 3):                                            # pespunte de algodon
        d.line([(9, y), (10, y)], fill=shade)
        d.line([(12, y), (13, y)], fill=shade)
    d.ellipse([10, 9, 13, 12], fill=_c(255, 150, 190))                    # florcita
    d.point([(11, 10), (12, 11)], fill=_c(255, 235, 120))
    d.line([(11, 13), (11, 15)], fill=_c(110, 180, 110))
    d.line([(8, 4), (15, 4)], fill=_c(255, 255, 255))
    return _outline(im)


def art_towel_night():
    im, d = _new()
    body, shade = _c(70, 72, 140), _c(40, 42, 96)
    d.polygon([(1, 12), (7, 12), (7, 20), (1, 19)], fill=shade)           # alas largas
    d.polygon([(22, 12), (16, 12), (16, 20), (22, 19)], fill=shade)
    d.rounded_rectangle([6, 0, 17, 23], radius=4, fill=body)
    d.ellipse([9, 4, 15, 10], fill=_c(255, 236, 140))                     # luna
    d.ellipse([11, 3, 17, 9], fill=body)
    d.point([(10, 13), (14, 15), (11, 18), (15, 11)], fill=_c(255, 245, 190))   # estrellas
    d.line([(8, 1), (15, 1)], fill=_c(120, 124, 200))
    return _outline(im)


def art_tampon():
    im, d = _new()
    white, shade = _c(250, 248, 252), _c(200, 196, 214)
    d.rounded_rectangle([8, 2, 15, 14], radius=3, fill=white)             # aplicador
    d.line([(9, 4), (9, 12)], fill=_c(255, 255, 255))
    d.line([(14, 4), (14, 12)], fill=shade)
    d.line([(8, 7), (15, 7)], fill=_c(255, 150, 190))                     # franja rosa
    d.rectangle([7, 14, 16, 16], fill=_c(255, 150, 190))                  # agarre
    d.rectangle([7, 14, 16, 14], fill=_c(255, 190, 215))
    d.rectangle([10, 16, 13, 20], fill=_c(255, 214, 230))                 # embolo
    d.line([(12, 20), (12, 21)], fill=white)                              # hilo
    d.line([(12, 21), (14, 22)], fill=white)
    d.point([(15, 22)], fill=white)
    return _outline(im)


def art_talc():
    im, d = _new()
    d.rounded_rectangle([6, 7, 17, 21], radius=2, fill=_c(80, 150, 255))   # bote azul
    d.line([(7, 9), (7, 19)], fill=_c(150, 200, 255))
    d.line([(16, 9), (16, 19)], fill=_c(40, 90, 200))
    d.rectangle([6, 4, 17, 7], fill=_c(240, 242, 250))                     # tapa con agujeritos
    d.point([(9, 5), (12, 5), (15, 5)], fill=_c(150, 156, 176))
    d.rectangle([8, 11, 15, 17], fill=_c(255, 255, 255))                   # etiqueta
    d.line([(9, 14), (14, 14)], fill=_c(80, 150, 255))
    d.point([(11, 12), (12, 12)], fill=_c(255, 150, 190))
    for p in ((10, 1), (13, 2), (15, 0), (8, 2), (17, 3)):                 # nubecita de talco
        d.point(p, fill=_c(255, 255, 255))
    return _outline(im)


def art_emergency_briefs():
    im, d = _new()
    white, shade, blue = _c(248, 250, 255), _c(200, 208, 230), _c(70, 140, 255)
    d.rectangle([3, 4, 20, 7], fill=blue)                                  # cintura
    d.line([(3, 5), (20, 5)], fill=_c(130, 180, 255))
    d.polygon([(3, 8), (20, 8), (19, 13), (15, 20), (12, 17), (9, 20), (4, 13)], fill=white)
    d.polygon([(12, 17), (15, 20), (19, 13), (14, 12)], fill=shade)
    d.line([(4, 12), (9, 19)], fill=blue)                                  # elastico de las piernas
    d.line([(19, 12), (14, 19)], fill=blue)
    d.rectangle([11, 9, 12, 14], fill=_c(232, 70, 90))                     # cruz de "emergencia"
    d.rectangle([9, 11, 14, 12], fill=_c(232, 70, 90))
    d.point([(6, 10), (17, 10)], fill=_c(255, 240, 110))                   # limpios: brillitos
    return _outline(im)


def art_deodorant_machote():
    im, d = _new()
    d.rounded_rectangle([7, 7, 16, 21], radius=2, fill=_c(58, 60, 78))     # lata
    d.line([(8, 9), (8, 19)], fill=_c(110, 114, 140))
    d.rectangle([8, 4, 15, 7], fill=_c(216, 221, 227))                      # tapa
    d.rectangle([10, 2, 13, 4], fill=_c(232, 70, 70))                       # boton
    d.rectangle([7, 11, 16, 17], fill=_c(216, 221, 227))                    # etiqueta
    d.polygon([(8, 15), (9, 13), (11, 14), (12, 13), (14, 14), (15, 13), (15, 16), (12, 15), (9, 16)], fill=_c(40, 24, 20))  # bigote
    for p, c in (((15, 2), (160, 230, 170)), ((17, 1), (190, 240, 190)), ((18, 4), (150, 220, 160)), ((20, 2), (200, 245, 200)), ((16, 4), (150, 220, 160))):
        d.rectangle([p[0], p[1], p[0] + 1, p[1] + 1], fill=_c(*c))          # spray
    return _outline(im)


def art_testicle_kit():
    im, d = _new()
    d.rounded_rectangle([3, 7, 20, 20], radius=2, fill=_c(80, 190, 190))   # estuche
    d.rectangle([3, 7, 20, 9], fill=_c(50, 140, 150))
    d.rectangle([10, 3, 13, 7], fill=_c(50, 140, 150))                      # asa
    d.rectangle([11, 11, 12, 18], fill=_c(255, 255, 255))                   # cruz blanca
    d.rectangle([8, 14, 15, 15], fill=_c(255, 255, 255))
    d.line([(4, 10), (4, 18)], fill=_c(150, 230, 225))
    d.polygon([(17, 12), (19, 12), (20, 15), (18, 17), (16, 15)], fill=_c(130, 190, 255))   # liston azul claro
    d.point([(5, 19), (19, 19)], fill=_c(40, 110, 120))
    return _outline(im)


def art_psa_test():
    im, d = _new()
    d.rounded_rectangle([9, 4, 14, 21], radius=2, fill=_c(225, 240, 250))   # tubo de vidrio
    d.rectangle([10, 10, 13, 20], fill=_c(214, 40, 70))                      # sangre
    d.line([(10, 10), (13, 10)], fill=_c(255, 130, 150))
    d.line([(10, 5), (10, 19)], fill=_c(255, 255, 255))
    d.rectangle([8, 2, 15, 5], fill=_c(70, 140, 255))                        # tapon azul
    d.line([(8, 3), (15, 3)], fill=_c(150, 195, 255))
    d.rectangle([9, 13, 13, 16], fill=_c(255, 255, 255))                     # etiqueta
    d.point([(10, 14), (12, 14), (11, 15)], fill=_c(70, 140, 255))
    d.polygon([(19, 9), (21, 13), (19, 15), (17, 13)], fill=_c(214, 40, 70))  # gota
    d.point([(19, 12)], fill=_c(255, 150, 170))
    return _outline(im)


def art_whip():
    im, d = _new()
    leather, hi, dark = _c(150, 96, 52), _c(204, 146, 90), _c(84, 48, 26)
    d.line([(3, 21), (7, 16)], fill=dark, width=4)                           # mango
    d.line([(3, 21), (6, 17)], fill=_c(60, 40, 40), width=2)
    pts = [(7, 16), (9, 12), (12, 9), (16, 7), (20, 8), (21, 12), (18, 14)]  # tira
    d.line(pts, fill=leather, width=2)
    d.line([(9, 12), (12, 9), (16, 7)], fill=hi, width=1)
    d.rectangle([17, 13, 19, 15], fill=_c(232, 70, 70))                      # punta
    d.rectangle([6, 15, 8, 17], fill=_c(216, 221, 227))                      # virola
    return _outline(im)


def art_latex_suit():
    im, d = _new()
    body, hi, dark = _c(44, 32, 70), _c(120, 98, 176), _c(26, 18, 44)
    d.polygon([(8, 2), (10, 3), (14, 3), (16, 2), (21, 6), (18, 11), (16, 9), (16, 21), (13, 22), (13, 15), (11, 15), (11, 22), (8, 21), (8, 9), (6, 11), (3, 6)], fill=body)
    d.polygon([(8, 2), (10, 3), (14, 3), (16, 2), (21, 6), (20, 7), (16, 4), (12, 5), (8, 4), (4, 7), (3, 6)], fill=dark)
    d.line([(9, 6), (9, 19)], fill=hi)                                       # brillos de latex
    d.line([(10, 5), (10, 8)], fill=_c(200, 180, 245))
    d.line([(15, 12), (15, 19)], fill=_c(78, 60, 124))
    d.line([(12, 3), (12, 14)], fill=_c(210, 210, 222))                      # cierre
    d.point([(12, 3)], fill=_c(255, 255, 255))
    return _outline(im)


def art_cursed_cage():
    im, d = _new()
    iron, hi, dark = _c(134, 138, 153), _c(216, 221, 227), _c(70, 72, 86)
    d.arc([5, 4, 19, 18], 180, 360, fill=iron, width=2)                      # domo
    for x in (6, 9, 12, 15, 18):
        d.line([(x, 10 if x in (6, 18) else 7 if x in (9, 15) else 5), (x, 18)], fill=iron)
    d.ellipse([4, 16, 20, 21], fill=dark)                                    # base
    d.ellipse([5, 16, 19, 19], fill=iron)
    d.ellipse([10, 1, 14, 5], outline=hi, width=1)                           # anilla
    d.rectangle([10, 12, 14, 17], fill=_c(255, 214, 90))                     # candado
    d.arc([10, 9, 14, 14], 180, 360, fill=_c(224, 168, 40), width=1)
    d.point([(12, 14)], fill=_c(90, 50, 20))
    for p in ((2, 6), (21, 5), (3, 14), (21, 13)):                           # aura maldita
        d.rectangle([p[0], p[1], p[0], p[1] + 1], fill=_c(176, 70, 210))
    d.point([(1, 10), (22, 9)], fill=_c(120, 40, 160))
    return _outline(im)


ART3B = {n[4:]: f for n, f in globals().items() if n.startswith("art_")}

if __name__ == "__main__":
    for name in sys.argv[1:] or list(ART3B):
        ART3B[name]().save(OUT / f"{name}.png")
        print("ok", name)
