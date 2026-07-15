#!/usr/bin/env bash
# Preview figlet/pyfiglet fonts. By default shows only the GOOD-LOOKING ones —
# fonts built from Unicode block/box-drawing/braille glyphs (█ ▄ ▀ ░ ▓ ┃ ━ ⣿ …) —
# skipping the plain-ASCII fonts drawn with #, |, /, letters and digits.
#
# Needs pyfiglet + its full font collection. Setup on Ubuntu 24 (see NB below):
#   sudo apt install python3-pyfiglet figlet toilet
# The apt pyfiglet is DFSG-stripped (~39 fonts, NO ansi_shadow). Restore the full
# set ONCE by copying pyfiglet's fonts into /usr/share/figlet/ — its
# SHARED_DIRECTORY, also read by figlet/toilet; plain data files, so immune to
# future Python upgrades:
#   git clone --depth 1 https://github.com/pwaller/pyfiglet /tmp/pf && \
#     sudo cp /tmp/pf/pyfiglet/fonts-*/*.flf /usr/share/figlet/
# → ~573 fonts; ~26 match the block/box "nice" heuristic below.
# NB: a `pip --user` install breaks on OS Python bumps (Ubuntu 22→24 moved
#     3.10→3.12 and orphaned it) — hence apt module + shared font files instead.
#
# Usage:  figlet-nice.sh [OPTIONS] [word]        # word defaults to "Notes"
#
#   Font set (mutually exclusive; last one wins):
#     -n, --nice          only block/box/braille fonts        (default)
#     -a, --all           every pyfiglet font (all 571)
#     -f, --font FONT      a specific font; repeatable, or comma-separated
#                          (e.g. -f pagga -f future  /  -f pagga,future)
#   Other:
#     -l, --list          list font names only, no rendering (respects the set)
#     -h, --help          this help
#
# Examples:
#   figlet-nice.sh "My Header"                # nice fonts, rendered
#   figlet-nice.sh -a "Hi" | less -R          # ALL fonts
#   figlet-nice.sh -f ansi_shadow "Deploy"    # one specific font
#   figlet-nice.sh --all --list               # names of all fonts

usage() { sed -n '2,25p' "$0" | sed 's/^# \{0,1\}//'; }

mode=nice          # nice | all | specific
list_only=0
fonts=""           # comma-joined, for specific mode
word=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -n|--nice) mode=nice; shift ;;
    -a|--all)  mode=all;  shift ;;
    -f|--font)
      [[ -z "${2:-}" ]] && { echo "figlet-nice: $1 needs a font name" >&2; exit 2; }
      mode=specific; fonts="${fonts:+$fonts,}$2"; shift 2 ;;
    -l|--list) list_only=1; shift ;;
    -h|--help) usage; exit 0 ;;
    --) shift; break ;;
    -*) echo "figlet-nice: unknown option '$1' (see --help)" >&2; exit 2 ;;
    *)  word="${word:+$word }$1"; shift ;;
  esac
done
word="${word:-Notes}"

python3 - "$mode" "$list_only" "$word" "$fonts" <<'PY'
import sys, re
from pyfiglet import Figlet, FigletFont

mode, list_only, word, fonts_csv = sys.argv[1], sys.argv[2] == "1", sys.argv[3], sys.argv[4]
# Block Elements + Box Drawing (U+2500–U+259F) and Braille (U+2800–U+28FF).
rx = re.compile('[─-▟⠀-⣿]')
all_fonts = sorted(FigletFont.getFonts())

if mode == "specific":
    fonts, seen = [], set()
    for w in (x.strip() for x in fonts_csv.split(",") if x.strip()):
        if w not in all_fonts:
            sys.stderr.write(f"figlet-nice: unknown font '{w}'\n")
        elif w not in seen:
            seen.add(w); fonts.append(w)
    if not fonts:
        sys.stderr.write("figlet-nice: no valid font names given\n")
        sys.exit(1)
else:
    fonts = all_fonts

names = []
for f in fonts:
    try:
        out = Figlet(font=f).renderText("Hi" if list_only else word)
    except Exception:
        continue
    # The block/box filter applies ONLY to --nice; --all and specific fonts pass through.
    if mode == "nice" and not rx.search(out):
        continue
    if list_only:
        names.append(f)
    else:
        print(f"== {f} ==\n{out}")

if list_only:
    print(" ".join(names))
PY
