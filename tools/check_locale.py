#!/usr/bin/env python3
"""Comprueba las traducciones: toda clave usada con tr("...") en src/ existe en
locale/*.csv, es y en no estan vacios y los marcadores de formato (%d, %s, %.0f)
coinciden entre los idiomas con texto. Columnas: keys,es,en,es_ES,fr (es_ES y fr pueden
ir vacias: respaldo es_ES->es, fr->en; informa cuantas faltan, y con --strict es error).
Uso: python3 tools/check_locale.py [--strict]"""
import csv, glob, os, re, sys

root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
STRICT = "--strict" in sys.argv
REQUIRED = ["es", "en"]
OPTIONAL = ["es_ES", "fr"]
keys, errors = {}, []
missing = {l: 0 for l in OPTIONAL}
for path in sorted(glob.glob(os.path.join(root, "locale", "*.csv"))):
    with open(path, encoding="utf-8", newline="") as f:
        rows = list(csv.reader(f))
    if not rows or rows[0][:1] != ["keys"]:
        errors.append(f"{path}: la primera fila debe empezar por 'keys'")
        continue
    langs = rows[0][1:]
    for i, row in enumerate(rows[1:], 2):
        if not row or not row[0]:
            continue
        if len(row) != len(rows[0]):
            errors.append(f"{os.path.basename(path)}:{i} columnas de mas o de menos: {row[0]}")
            continue
        cells = dict(zip(langs, row[1:]))
        for l in langs:
            if cells[l].strip() == "":
                if l in OPTIONAL:
                    missing[l] += 1
                    if STRICT:
                        errors.append(f"{os.path.basename(path)}:{i} {l} vacio: {row[0]}")
                else:
                    errors.append(f"{os.path.basename(path)}:{i} columna {l} vacia: {row[0]}")
        if row[0] in keys:
            errors.append(f"clave duplicada: {row[0]}")
        keys[row[0]] = row
        fmts = [sorted(re.findall(r"%[-+0-9.]*[sdfxX]", c)) for c in row[1:] if c.strip()]
        if any(x != fmts[0] for x in fmts):
            errors.append(f"{os.path.basename(path)}:{i} formatos distintos entre idiomas: {row[0]}")

used = {}
pat = re.compile(r'\btr\(\s*"([A-Z0-9_]+)"')
for path in glob.glob(os.path.join(root, "src", "**", "*.gd"), recursive=True):
    for n, line in enumerate(open(path, encoding="utf-8"), 1):
        for k in pat.findall(line):
            if k.endswith('_'):
                continue  # prefijo dinamico: tr("PREFIJO_" + id)
            used.setdefault(k, f"{os.path.relpath(path, root)}:{n}")
# claves puestas como texto en .tscn y las construidas con prefijo (tr("PREFIJO_" + x))
for path in glob.glob(os.path.join(root, "src", "**", "*.tscn"), recursive=True):
    for n, line in enumerate(open(path, encoding="utf-8"), 1):
        m = re.match(r'text = "([A-Z][A-Z0-9_]+)"$', line.strip())
        if m:
            used.setdefault(m.group(1), f"{os.path.relpath(path, root)}:{n}")
for k, where in sorted(used.items()):
    if k not in keys:
        errors.append(f"clave usada y no definida: {k} ({where})")
print(f"{len(keys)} claves definidas, {len(used)} usadas literalmente")
print("sin traducir: " + ", ".join(f"{l} {missing[l]}/{len(keys)}" for l in OPTIONAL))
for e in errors:
    print("ERROR:", e)
sys.exit(1 if errors else 0)
