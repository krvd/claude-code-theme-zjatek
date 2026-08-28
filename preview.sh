#!/usr/bin/env bash
# Renders the status line with a fake payload so you can see it without launching Claude Code.
# Pass --live to redraw once a second (Ctrl+C to stop) and watch the animations.
set -uo pipefail
SELF=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

PAYLOAD='{
  "session_id": "preview-0001",
  "cwd": "'"$PWD"'",
  "model": { "display_name": "Opus 5" },
  "workspace": { "current_dir": "'"$PWD"'", "project_dir": "'"$PWD"'" },
  "output_style": { "name": "default" },
  "fast_mode": true,
  "cost": {
    "total_cost_usd": 2.34,
    "total_api_duration_ms": 1080000,
    "total_lines_added": 412,
    "total_lines_removed": 87
  },
  "context_window": { "used_percentage": 61, "context_window_size": 1000000 }
}'

if [[ ${1:-} == --live ]]; then
  trap 'printf "\033[?25h\n"; exit 0' INT
  printf '\033[?25l'
  while true; do
    OUT=$(printf '%s' "$PAYLOAD" | bash "$SELF/statusline.sh")
    printf '\033[H\033[2J%s\n' "$OUT"
    sleep 1
  done
else
  printf '%s' "$PAYLOAD" | bash "$SELF/statusline.sh"
fi
