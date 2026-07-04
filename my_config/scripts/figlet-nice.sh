#!/usr/bin/env bash
# Preview only the GOOD-LOOKING figlet fonts — the ones built from Unicode
# block/box-drawing/braille glyphs (█ ▄ ▀ ░ ▓ ┃ ━ ⣿ …) — and skip the plain-ASCII
# fonts drawn with #, |, /, letters and digits.
#
# Needs pyfiglet (pip install --user pyfiglet). ~24 of pyfiglet's 571 fonts match.
#
# Usage:  figlet-nice.sh [word]            # default word: Notes
#         figlet-nice.sh "My Header" | less -R
#         figlet-nice.sh --list            # just the font names
word="${*:-Notes}"
python3 - "$word" <<'PY'
import sys, re
from pyfiglet import Figlet, FigletFont
word = sys.argv[1]
list_only = word in ("--list", "-l")
# Block Elements + Box Drawing (U+2500–U+259F) and Braille (U+2800–U+28FF).
rx = re.compile('[─-▟⠀-⣿]')
names = []
for f in sorted(FigletFont.getFonts()):
    try:
        out = Figlet(font=f).renderText("Hi" if list_only else word)
    except Exception:
        continue
    if not rx.search(out):
        continue
    if list_only:
        names.append(f)
    else:
        print(f"== {f} ==\n{out}")
if list_only:
    print(" ".join(names))
PY
