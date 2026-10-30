#!/usr/bin/env python3
"""Genera/actualiza los CSV de traduccion de DATOS del juego (locale/items|lore|narrator|world.csv
y un locale/narrator_<stem>.csv por cada assets/data/narrator/<stem>.json distinto de lines.json).

Fuente de verdad del espanol: assets/data/items/*.tres, assets/data/lore/*.tres,
assets/data/narrator/*.json y las constantes de src/autoloads/run_manager.gd
(FLOORS, CHARACTERS, BLESSINGS, META_UPGRADES; se vuelcan con tools/dump_world.gd).

- La columna `es` SIEMPRE se regenera desde los datos.
- Las demas columnas (en, es_ES, fr...) se CONSERVAN de los CSV existentes; las claves nuevas
  quedan con ellas vacias para traducirlas. Una celda de es_ES/fr vacia significa "usa el
  respaldo" (es_ES -> es; fr -> en), asi que NO es un error.
- Las filas existentes conservan su ORDEN; las claves nuevas se agregan al final. Un CSV cuyo
  contenido no cambia no se reescribe (ni se toca su fecha). Solo se tocan los CSV de SOURCES.
- Las claves que ya no existen en los datos NO se borran (se avisa); --prune las elimina.

Uso:  tools/extract_locale_data.py [--merge-en traducciones.json] [--prune]
  --merge-en: JSON {clave: texto_en}; rellena/sobrescribe la columna en de esas claves.
  --prune: elimina las filas cuya clave ya no existe en los datos.
"""
import csv
import io
import json
import re
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LOCALE = ROOT / "locale"
LANGS = ["es", "en", "es_ES", "fr", "pt_BR"]  # es = Latinoamerica (base); es_ES y fr pueden ir vacios

_STR = re.compile(r'^(\w+)\s*=\s*("(?:[^"\\]|\\.)*")\s*$')


def parse_tres_strings(path: Path) -> dict:
    out = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        m = _STR.match(line)
        if m:
            out[m.group(1)] = json.loads(m.group(2))  # escapes de Godot == JSON
    return out


# Objetos de la etapa 3b: su texto vive en locale/items_extra.csv (marca en el .tres:
# custom_data {"locale": "items_extra"}). Ademas, los textos de interfaz de ranuras, sets y estados.
EXTRA_MARK = '"locale": "items_extra"'
EXTRA_UI = {
    "PICKUP_SLOT_HINT": "Se guarda en una ranura (teclas 1-4 o cruceta).",
    "PICKUP_CURSE_HINT": "Maldito: ocupa una ranura hasta que lo quites con una llave.",
    "FX_SLOT_FULL": "Sin ranura libre: se usa al instante",
    "FX_CAGE_NO_HORMONE": "La jaula no deja pasar hormonas",
    "FX_CURSE_NO_SLOT": "Necesitas una ranura libre",
    "FX_CURSED": "¡Maldito!",
    "FX_CURSE_FREED": "¡Libre!",
    "FX_CURSE_NEEDS_KEY": "Hace falta una llave",
    "FX_SET_COMPLETE": "¡Set completo! %s",
    "FX_LATEX_SQUEAK": "*ñic*",
    "FX_STIM_CRASH": "¡Bajón!",
    "STATUS_DOT_IMMUNE": "Sin ardor",
    "STATUS_INFECT_IMMUNE": "Inmune al contagio",
    "STATUS_CHAFE": "Roce de malla",
    "HUD_SET_ON": "Set %s: ACTIVO",
    "HUD_SET_PROGRESS": "Set %s: %d/%d",
    "SET_PENE_NAME": "Orgullo de Penelandia",
    "SET_PENE_DESC": "3 objetos de Penelandia: +10% de daño y +5% de crítico. Si eres de allí, más.",
    "SET_VULVA_NAME": "Ciclo de Vulvania",
    "SET_VULVA_DESC": "3 objetos de Vulvania: +10% de cadencia y estamina 20% más rápida. Si eres de allí, más.",
}


def _item_rows(extra: bool) -> dict:
    rows = {}
    for p in sorted((ROOT / "assets/data/items").glob("*.tres")):
        d = parse_tres_strings(p)
        if "id" not in d:
            continue
        if (EXTRA_MARK in p.read_text(encoding="utf-8")) != extra:
            continue
        k = d["id"].upper()
        rows[f"ITEM_{k}_NAME"] = d.get("display_name", "")
        rows[f"ITEM_{k}_DESC"] = d.get("description", "")
    return rows


def collect_items() -> dict:
    return _item_rows(False)


def collect_items_extra() -> dict:
    rows = _item_rows(True)
    rows.update(EXTRA_UI)
    return rows


def collect_lore() -> dict:
    rows = {}
    for p in sorted((ROOT / "assets/data/lore").glob("*.tres")):
        d = parse_tres_strings(p)
        if "id" not in d:
            continue
        if d["id"].startswith("boss_alt_"):
            continue  # jefes alternativos (6c): sus textos viven en locale/jefes_alt.csv
        k = d["id"].upper()
        rows[f"LORE_{k}_TITLE"] = d.get("title", "")
        rows[f"LORE_{k}_TEXT"] = d.get("text", "")
        rows[f"LORE_{k}_FLAVOR"] = d.get("flavor_text", "")
    return rows


