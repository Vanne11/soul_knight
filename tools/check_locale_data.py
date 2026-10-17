#!/usr/bin/env python3
"""Comprueba locale/items|lore|narrator|world.csv contra los datos del juego.

- Todas las claves que Loc puede pedir existen (y no sobran).
- Ninguna columna de idioma vacia (salvo que el espanol tambien lo este).
- Los placeholders ({x}, %d, %s, %%) y las etiquetas [b]/[i] coinciden entre es y en.
Sale con codigo 1 si hay errores.
"""
import csv
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import extract_locale_data as ex  # noqa: E402

# {x} (str.format del narrador), etiquetas bbcode, y %s solo en claves *_FMT (el resto
# de '%' son porcentajes literales: esos textos no se pasan por el operador %).
PLACEHOLDER = re.compile(r"\{\w+\}|\[/?(?:b|i|color[^\]]*)\]")
FMT = re.compile(r"%s")


def main() -> int:
    errors = 0
    for name, fn in ex.SOURCES.items():
        expected = fn()
        path = ex.LOCALE / f"{name}.csv"
        with path.open(newline="", encoding="utf-8") as fh:
            rows = list(csv.DictReader(fh))
        keys = [r["keys"] for r in rows]
        if len(keys) != len(set(keys)):
            print(f"[{name}] claves duplicadas")
            errors += 1
        for k in set(expected) - set(keys):
            print(f"[{name}] falta la clave {k}")
            errors += 1
        for k in set(keys) - set(expected):
            print(f"[{name}] sobra la clave {k}")
            errors += 1
        for r in rows:
            k, es, en = r["keys"], r["es"], r["en"]
            if es != expected.get(k, es):
                print(f"[{name}] {k}: es desactualizado respecto a los datos")
                errors += 1
            for lang in ("es", "en"):
                if not r[lang] and (lang != "es" or expected.get(k)):
                    print(f"[{name}] {k}: columna {lang} vacia")
                    errors += 1
            if k.endswith("_FMT") and es.count("%s") != en.count("%s"):
                print(f"[{name}] {k}: %s distintos")
                errors += 1
            if sorted(PLACEHOLDER.findall(es)) != sorted(PLACEHOLDER.findall(en)):
                print(f"[{name}] {k}: placeholders distintos es={PLACEHOLDER.findall(es)} en={PLACEHOLDER.findall(en)}")
                errors += 1
        print(f"{name}.csv: {len(rows)} claves")
    print("OK" if errors == 0 else f"{errors} errores")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
