#!/usr/bin/env bash
# Pulls anekdot.ru's public RSS feeds and flattens each joke onto one line.
# Runs in the background from the status line, at most once every 15 minutes.
set -uo pipefail
export LC_ALL=en_US.UTF-8

UA='Mozilla/5.0 (Macintosh; Intel Mac OS X) claude-code-statusline/1.0'
FEEDS=(
  https://www.anekdot.ru/rss/export_j.xml
  https://www.anekdot.ru/rss/export_top.xml
)

for f in "${FEEDS[@]}"; do
  curl -sSL --max-time 6 --retry 0 -A "$UA" "$f" 2>/dev/null
done | python3 -c '
import sys, re, html

data = sys.stdin.read()
out, seen = [], set()

for raw in re.findall(r"<description>(.*?)</description>", data, re.S):
    m = re.match(r"\s*<!\[CDATA\[(.*?)\]\]>\s*$", raw, re.S)
    text = m.group(1) if m else raw
    text = re.sub(r"<br\s*/?>", " / ", text, flags=re.I)   # keep line breaks as separators
    text = re.sub(r"<[^>]+>", "", text)                     # drop any other markup
    text = html.unescape(text)
    text = " ".join(text.split())                           # collapse to a single line
    if 20 <= len(text) <= 400 and text not in seen:
        seen.add(text)
        out.append(text)

# the feed description itself is not a joke
out = [t for t in out if "Анекдоты из России" not in t]
print("\n".join(out))
'
