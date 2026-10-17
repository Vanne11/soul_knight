#!/usr/bin/env python3
"""Genera/actualiza los CSV de traduccion de DATOS del juego (locale/items|lore|narrator|world.csv).

Fuente de verdad del espanol: assets/data/items/*.tres, assets/data/lore/*.tres,
assets/data/narrator/lines.json y las constantes de src/autoloads/run_manager.gd
(FLOORS, CHARACTERS, BLESSINGS, META_UPGRADES; se vuelcan con tools/dump_world.gd).

- La columna `es` SIEMPRE se regenera desde los datos.
- La columna `en` (y cualquier otra columna de idioma) se CONSERVA de los CSV existentes;
  las claves nuevas quedan con `en` vacio para traducirlas.
- Las claves que ya no existen en los datos se eliminan.

Uso:  tools/extract_locale_data.py [--merge-en traducciones.json]
  --merge-en: JSON {clave: texto_en}; rellena/sobrescribe la columna en de esas claves.
"""
import csv
import json
import re
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LOCALE = ROOT / "locale"
LANGS = ["es", "en"]

_STR = re.compile(r'^(\w+)\s*=\s*("(?:[^"\\]|\\.)*")\s*$')


def parse_tres_strings(path: Path) -> dict:
    out = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        m = _STR.match(line)
        if m:
            out[m.group(1)] = json.loads(m.group(2))  # escapes de Godot == JSON
    return out


def collect_items() -> dict:
    rows = {}
    for p in sorted((ROOT / "assets/data/items").glob("*.tres")):
        d = parse_tres_strings(p)
        if "id" not in d:
            continue
        k = d["id"].upper()
        rows[f"ITEM_{k}_NAME"] = d.get("display_name", "")
        rows[f"ITEM_{k}_DESC"] = d.get("description", "")
    return rows


def collect_lore() -> dict:
    rows = {}
    for p in sorted((ROOT / "assets/data/lore").glob("*.tres")):
        d = parse_tres_strings(p)
        if "id" not in d:
            continue
        k = d["id"].upper()
        rows[f"LORE_{k}_TITLE"] = d.get("title", "")
        rows[f"LORE_{k}_TEXT"] = d.get("text", "")
        rows[f"LORE_{k}_FLAVOR"] = d.get("flavor_text", "")
    return rows


def collect_narrator() -> dict:
    data = json.loads((ROOT / "assets/data/narrator/lines.json").read_text(encoding="utf-8"))
    rows = {}
    for event, lines in data.items():
        if event.startswith("_"):
            continue
        for i, line in enumerate(lines):
            rows[f"NARR_{event.upper()}_{i}"] = line
    return rows


def enemy_key(variant: str) -> str:
    return f"ENEMY_{variant.upper()}_NAME"


def boss_key(boss: str) -> str:
    return f"BOSS_{boss.removeprefix('boss_').upper()}_NAME"


def collect_world() -> dict:
    with tempfile.TemporaryDirectory() as tmp:
        out = Path(tmp) / "world.json"
        subprocess.run(["godot", "--headless", "--path", str(ROOT), "-s", "tools/dump_world.gd", "--", str(out)],
                       check=True, stdout=subprocess.DEVNULL)
        w = json.loads(out.read_text(encoding="utf-8"))
    rows = {}
    for i, f in enumerate(w["FLOORS"], start=1):
        rows[f"FLOOR_{i}_NAME"] = f["name"]
        # version corta para el mapa del menu (quita el articulo largo del palacio)
        rows[f"FLOOR_{i}_SHORT"] = f["name"].replace("EL PALACIO DE LA ", "PALACIO ")
        for roster, names in (("roster", "names"), ("alt_roster", "alt_names")):
            for v, n in zip(f.get(roster, []), f.get(names, [])):
                rows[enemy_key(v)] = n
        for x in f.get("extra", []):
            rows[enemy_key(x["variant"])] = x["name"]
        rows[boss_key(f["boss"])] = f["boss_name"]
    for cid, c in w["CHARACTERS"].items():
        k = cid.upper()
        for field in ("name", "title", "perk", "bio"):
            rows[f"CHAR_{k}_{field.upper()}"] = c[field]
    for bid, b in w["BLESSINGS"].items():
        rows[f"BLESSING_{bid.upper()}_NAME"] = b["name"]
        rows[f"BLESSING_{bid.upper()}_DESC"] = b["desc"]
    for mid, m in w["META_UPGRADES"].items():
        rows[f"META_{mid.upper()}_NAME"] = m["name"]
        rows[f"META_{mid.upper()}_DESC"] = m["desc"]
    # Nombres de reino (main.gd KINGDOM_NAMES) y gigantes (minijefes: "<bicho> Gigante")
    rows["KINGDOM_PENE_NAME"] = "PENELANDIA"
    rows["KINGDOM_VULVA_NAME"] = "VULVANIA"
    rows["ENEMY_GIANT_FMT"] = "%s Gigante"
    return rows


SOURCES = {
    "items": collect_items,
    "lore": collect_lore,
    "narrator": collect_narrator,
    "world": collect_world,
}


def read_existing(path: Path) -> dict:
    if not path.exists():
        return {}
    with path.open(newline="", encoding="utf-8") as fh:
        return {r["keys"]: r for r in csv.DictReader(fh)}


def main() -> None:
    merge = {}
    if "--merge-en" in sys.argv:
        merge = json.loads(Path(sys.argv[sys.argv.index("--merge-en") + 1]).read_text(encoding="utf-8"))
    LOCALE.mkdir(exist_ok=True)
    for name, fn in SOURCES.items():
        path = LOCALE / f"{name}.csv"
        old = read_existing(path)
        new = fn()
        with path.open("w", newline="", encoding="utf-8") as fh:
            w = csv.writer(fh, lineterminator="\n", quoting=csv.QUOTE_MINIMAL)
            w.writerow(["keys"] + LANGS)
            missing = 0
            for key, es in new.items():
                row = [key, es]
                for lang in LANGS[1:]:
                    val = old.get(key, {}).get(lang, "") or ""
                    if lang == "en" and key in merge:
                        val = merge[key]
                    if not val:
                        missing += 1
                    row.append(val)
                w.writerow(row)
        print(f"{name}.csv: {len(new)} claves, {missing} sin traducir, {len(set(old) - set(new))} obsoletas eliminadas")


if __name__ == "__main__":
    main()
