#!/usr/bin/env python3
"""Junta registros de peleas de jefe del bot (lineas "[J0] clave=valor ...") en una tabla markdown.

Uso:  python3 tools/autoplay/tabla_jefes.py <archivo|carpeta> [...]   > tabla.md
Lee los .log del bot y los .out de Godot (la salida estandar guardada), sin duplicar peleas.
Tambien recoge las lineas "[boss-stats]" y "[boss-dmg]" que impriman otros modulos (solo estan en el .out)
y las agrega bajo la tabla, junto al nombre de la pelea.
Columnas: heroe, semilla, arma, resultado, dur(s), golpes, dano recibido, vida restante, dps, % ataque / agotado,
curas (cortadas), golpe max (arma). Al final, promedios por jefe+arma.
"""
import re
import sys
from pathlib import Path

KV = re.compile(r"(\w+)=(\S+)")


def archivos(args):
    out = []
    for a in args:
        p = Path(a)
        if p.is_dir():
            out += sorted(list(p.glob("*.log")) + list(p.glob("*.out")))
        elif p.exists():
            out.append(p)
    return out


def leer(paths):
    peleas = {}  # clave unica -> dict
    extras = {}  # nombre base -> lineas [boss-stats]/[boss-dmg]
    for p in paths:
        base = p.stem
        for ln in p.read_text(errors="replace").splitlines():
            i = ln.find("[J0]")
            if i >= 0:
                d = dict(KV.findall(ln[i:]))
                key = (d.get("jefe"), d.get("heroe"), d.get("semilla"), d.get("arma"), d.get("god"))
                d["_base"] = base
                peleas[key] = d
                continue
            for tag in ("[boss-stats]", "[boss-dmg]"):
                j = ln.find(tag)
                if j >= 0:
                    lst = extras.setdefault(base, [])
                    t = ln[j:].strip()
                    if t not in lst:
                        lst.append(t)
    return peleas, extras


def f(d, k, nd=0):
    try:
        return ("%." + str(nd) + "f") % float(d[k])
    except (KeyError, ValueError):
        return "-"


def media(rows, k):
    v = []
    for r in rows:
        try:
            v.append(float(r[k]))
        except (KeyError, ValueError):
            pass
    return sum(v) / len(v) if v else float("nan")


def main():
    peleas, extras = leer(archivos(sys.argv[1:]))
    if not peleas:
        print("(sin peleas [J0] en los registros)")
        return
    rows = sorted(peleas.values(), key=lambda d: (d.get("jefe", ""), d.get("arma", ""), d.get("heroe", ""), int(d.get("semilla", 0) or 0)))
    print("| jefe | heroe | semilla | arma | resultado | dur (s) | golpes | dano rec. | vida jefe restante | dps | % ataque | % agotado | curas (cortadas) | golpe max (arma) |")
    print("|---|---|---|---|---|---|---|---|---|---|---|---|---|---|")
    for d in rows:
        print("| %s | %s | %s | %s | %s | %s | %s | %s | %s/%s | %s | %s | %s | %s (%s) | %s (%s) |" % (
            d.get("jefe", "?"), d.get("heroe", "?"), d.get("semilla", "?"), d.get("arma", "?"), d.get("resultado", "?"),
            f(d, "dur", 1), d.get("golpes", "-"), f(d, "dano_rec"), f(d, "vida_restante"), f(d, "vida_max"), f(d, "dps", 1),
            f(d, "pct_ataque"), f(d, "pct_agotado"), d.get("curas", "-"), d.get("cortadas", "-"), f(d, "golpe_max"), d.get("arma_golpe_max", "-")))
    print()
    print("Promedios por jefe y arma:")
    print()
    print("| jefe | arma | peleas | victorias | dur (s) | golpes | dano rec. | dps | % ataque | % agotado | curas | cortadas | golpe max |")
    print("|---|---|---|---|---|---|---|---|---|---|---|---|---|")
    grupos = {}
    for d in rows:
        grupos.setdefault((d.get("jefe", "?"), d.get("arma", "?")), []).append(d)
    for (jefe, arma), g in grupos.items():
        gana = sum(1 for d in g if d.get("resultado") == "victoria")
        print("| %s | %s | %d | %d | %.1f | %.1f | %.0f | %.1f | %.0f | %.0f | %.1f | %.1f | %.0f |" % (
            jefe, arma, len(g), gana, media(g, "dur"), media(g, "golpes"), media(g, "dano_rec"), media(g, "dps"),
            media(g, "pct_ataque"), media(g, "pct_agotado"), media(g, "curas"), media(g, "cortadas"), max(float(d.get("golpe_max", 0) or 0) for d in g)))
    if extras:
        print()
        print("Lineas de otros modulos ([boss-stats] / [boss-dmg]):")
        for base in sorted(extras):
            for ln in extras[base]:
                print("- `%s`: %s" % (base, ln))


if __name__ == "__main__":
    main()
