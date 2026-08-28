#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════
#  ✨ САМАЯ ВЕСЁЛАЯ ТЕМА ✨  — status line for Claude Code
#  Rainbow shimmer · dancing mascot · context gauge · battery ·
#  now playing · anekdot.ru
# ═══════════════════════════════════════════════════════════════════
set -uo pipefail
export LC_ALL=${JZ_LOCALE:-en_US.UTF-8}

SELF=$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd) || SELF=.
LIB="$SELF/lib"
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/jurnal-zjatek"
[[ -d $CACHE ]] || mkdir -p "$CACHE" 2>/dev/null

IN=$(cat)

# opt-in payload dump, handy when adapting the layout to a new field
if [[ ${JZ_DEBUG:-} == 1 ]]; then
  { printf '%s' "$IN" > "$CACHE/last-payload.json.$$" &&
    mv -f "$CACHE/last-payload.json.$$" "$CACHE/last-payload.json"; } 2>/dev/null
fi

command -v jq >/dev/null 2>&1 || { printf ' jurnal-zjatek: jq не установлен\n'; exit 0; }

IFS=$'\037' read -r MODEL CWD PROJ STYLE AGENT VIM FAST COST ADD DEL DUR SID PCT < <(
  printf '%s' "$IN" | jq -r '
    (.context_window // {}) as $c
    | [ (.model.display_name // "Claude"),
        (.workspace.current_dir // .cwd // "."),
        (.workspace.project_dir // .workspace.current_dir // .cwd // "."),
        (.output_style.name // ""),
        (.agent.name // ""),
        (.vim.mode // ""),
        (if .fast_mode then 1 else 0 end),
        (.cost.total_cost_usd // 0),
        (.cost.total_lines_added // 0),
        (.cost.total_lines_removed // 0),
        (.cost.total_api_duration_ms // .cost.total_duration_ms // 0),
        (.session_id // "x"),
        (($c.used_percentage // $c.used_percent // $c.percent_used //
          (($c.remaining_percentage | if . then 100 - . else null end)) //
          (($c.context_window_size // $c.max_tokens // 0) as $m
           | if $m > 0
             then ((($c.current_usage // {}) | (.input_tokens//0)+(.output_tokens//0)
                    +(.cache_creation_input_tokens//0)+(.cache_read_input_tokens//0))
                   as $u
                   | (if $u > 0 then $u
                      else ($c.total_tokens // $c.used_tokens //
                            (($c.input_tokens//0)+($c.cached_input_tokens//0)+($c.output_tokens//0)))
                      end) / $m * 100)
             else 0 end)) | floor)
      ] | map(tostring) | join("\u001f")' 2>/dev/null)

MODEL=${MODEL:-Claude}; CWD=${CWD:-.}; PROJ=${PROJ:-$CWD}
PCT=${PCT:-0}; PCT=${PCT//[!0-9]/}; PCT=${PCT:-0}
(( PCT > 100 )) && PCT=100

NAME=$(basename "$PROJ")
T=$(date +%s)

# ── truecolor helpers ──────────────────────────────────────────────
fg() { printf '\033[38;2;%d;%d;%dm' "$1" "$2" "$3"; }
R=$'\033[0m'; B=$'\033[1m'; DIM=$'\033[2m'

hue() {
  local h=$(( $1 % 360 )); local s=$(( h % 60 )); local x=$(( 255 * s / 60 ))
  case $(( h / 60 )) in
    0) fg 255 "$x" 0 ;;      1) fg $((255-x)) 255 0 ;;
    2) fg 0 255 "$x" ;;      3) fg 0 $((255-x)) 255 ;;
    4) fg "$x" 0 255 ;;      *) fg 255 0 $((255-x)) ;;
  esac
}

rainbow() {
  local s=$1 i=0 ch out=""
  while IFS= read -r -n1 ch; do
    [[ -z $ch ]] && continue
    out+="$(hue $(( i * 14 + T * 25 )))$ch"
    i=$((i+1))
  done < <(printf '%s' "$s")
  printf '%s%s' "$out" "$R"
}

# ── cache plumbing: the status line must never wait on anything ────
mtime() { stat -f %m "$1" 2>/dev/null || stat -c %Y "$1" 2>/dev/null || echo 0; }
age()   { echo $(( T - $(mtime "$1") )); }

# refresh_async <cachefile> <ttl> <cmd...> — first run synchronous, then background
refresh_async() {
  local f=$1 ttl=$2; shift 2
  if [[ ! -s $f ]]; then
    "$@" > "$f.tmp" 2>/dev/null && mv -f "$f.tmp" "$f" 2>/dev/null
  elif (( $(age "$f") >= ttl )); then
    { "$@" > "$f.tmp" 2>/dev/null && mv -f "$f.tmp" "$f"; } >/dev/null 2>&1 </dev/null &
  fi
}

# refresh_bg <cachefile> <ttl> <cmd...> — never synchronous (use for network)
refresh_bg() {
  local f=$1 ttl=$2; shift 2
  if [[ ! -s $f ]] || (( $(age "$f") >= ttl )); then
    { "$@" > "$f.tmp" 2>/dev/null && [[ -s $f.tmp ]] && mv -f "$f.tmp" "$f"; } >/dev/null 2>&1 </dev/null &
  fi
}

# ── 🔋 battery ─────────────────────────────────────────────────────
BATT=""
if [[ ${JZ_BATTERY:-1} == 1 ]]; then
  BATF="$CACHE/battery"
  refresh_async "$BATF" 20 bash "$LIB/battery.sh"
  if [[ -s $BATF ]]; then
    read -r BPCT BSTATE < "$BATF"
    BPCT=${BPCT//[!0-9]/}
    if [[ -n $BPCT ]]; then
      case "$BSTATE" in
        charged)     BICO="🔌"; BC=$(fg 120 220 140) ;;
        charging)    BICO="⚡"; BC=$(fg 255 215 0) ;;
        *)           if   (( BPCT <= 15 )); then BICO="🪫"; BC=$(fg 250 90 90)
                     elif (( BPCT <= 40 )); then BICO="🔋"; BC=$(fg 250 200 80)
                     else                        BICO="🔋"; BC=$(fg 140 225 130); fi ;;
      esac
      BW=6; BF=$(( BPCT * BW / 100 )); (( BF == 0 && BPCT > 0 )) && BF=1; BBAR=""
      for ((i=0;i<BW;i++)); do
        if (( i < BF )); then BBAR+="${BC}▰"; else BBAR+="$(fg 62 62 78)▱"; fi
      done
      BATT="$BICO $BBAR ${BC}${BPCT}%$R"
    fi
  fi
fi

# ── 🎵 now playing ─────────────────────────────────────────────────
SPOT=""
if [[ ${JZ_MUSIC:-1} == 1 ]]; then
  SPF="$CACHE/nowplaying"
  refresh_async "$SPF" 3 bash "$LIB/nowplaying.sh"
  if [[ -s $SPF ]]; then
    IFS='|' read -r SST STRACK SARTIST SPOS SDUR < "$SPF"
    SPOS=${SPOS//[!0-9]/}; SDUR=${SDUR//[!0-9]/}
    SPOS=${SPOS:-0}; SDUR=${SDUR:-0}
    if [[ -n ${STRACK:-} && ${SST:-stopped} != stopped ]]; then
      if [[ $SST == playing ]]; then
        # extrapolate the playhead from the cache age so the clock ticks every second
        SPOS=$(( SPOS + $(age "$SPF") ))
        (( SDUR > 0 && SPOS > SDUR )) && SPOS=$SDUR
        SICO="▶"; SC=$(fg 30 215 96)
      else
        SICO="⏸"; SC=$(fg 140 160 150)
      fi
      TITLE="$SARTIST — $STRACK"
      LIM=44
      if (( ${#TITLE} > LIM )); then
        SCROLL="$TITLE   •   "
        OFF=$(( T % ${#SCROLL} ))
        TITLE="${SCROLL:OFF}${SCROLL:0:OFF}"
        TITLE="${TITLE:0:LIM}"
      fi
      PW=12; PF=0
      (( SDUR > 0 )) && PF=$(( SPOS * PW / SDUR ))
      (( PF >= PW )) && PF=$(( PW - 1 ))
      PBAR=""
      for ((i=0;i<PW;i++)); do
        if   (( i <  PF )); then PBAR+="${SC}━"
        elif (( i == PF )); then PBAR+="${SC}●"
        else                     PBAR+="$(fg 62 62 78)━"; fi
      done
      tm() { printf '%d:%02d' $(( $1 / 60 )) $(( $1 % 60 )); }
      SPOT="${SC}♫$R $(fg 205 205 215)$TITLE$R $SC$SICO$R $(fg 130 130 150)$(tm "$SPOS")$R $PBAR$R $(fg 130 130 150)$(tm "$SDUR")$R"
    fi
  fi
fi

# ── 😄 anekdot.ru ──────────────────────────────────────────────────
JOKE=""
if [[ ${JZ_JOKES:-1} == 1 ]]; then
  AKF="$CACHE/anekdot"
  refresh_bg "$AKF" 900 bash "$LIB/anekdot.sh"
  if [[ -s $AKF ]]; then
    NJ=$(grep -c . "$AKF" 2>/dev/null || echo 0)
    (( NJ > 0 )) && JOKE=$(sed -n "$(( (T / 120 + ${#SID}) % NJ + 1 ))p" "$AKF" 2>/dev/null)
  fi
fi

# ── dancing mascot ─────────────────────────────────────────────────
FRAMES=( 'ヽ(•‿•)ノ' 'ᕕ( ᐛ )ᕗ' '\(^ᴥ^)/' 'ᕙ(⇀‸↼)ᕗ' '♪┏(・o･)┛♪' '(っ◔◡◔)っ' )
PANIC=( '(╯°□°)╯' '(ﾉಥ益ಥ)ﾉ' '☉_☉' '(๑•̀ㅁ•́)۶' )
if (( PCT >= 85 )); then
  MASCOT=${PANIC[$(( T % ${#PANIC[@]} ))]}; MC=$(fg 255 70 70)
else
  MASCOT=${FRAMES[$(( T / 2 % ${#FRAMES[@]} ))]}; MC=$(fg 255 210 90)
fi

# ── git ────────────────────────────────────────────────────────────
GIT=""
if BR=$(git --no-optional-locks -C "$CWD" rev-parse --abbrev-ref HEAD 2>/dev/null); then
  DIRTY=""
  git --no-optional-locks -C "$CWD" diff --quiet --ignore-submodules HEAD 2>/dev/null || DIRTY="$(fg 255 190 60)✦"
  AB=$(git --no-optional-locks -C "$CWD" rev-list --count --left-right '@{u}...HEAD' 2>/dev/null)
  SYNC=""
  if [[ -n $AB ]]; then
    TAB=$'\t'
    BEH=${AB%%${TAB}*}; AHD=${AB##*${TAB}}
    (( AHD > 0 )) && SYNC+="$(fg 120 220 140)↑$AHD"
    (( BEH > 0 )) && SYNC+="$(fg 240 130 130)↓$BEH"
  fi
  GIT="$(fg 190 160 255)⎇ $BR$DIRTY$SYNC$R"
fi

# ── context fuel gauge ─────────────────────────────────────────────
W=14; FILL=$(( PCT * W / 100 )); (( FILL == 0 && PCT > 0 )) && FILL=1; BAR=""
for ((i=0;i<W;i++)); do
  if (( i < FILL )); then
    p=$(( i * 100 / (W-1) ))
    if   (( p < 50 )); then BAR+="$(fg $(( 90 + p*3 )) 225 110)█"
    elif (( p < 80 )); then BAR+="$(fg 250 $(( 225 - (p-50)*3 )) 80)█"
    else                    BAR+="$(fg 250 $(( 130 - (p-80)*3 )) 90)█"; fi
  else
    BAR+="$(fg 62 62 78)░"
  fi
done
if   (( PCT >= 85 )); then GICO="🔥"
elif (( PCT >= 60 )); then GICO="🌡️ "
else                       GICO="🧠"; fi

CC=$(awk -v c="$COST" 'BEGIN{printf "%.2f", c}')
COINS=$(awk -v c="$COST" 'BEGIN{n=int(c/1); if(n>5)n=5; s=""; for(i=0;i<n;i++)s=s"💰"; if(s=="")s="🪙"; print s}')
MIN=$(( DUR / 60000 ))

QUIPS=(
 "код сам себя не отрефакторит"
 "«у меня локально работает» — древнее заклинание"
 "коммить почаще, плакать пореже"
 "тесты зелёные? тогда это фича"
 "TODO: убрать этот TODO"
 "не забудь прогнать typecheck"
)
QUIP=${QUIPS[$(( (T / 30 + ${#SID}) % ${#QUIPS[@]} ))]}

BADGE=""
(( FAST == 1 )) && BADGE+="$(fg 255 215 0) ⚡FAST$R"
[[ -n $AGENT && $AGENT != null ]] && BADGE+="$(fg 150 210 255) 🤖$AGENT$R"
[[ -n $STYLE && $STYLE != null && $STYLE != default ]] && BADGE+="$(fg 200 170 255) ✎$STYLE$R"
[[ -n $VIM && $VIM != null ]] && BADGE+="$(fg 120 255 180) [$VIM]$R"

# ── render ─────────────────────────────────────────────────────────
SEP="$(fg 90 90 110)│$R"

printf '%s%s%s  %s%s  %s %s%s%s\n' \
  "$MC" "$MASCOT" "$R" "$B" "$(rainbow "$NAME")" "$GIT" \
  "$SEP" "$(fg 235 145 105) ✻ $MODEL$R" "$BADGE"

printf ' %s %s%s %s%3d%%%s %s %s%s%s %s %s%s%s %s %s⏱ %sm%s%s\n' \
  "$GICO" "$BAR" "$R" "$(fg 175 175 190)" "$PCT" "$R" \
  "$SEP" "$COINS" "$(fg 190 230 150) \$$CC" "$R" \
  "$SEP" "$(fg 120 220 140)+$ADD" "$(fg 240 130 130) -$DEL" "$R" \
  "$SEP" "$(fg 130 130 150)" "$MIN" "$R" \
  "${BATT:+ $SEP $BATT}"

[[ -n $SPOT ]] && printf ' %s\n' "$SPOT"

if [[ -n $JOKE ]]; then
  JLIM=96
  if (( ${#JOKE} > JLIM )); then                   # marquee, 3 chars/second
    JS="$JOKE      ~      "
    JO=$(( (T * 3) % ${#JS} ))
    JOKE="${JS:JO}${JS:0:JO}"
    JOKE="${JOKE:0:JLIM}"
  fi
  printf ' %s😄 %s%s%s\n' "$(fg 255 205 100)" "$(fg 185 185 200)" "$JOKE" "$R"
else
  printf ' %s%s💡 %s%s\n' "$(fg 110 110 130)" "$DIM" "$QUIP" "$R"
fi
