#!/bin/zsh
set -eu

SOURCE=""
EVENT=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --source) SOURCE="$2"; shift 2 ;;
    --event) EVENT="$2"; shift 2 ;;
    *) shift ;;
  esac
done

INPUT="$(cat)"
SESSION="$(printf '%s' "$INPUT" | /usr/bin/python3 -c 'import json,sys; d=json.load(sys.stdin); print(d.get("session_id") or d.get("thread_id") or "default")' 2>/dev/null || printf default)"
/usr/bin/open "deskcat://agent?source=${SOURCE}&event=${EVENT}&session=${SESSION}"
