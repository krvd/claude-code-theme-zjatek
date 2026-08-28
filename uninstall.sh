#!/usr/bin/env bash
# Removes the three keys jurnal-zjatek adds. Everything else in settings.json is left alone.
set -euo pipefail

CLAUDE_DIR=${CLAUDE_DIR:-$HOME/.claude}
SETTINGS="$CLAUDE_DIR/settings.json"
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/jurnal-zjatek"

[[ -f $SETTINGS ]] || { echo "  нет $SETTINGS — нечего снимать"; exit 0; }
jq -e . "$SETTINGS" >/dev/null 2>&1 || { echo "  $SETTINGS невалиден"; exit 1; }

BACKUP="$SETTINGS.bak-$(date +%Y%m%d%H%M%S)"
cp "$SETTINGS" "$BACKUP"

TMP=$(mktemp)
jq 'del(.statusLine, .spinnerVerbs, .spinnerTipsOverride)' "$SETTINGS" > "$TMP"
mv "$TMP" "$SETTINGS"

rm -rf "$CACHE"

printf '  \033[32m✓\033[0m снято. Бэкап: %s\n' "$BACKUP"
printf '  Перезапусти Claude Code.\n'
