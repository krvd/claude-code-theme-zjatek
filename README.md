# 📔 Журнал Зятёк

A theme for [Claude Code](https://claude.com/claude-code) that keeps a running
log of your session: context window, money, battery, whatever is playing, and a
joke every couple of minutes.

```
ヽ(•‿•)ノ  my-project  ⎇ main✦↑2 │ ✻ Opus 5 ⚡FAST
 🧠 ████████░░░░░░  61% │ 💰 $2.34 │ +412 -87 │ ⏱ 18m │ 🔋 ▰▰▰▰▰▱ 94%
 ♫ Artist — Track  ▶ 3:43 ━━━━━━━━●━━━ 4:59
 😄 a joke from anekdot.ru, scrolling past
```

All of it redraws **once per second**. Yes, it moves.

---

## One line. Absolutely no restraint.

Claude Code gives you a single line at the bottom of the screen. Most setups
spend it on a branch name and call it a day.

This one spends it on everything.

Your context window becomes a fuel gauge that slides from green to red while you
watch. Your session cost becomes a stack of coins. A mascot dances through six
frames and then panics, visibly and in red, the moment you cross 85% of the
window — which is roughly the moment you should be thinking about compacting
anyway. The project name shimmers through a 24-bit rainbow, because nobody
asked it not to.

Then it keeps going. It tells you what's playing, with a progress bar. It tells
you how much battery you have left. And every two minutes it tells you a joke,
scrolling past like a ticker for people with no stocks.

It redraws every second and takes ~70 ms to do it, because everything expensive
is cached and refreshed in the background. The whole thing is one bash script
you can read in a sitting and edit with any text editor.

None of this will make you a better engineer. That is not what it is for.

**On the line:** context gauge · session cost · lines added and removed · API
time · git branch with dirty and ahead/behind markers · `⚡FAST`, `🤖<subagent>`,
`✎<output style>` and vim-mode badges · battery · now playing · a joke.

**Off the line:** 45 custom spinner verbs and a custom set of spinner tips.

---

## Install

```sh
git clone git@github.com:krvd/claude-code-theme-zjatek.git
cd claude-code-theme-zjatek
./install.sh
```

The installer backs up `~/.claude/settings.json` with a timestamp, merges in
exactly three keys — `statusLine`, `spinnerVerbs`, `spinnerTipsOverride` — and
warms the caches. Your hooks, plugins, model and everything else are left alone.

**Restart Claude Code afterwards**: spinner verbs and tips are read once at
startup.

See it without launching Claude Code:

```sh
./preview.sh          # one frame
./preview.sh --live   # redraw every second, animations included
```

Had enough:

```sh
./uninstall.sh        # removes only its own three keys and the cache
```

---

## Requirements

| | |
|---|---|
| **required** | `bash` 3.2+, `jq`, a truecolor terminal |
| git segment | `git` |
| jokes | `curl` + `python3` |
| battery | macOS (`pmset`) or Linux (`/sys/class/power_supply`) |
| music | macOS: Spotify. Linux: `playerctl` — any MPRIS player |

Whatever is missing simply isn't drawn. The line doesn't fall apart, it just
gets shorter.

---

## Why it isn't slow

The line redraws every second, so nothing more expensive than a single `jq`
call happens synchronously.

Everything slow lives **behind a cache in `~/.cache/jurnal-zjatek/`**, and
refreshes are pushed to the background: the line renders whatever is already on
disk and never waits for anything. TTLs — battery 20s, player 3s, jokes 15min.

Two places where this matters:

- `osascript` to Spotify costs ~150 ms. Once a second, that would have tripled
  the render latency.
- `curl` to anekdot.ru can take up to 6 seconds. Jokes therefore get a
  background-only mode with no synchronous first run: until the cache exists,
  the line just renders without them.

The playhead position is extrapolated from the cache age, so the timecode ticks
every second even though the player is polled every three.

Result — **~70 ms** per render.

---

## Knobs

Turn segments off with environment variables:

```sh
JZ_JOKES=0     # no jokes
JZ_MUSIC=0     # no player
JZ_BATTERY=0   # no battery
JZ_DEBUG=1     # dump the payload to ~/.cache/jurnal-zjatek/last-payload.json
```

The rest is edited by hand in `statusline.sh`: `FRAMES` and `PANIC` are the
mascot frames, `QUIPS` the offline one-liners, `W` the gauge width, `LIM` and
`JLIM` the scroll lengths.

---

## Fine print

**The dollar figure is not a bill.** Claude Code estimates what the session
*would* cost at API rates. On a subscription it's a reference number and nothing
is charged for it separately; on an API key it's closer to real feelings. Coins
accumulate one per dollar, capped at five.

**The music player is never launched for you.** If the process isn't already
running, the segment simply isn't drawn — nothing gets started behind your back.

**Claude Code has no custom color themes.** There are exactly six, compiled into
the binary: `dark`, `light`, `light-daltonized`, `dark-daltonized`, `light-ansi`,
`dark-ansi`. So the "theme" here is the status line and the spinner; everything
else is painted by Claude Code itself. Don't expect the palette to change.

**macOS will ask for permission** to control Spotify on first contact — System
Settings → Privacy & Security → Automation. Deny it and the segment disappears,
nothing else happens.

**Jokes** come from anekdot.ru's public RSS feeds (`export_j.xml` and
`export_top.xml`), fetched every 15 minutes, one request per feed. The text sits
in the cache until the next refresh and belongs to its authors.

**Your terminal needs truecolor.** If the gradients look like mush, that's why.

---

<sub>Зятёк doesn't fix anything, but he writes it all down.</sub>
