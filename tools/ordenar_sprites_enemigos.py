#!/usr/bin/env python3
"""Ordena assets/sprites/enemies/ en carpetas <reino>/<enemigo>/ y arregla todas las referencias.

Uso:
  python3 tools/ordenar_sprites_enemigos.py           # simula: dice qué movería
  python3 tools/ordenar_sprites_enemigos.py --apply   # mueve (git mv) y reescribe referencias

Idempotente: se puede volver a correr cuando un generador de arte (tools/gen_*.py) deje archivos
sueltos en assets/sprites/enemies/; solo mueve lo que está en la raíz de esa carpeta.

- El reino de cada enemigo sale de assets/data/floors/*.json (roster, extra, boss, boss_alt,
  miniboss) y de floors/extra/enemigos3a.json: el PRIMER reino donde aparece (orden de los JSON).
- Las ITS (aparecen en muchos reinos) van a comunes/its/; los genéricos y lo que no aparece en
  ningún piso, a comunes/ (o a la tabla MANUAL de abajo).
- Escribe assets/data/enemy_art.json (enemigo -> carpeta), que lee src/core/enemy_art.gd
  (EnemyArt.frames(v), EnemyArt.dir(v)) para las rutas armadas en código con el nombre.
- Reescribe (res://)assets/sprites/enemies/<archivo> en .gd .tscn .tres .import .py .json .cfg.
"""
import json
import os
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
EN = ROOT / "assets/sprites/enemies"
RES = "res://assets/sprites/enemies/"
REL = "assets/sprites/enemies/"  # con o sin res:// (los generadores de tools/ usan rutas de disco)
INDEX = ROOT / "assets/data/enemy_art.json"

ITS = {"clamidia", "vph", "herpes", "gonorrea", "sifilis", "verruguita"}
COMUNES = {"melee", "ranged", "swarmer", "tank", "boss", "espinilla"}
# Enemigos que no salen (o no salen bien) de los pisos: carpeta a mano.
MANUAL = {
    "hombre_l": "arcoiria/hombre",
    "hombre_r": "arcoiria/hombre",
    "hojita_censora": "palacio/hoja_de_parra",
    "cria_ovarica": "vulvania/cria_ovarica",
    "parra": "palacio/hoja_de_parra",
    "ego_inflado": "comunes/ego_inflado",
    "pastilla": "penelandia/pastilla",
    "pelusa_estatica": "selva/pelusa_estatica",
    "sintoma": "prostata/sintoma",
    "satelite_cobre": "vulvania/satelite_cobre",
    "funcionario": "perineo/funcionario",
    "don_chequeo": "prostata/don_chequeo",
    "don_chequeo_timbre": "prostata/don_chequeo_timbre",
    "timbre": "perineo/timbre",
    "bot_reporte": "palacio/bot_reporte",
    "coprolito": "puerta_trasera/coprolito",
    "guijarro": "puerta_trasera/guijarro",
}
EXTS = (".gd", ".tscn", ".tres", ".import", ".py", ".json", ".cfg", ".godot")


def region_of_floor_files() -> tuple[dict, dict]:
    """variante -> reino (primera aparición) y nombre de piso -> reino."""
    first: dict[str, str] = {}
    floor_region: dict[str, str] = {}
    for f in sorted((ROOT / "assets/data/floors").glob("*.json")):
        d = json.loads(f.read_text())
        reg = d.get("region", "")
        floor_region[re.sub(r"^\d+_", "", f.stem)] = reg
        names = list(d.get("roster", []))
        names += [e.get("variant", "") for e in d.get("extra", [])]
        names += [d.get("boss") or "", d.get("boss_alt") or ""]
        names.append((d.get("miniboss") or {}).get("variant", ""))
        for n in names:
            if n:
                first.setdefault(n, reg)
    extra = ROOT / "assets/data/floors/extra/enemigos3a.json"
    if extra.exists():
        for e in json.loads(extra.read_text()):
            floors = e.get("floor", [])
            regs = [floor_region.get(x, "") for x in floors]
            regs = [r for r in regs if r]
            if regs and e.get("variant"):
                first.setdefault(e["variant"], regs[0])
    return first, floor_region


