#!/usr/bin/env bash
# Prints "<percent> <charging|discharging|charged>" or nothing when there is no battery.
set -uo pipefail

case "$(uname -s)" in
  Darwin)
    line=$(pmset -g batt 2>/dev/null | grep -m1 -o '[0-9]\{1,3\}%.*') || exit 0
    pct=${line%%\%*}; pct=${pct//[!0-9]/}
    [[ -z $pct ]] && exit 0
    case "$line" in
      *charged*)      state=charged ;;
      *discharging*)  state=discharging ;;
      *)              state=charging ;;
    esac
    printf '%s %s\n' "$pct" "$state"
    ;;
  Linux)
    for b in /sys/class/power_supply/BAT*; do
      [[ -r $b/capacity ]] || continue
      pct=$(cat "$b/capacity" 2>/dev/null)
      raw=$(cat "$b/status" 2>/dev/null)
      case "$raw" in
        Charging)  state=charging ;;
        Full)      state=charged ;;
        *)         state=discharging ;;
      esac
      printf '%s %s\n' "$pct" "$state"
      exit 0
    done
    ;;
esac
exit 0