NARRATOR_DIR = ROOT / "assets/data/narrator"


def narr_key(stem: str, event: str, i: int) -> str:
    """Igual que Loc.narr_key: lines.json conserva NARR_<EVENTO>_<i>; el resto lleva el archivo."""
    if stem == "lines":
        return f"NARR_{event.upper()}_{i}"
    return f"NARR_{stem.upper()}__{event.upper()}_{i}"


def collect_narrator(stem: str = "lines") -> dict:
    data = json.loads((NARRATOR_DIR / f"{stem}.json").read_text(encoding="utf-8"))
    rows = {}
    for event, lines in data.items():
        if event.startswith("_"):
            continue
        for i, line in enumerate(lines):
            rows[narr_key(stem, event, i)] = line
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
    regions = []
    for f in w["FLOORS"]:
        if f["region"] not in regions:
            regions.append(f["region"])
        # 1a etapa FLOOR_<reino>_*, 2a etapa FLOOR_<reino>B_* (ver Loc.floor_name)
        i = f"{regions.index(f['region']) + 1}{'B' if f.get('stage', 1) > 1 else ''}"
        if f.get("stage", 1) == 1:  # los nombres de 2a etapa viven en locale/etapas.csv (a mano)
            rows[f"FLOOR_{i}_NAME"] = f["name"]
            # version corta para el mapa del menu (quita el articulo largo del palacio)
            rows[f"FLOOR_{i}_SHORT"] = f["name"].replace("EL PALACIO DE LA ", "PALACIO ")
        for roster, names in (("roster", "names"), ("alt_roster", "alt_names")):
            for v, n in zip(f.get(roster, []), f.get(names, [])):
                rows[enemy_key(v)] = n
        for x in f.get("extra", []):
            rows[enemy_key(x["variant"])] = x["name"]
        if f.get("miniboss"):  # minijefe propio de la sala MINIBOSS
            rows[enemy_key(f["miniboss"]["variant"])] = f["miniboss"]["name"]
        if f.get("boss"):
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
    "items_extra": collect_items_extra,
    "lore": collect_lore,
    "narrator": collect_narrator,
    "world": collect_world,
}
# Un CSV por archivo extra del narrador: cada bloque toca solo el suyo.
for _p in sorted(NARRATOR_DIR.glob("*.json")):
    if _p.stem != "lines":
        SOURCES[f"narrator_{_p.stem}"] = (lambda s: lambda: collect_narrator(s))(_p.stem)


def read_existing(path: Path):
    """(cabecera, filas en orden) del CSV actual; ([], []) si no existe."""
    if not path.exists():
        return [], []
    with path.open(newline="", encoding="utf-8") as fh:
        r = csv.DictReader(fh)
        return list(r.fieldnames or []), list(r)


def render(header: list, rows: list) -> str:
    out = io.StringIO()
    w = csv.writer(out, lineterminator="\n", quoting=csv.QUOTE_MINIMAL)
    w.writerow(header)
    for r in rows:
        w.writerow([r.get(h, "") or "" for h in header])
    return out.getvalue()


def main() -> None:
    merge = {}
    if "--merge-en" in sys.argv:
        merge = json.loads(Path(sys.argv[sys.argv.index("--merge-en") + 1]).read_text(encoding="utf-8"))
    prune = "--prune" in sys.argv
    LOCALE.mkdir(exist_ok=True)
    for name, fn in SOURCES.items():
        path = LOCALE / f"{name}.csv"
        old_header, old_rows = read_existing(path)
        new = fn()
        header = list(old_header) if old_header[:1] == ["keys"] else ["keys"]
        for lang in LANGS:  # agrega las columnas que falten, sin mover las existentes
            if lang not in header:
                header.append(lang)
        by_key = {r["keys"]: r for r in old_rows}
        rows = []
        for r in old_rows:  # orden original
            k = r["keys"]
            if k in new:
                r["es"] = new[k]
            elif prune:
                continue
            rows.append(r)
        for k, es in new.items():  # claves nuevas al final
            if k not in by_key:
                rows.append({"keys": k, "es": es})
        for r in rows:
            if r["keys"] in merge:
                r["en"] = merge[r["keys"]]
        missing = sum(1 for r in rows if r["keys"] in new and not r.get("en"))
        obsolete = [r["keys"] for r in rows if r["keys"] not in new]
        text = render(header, rows)
        changed = not path.exists() or path.read_text(encoding="utf-8") != text
        if changed:
            with path.open("w", newline="", encoding="utf-8") as fh:
                fh.write(text)
        print(f"{name}.csv: {len(new)} claves, {missing} sin en, {len(obsolete)} obsoletas "
              f"({'eliminadas' if prune else 'conservadas'})" + ("" if changed else ", sin cambios"))
        for k in obsolete[:5]:
            print(f"    obsoleta: {k}")


if __name__ == "__main__":
    main()
