#!/usr/bin/env bash
# Installs jurnal-zjatek into Claude Code's user settings.
# Safe to re-run: it backs up settings.json and merges only its own three keys.
set -euo pipefail

SELF=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CLAUDE_DIR=${CLAUDE_DIR:-$HOME/.claude}
SETTINGS="$CLAUDE_DIR/settings.json"

say()  { printf '  %s\n' "$*"; }
ok()   { printf '  \033[32m✓\033[0m %s\n' "$*"; }
warn() { printf '  \033[33m!\033[0m %s\n' "$*"; }
die()  { printf '  \033[31m✗\033[0m %s\n' "$*" >&2; exit 1; }

printf '\n\033[1m✨ jurnal-zjatek\033[0m\n\n'

# ── dependencies ───────────────────────────────────────────────────
command -v jq >/dev/null   || die "нужен jq  (brew install jq / apt install jq)"
command -v git >/dev/null  || warn "git не найден — сегмент с веткой будет пустым"
command -v curl >/dev/null || warn "curl не найден — анекдоты отключатся"
command -v python3 >/dev/null || warn "python3 не найден — анекдоты отключатся"
[[ -n ${COLORTERM:-} ]] || warn "COLORTERM не выставлен — если цвета кривые, тема просит truecolor-терминал"
ok "зависимости на месте"

# ── the status line itself ─────────────────────────────────────────
chmod +x "$SELF/statusline.sh" "$SELF"/lib/*.sh 2>/dev/null || true
[[ -x $SELF/statusline.sh ]] || die "не могу сделать statusline.sh исполняемым"

mkdir -p "$CLAUDE_DIR"
[[ -f $SETTINGS ]] || echo '{}' > "$SETTINGS"
jq -e . "$SETTINGS" >/dev/null 2>&1 || die "$SETTINGS — невалидный JSON, почини его сначала"

BACKUP="$SETTINGS.bak-$(date +%Y%m%d%H%M%S)"
cp "$SETTINGS" "$BACKUP"
ok "бэкап: $BACKUP"

if jq -e '.statusLine' "$SETTINGS" >/dev/null 2>&1; then
  CUR=$(jq -r '.statusLine.command // ""' "$SETTINGS")
  [[ $CUR == *statusline.sh* ]] || warn "перезаписываю существующий statusLine: $CUR"
fi

TMP=$(mktemp)
jq --slurpfile frag <(sed "s|__STATUSLINE__|bash $SELF/statusline.sh|" "$SELF/settings-fragment.json") \
   '. + $frag[0]' "$SETTINGS" > "$TMP"
mv "$TMP" "$SETTINGS"
ok "settings.json обновлён"

# ── warm the caches so the first render is not empty ───────────────
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/jurnal-zjatek"
mkdir -p "$CACHE"
bash "$SELF/lib/battery.sh"    > "$CACHE/battery"    2>/dev/null || true
bash "$SELF/lib/nowplaying.sh" > "$CACHE/nowplaying" 2>/dev/null || true
if command -v curl >/dev/null && command -v python3 >/dev/null; then
  bash "$SELF/lib/anekdot.sh" > "$CACHE/anekdot" 2>/dev/null || true
  N=$(grep -c . "$CACHE/anekdot" 2>/dev/null || echo 0)
  ok "анекдотов в кэше: $N"
fi

printf '\n'
say "Готово. Перезапусти Claude Code — глаголы спиннера и подсказки читаются при старте."
say "Предпросмотр прямо сейчас:  ./preview.sh"
printf '\n'
