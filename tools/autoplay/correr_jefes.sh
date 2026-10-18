#!/bin/bash
# Corre peleas directas contra un jefe, de a 3 en paralelo, y deja los registros (.log del bot y .out de Godot) en una carpeta.
# Uso: tools/autoplay/correr_jefes.sh <jefe> <carpeta_salida> [loadout]
#   ej: tools/autoplay/correr_jefes.sh cera .claude_tmp/antes boomerang_silicona
# Variables: HEROES (def. "pitocles vulvalquiria ornitorrinco"), SEEDS (def. "1 2 3"), EXTRA (flags extra del bot, p. ej. "--boss-alt=1").
# Siempre --no-god=1, sin sonido, headless a 60 fps fijos. Despues: python3 tools/autoplay/tabla_jefes.py <carpeta>
BOSS="$1"
OUT="$2"
LOAD="${3:-}"
HEROES="${HEROES:-pitocles vulvalquiria ornitorrinco}"
SEEDS="${SEEDS:-1 2 3}"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
mkdir -p "$ROOT/$OUT"
TAG="${LOAD:-pistola}"

run_one() {
  local h="$1" s="$2"
  local name="${BOSS}_${TAG}_${h}_${s}"
  local lo=""
  if [ -n "$LOAD" ]; then lo="--loadout=$LOAD"; fi
  XDG_DATA_HOME="$ROOT/.claude_tmp/xdg_$name" godot --headless --audio-driver Dummy --fixed-fps 60 --path "$ROOT" \
    res://tools/autoplay/autoplay.tscn -- --hero="$h" --seed="$s" --boss="$BOSS" --no-god=1 $lo $EXTRA \
    --log="$ROOT/$OUT/$name.log" > "$ROOT/$OUT/$name.out" 2>&1
  rm -rf "$ROOT/.claude_tmp/xdg_$name"
}
export -f run_one
export BOSS OUT LOAD ROOT TAG EXTRA

for h in $HEROES; do for s in $SEEDS; do echo "$h $s"; done; done | xargs -P 3 -L 1 bash -c 'run_one "$0" "$1"'