def variants() -> list[str]:
    """Todas las variantes conocidas: las que tienen SpriteFrames (en la raíz o ya ordenadas)."""
    vs = {p.name[: -len("_sprite_frames.tres")] for p in EN.rglob("*_sprite_frames.tres")}
    vs |= set(MANUAL)
    return sorted(vs, key=len, reverse=True)  # el prefijo más largo gana (testiculo_primordial > testiculo)


def folder_for(v: str, first: dict, old: dict) -> str:
    if v in MANUAL:
        return MANUAL[v]
    if v in old:
        return old[v]  # ya ordenado antes: no se mueve de carpeta
    if v in ITS:
        return "comunes/its/" + v
    if v in COMUNES:
        return "comunes/" + v
    reg = first.get(v)
    return f"{reg}/{v}" if reg else "comunes/" + v


def owner(fname: str, vs: list[str]) -> str | None:
    stem = fname[: -len(".import")] if fname.endswith(".import") else fname
    for v in vs:
        if stem.startswith(v + "_") or stem == v + ".png":
            return v
    return None


def text_files():
    skip = {".git", ".godot", ".claude", "build"}
    for dp, dns, fns in os.walk(ROOT):
        dns[:] = [d for d in dns if d not in skip]
        for fn in fns:
            if fn.endswith(EXTS) or fn == "project.godot":
                yield Path(dp) / fn


def main() -> None:
    apply = "--apply" in sys.argv
    first, _ = region_of_floor_files()
    vs = variants()
    old = json.loads(INDEX.read_text()) if INDEX.exists() else {}
    index = dict(old)
    moves: list[tuple[str, str]] = []  # (archivo, carpeta relativa)
    loose = []
    for p in sorted(EN.iterdir()):
        if p.is_dir():
            continue
        v = owner(p.name, vs)
        if v is None:
            loose.append(p.name)
            continue
        d = folder_for(v, first, old)
        index[v] = d
        moves.append((p.name, d))
    for v in vs:  # variantes ya ordenadas que el índice aún no conoce
        if v not in index:
            index[v] = folder_for(v, first, old)
    if loose:
        print("SIN DUEÑO (se quedan en la raíz; agrégalos a MANUAL):", ", ".join(loose))
    by_dir: dict[str, int] = {}
    for _, d in moves:
        by_dir[d] = by_dir.get(d, 0) + 1
    for d in sorted(by_dir):
        print(f"{by_dir[d]:4d}  {d}/")
    print(f"{len(moves)} archivos a mover")
    if not apply:
        print("(simulación: usa --apply)")
        return
    renames = {}
    for name, d in moves:
        (EN / d).mkdir(parents=True, exist_ok=True)
        src, dst = EN / name, EN / d / name
        subprocess.run(["git", "mv", "-k", str(src), str(dst)], cwd=ROOT)
        if not dst.exists():
            src.rename(dst)  # archivo sin seguimiento en git
    # Toda ruta plana que ya no existe en la raíz apunta a donde quedó el archivo (también lo
    # movido en corridas anteriores: así se arreglan ramas que llegan con rutas viejas).
    for p in EN.rglob("*"):
        if p.is_file() and p.parent != EN and not p.name.endswith(".import") and not (EN / p.name).exists():
            renames[REL + p.name] = REL + str(p.relative_to(EN))
    pat = re.compile(re.escape(REL) + r"[A-Za-z0-9_.\-]+")
    changed = 0
    for f in text_files():
        try:
            t = f.read_text()
        except UnicodeDecodeError:
            continue
        if REL not in t:
            continue
        n = pat.sub(lambda m: renames.get(m.group(0), m.group(0)), t)
        if n != t:
            f.write_text(n)
            changed += 1
    INDEX.write_text(json.dumps(dict(sorted(index.items())), ensure_ascii=False, indent="\t") + "\n")
    print(f"referencias reescritas en {changed} archivos; índice: {INDEX.relative_to(ROOT)}")
    print("Ahora: godot --headless --path . --audio-driver Dummy --import")


if __name__ == "__main__":
    main()
