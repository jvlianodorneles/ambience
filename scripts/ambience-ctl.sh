#!/usr/bin/env bash
# CLI controller for Ambience Studio
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYTHON="${PYTHON:-python3}"

case "$1" in
  toggle)
    "$PYTHON" "$DIR/ambience-engine.py" toggle "${2:-}" "${3:-}"
    ;;
  play|start)
    "$PYTHON" "$DIR/ambience-engine.py" start "${2:-rain}" "${3:-60}" "${4:-0}"
    ;;
  stop|pause)
    "$PYTHON" "$DIR/ambience-engine.py" stop
    ;;
  vol|volume)
    if [[ "$2" == +* ]] || [[ "$2" == -* ]]; then
      cur=$("$PYTHON" -c 'import json; from pathlib import Path; p = Path.home()/".local/state/omarchy/ambience/state.json"; print(json.load(open(p))["volume"] if p.exists() else 60)')
      delta="${2#+}"
      if [[ "$2" == +* ]]; then
        new_vol=$((cur + delta))
      else
        new_vol=$((cur - ${2#-}))
      fi
      "$PYTHON" "$DIR/ambience-engine.py" volume "$new_vol"
    else
      "$PYTHON" "$DIR/ambience-engine.py" volume "${2:-60}"
    fi
    ;;
  preset|set)
    "$PYTHON" "$DIR/ambience-engine.py" preset "$2"
    ;;
  timer)
    "$PYTHON" "$DIR/ambience-engine.py" timer "${2:-0}"
    ;;
  status)
    "$PYTHON" "$DIR/ambience-engine.py" status
    ;;
  list)
    "$PYTHON" "$DIR/ambience-engine.py" list-presets
    ;;
  *)
    "$PYTHON" "$DIR/ambience-engine.py" status
    ;;
esac
