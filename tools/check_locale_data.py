#!/usr/bin/env python3
"""Comprueba locale/items|lore|narrator|world.csv (y narrator_<stem>.csv) contra los datos del juego.

- Todas las claves que Loc puede pedir existen (y no sobran).
- es y en nunca vacios (salvo que el dato en espanol tambien lo este).
- es_ES y fr PUEDEN estar vacios (respaldo: es_ES -> es, fr -> en): se informa por idioma
  cuantas claves faltan, sin fallar. Con --strict tambien es error.
- Los placeholders ({x}, %d, %s, %%) y las etiquetas [b]/[i] coinciden entre es y los demas
  idiomas que tengan texto.
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


REQUIRED = ("es", "en")
OPTIONAL = ("es_ES", "fr", "pt_BR")


def main() -> int:
    strict = "--strict" in sys.argv
    errors = 0
    missing = {lang: 0 for lang in OPTIONAL}
    total = 0
    for name, fn in ex.SOURCES.items():
        expected = fn()
        path = ex.LOCALE / f"{name}.csv"
        if not path.exists():
            print(f"[{name}] falta {path.name}: corre tools/extract_locale_data.py")
            errors += 1
            continue
        with path.open(newline="", encoding="utf-8") as fh:
            rows = list(csv.DictReader(fh))
        for lang in REQUIRED + OPTIONAL:
            if rows and lang not in rows[0]:
                print(f"[{name}] falta la columna {lang}: corre tools/extract_locale_data.py")
                errors += 1
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
            k, es = r["keys"], r["es"]
            if es != expected.get(k, es):
                print(f"[{name}] {k}: es desactualizado respecto a los datos")
                errors += 1
            for lang in REQUIRED:
                if not r[lang] and (lang != "es" or expected.get(k)):
                    print(f"[{name}] {k}: columna {lang} vacia")
                    errors += 1
            total += 1
            for lang in OPTIONAL:
                if not (r.get(lang) or ""):
                    missing[lang] += 1
                    if strict:
                        print(f"[{name}] {k}: columna {lang} vacia")
                        errors += 1
            for lang in ("en",) + OPTIONAL:
                txt = r.get(lang) or ""
                if not txt:
                    continue
                if k.endswith("_FMT") and es.count("%s") != txt.count("%s"):
                    print(f"[{name}] {k}: %s distintos ({lang})")
                    errors += 1
                if sorted(PLACEHOLDER.findall(es)) != sorted(PLACEHOLDER.findall(txt)):
                    print(f"[{name}] {k}: placeholders distintos es={PLACEHOLDER.findall(es)} {lang}={PLACEHOLDER.findall(txt)}")
                    errors += 1
        print(f"{name}.csv: {len(rows)} claves")
    print("Claves sin traducir (datos): " + ", ".join(f"{l} {missing[l]}/{total}" for l in OPTIONAL)
          + ("" if strict else "  (respaldo: es_ES->es, fr->en; usa --strict para exigirlas)"))
    print("OK" if errors == 0 else f"{errors} errores")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
