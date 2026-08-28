#!/usr/bin/env bash
# Prints "<state>|<track>|<artist>|<position-sec>|<duration-sec>", or nothing.
# Never launches a player that is not already running.
set -uo pipefail

SELF=$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd) || SELF=.

case "$(uname -s)" in
  Darwin)
    if pgrep -x Spotify >/dev/null 2>&1; then
      osascript "$SELF/nowplaying.applescript" 2>/dev/null
    fi
    ;;
  Linux)
    # playerctl covers Spotify, VLC, mpv, browsers — anything speaking MPRIS
    if command -v playerctl >/dev/null 2>&1 && playerctl status >/dev/null 2>&1; then
      state=$(playerctl status 2>/dev/null | tr '[:upper:]' '[:lower:]')
      track=$(playerctl metadata title 2>/dev/null)
      artist=$(playerctl metadata artist 2>/dev/null)
      pos=$(playerctl position 2>/dev/null | cut -d. -f1)
      dur=$(playerctl metadata mpris:length 2>/dev/null)
      [[ -n ${dur:-} ]] && dur=$(( dur / 1000000 ))     # microseconds → seconds
      printf '%s|%s|%s|%s|%s\n' "$state" "$track" "$artist" "${pos:-0}" "${dur:-0}"
    fi
    ;;
esac
exit 0
