#!/usr/bin/env python3
"""Regenera `locale/translations` de project.godot con todos los locale/*.csv.

Convencion: cada bloque crea SU locale/<bloque>.csv (cabecera keys,es,en) y no toca los
de otros. Godot importa cada CSV a locale/<bloque>.<idioma>.translation (una por columna).
Este script lista esas .translation a partir de las cabeceras de los CSV (asi funciona
tambien en un clon limpio, antes de importar) y reescribe la linea de project.godot:
conserva el orden de las que ya estaban, quita las de CSV borrados y agrega las nuevas en
orden alfabetico.

No es obligatorio: Loc.load_unregistered_translations() carga en runtime (editor y export)
cualquier .translation de locale/ que falte aqui. Sirve para dejar project.godot al dia
(p.ej. al integrar ramas: si dos ramas agregan un CSV y chocan en esta linea, basta con
quedarse con cualquiera de las dos y volver a correr el script).

Uso:  python3 tools/register_locales.py           reescribe project.godot si hace falta
      python3 tools/register_locales.py --check   solo comprueba (sale con 1 si no esta al dia)
"""
import csv
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PROJECT = ROOT / "project.godot"
LINE = re.compile(r'^locale/translations=PackedStringArray\((.*)\)$', re.M)


def wanted() -> list:
    out = []
    for p in sorted((ROOT / "locale").glob("*.csv")):
        with p.open(newline="", encoding="utf-8") as fh:
            header = next(csv.reader(fh), [])
        if header[:1] != ["keys"]:
            print(f"aviso: {p.name} no empieza por 'keys', se ignora")
            continue
        # columnas vacias o que empiezan por '_' las ignora el importador de Godot
        out += [f"res://locale/{p.stem}.{lang}.translation" for lang in header[1:] if lang and not lang.startswith("_")]
    return out


def main() -> int:
    text = PROJECT.read_text(encoding="utf-8")
    m = LINE.search(text)
    current = re.findall(r'"([^"]*)"', m.group(1)) if m else []
    want = wanted()
    new = [p for p in current if p in want] + [p for p in want if p not in current]
    if new == current:
        print(f"project.godot al dia ({len(new)} traducciones)")
        return 0
    added = [p for p in new if p not in current]
    removed = [p for p in current if p not in new]
    for p in added:
        print(f"+ {p}")
    for p in removed:
        print(f"- {p}")
    if "--check" in sys.argv:
        print("project.godot no esta al dia: corre python3 tools/register_locales.py")
        return 1
    line = "locale/translations=PackedStringArray(%s)" % ", ".join(f'"{p}"' for p in new)
    if m:
        text = text[:m.start()] + line + text[m.end():]
    elif "[internationalization]" in text:
        text = text.replace("[internationalization]\n", "[internationalization]\n\n" + line + "\n", 1)
    else:
        text = text.rstrip("\n") + "\n\n[internationalization]\n\n" + line + "\n"
    PROJECT.write_text(text, encoding="utf-8")
    print(f"project.godot actualizado ({len(new)} traducciones)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
