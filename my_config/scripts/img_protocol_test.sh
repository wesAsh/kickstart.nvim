#!/usr/bin/env bash
# Raw terminal image-protocol probe. Run directly in the terminal under test
# (NOT inside tmux/screen, NOT via nvim :!). Emits one labeled test image per
# protocol; report which of the three actually draws a small rose picture.
#
#   sixel  -> DCS escape (ESC P ... ESC \)
#   kitty  -> APC escape (ESC _G ... ESC \)
#   iterm2 -> OSC 1337   (ESC ] 1337;File= ... BEL)
#
# Usage: img_protocol_test.sh [sixel|kitty|iterm2|all]   (default: all)

set -u
which magick >/dev/null 2>&1 && IM=magick || IM=convert

png=$(mktemp --suffix=.png)
trap 'rm -f "$png"' EXIT
$IM rose: -resize 200x200 "$png" || { echo "ImageMagick failed"; exit 1; }
b64=$(base64 -w0 "$png")
size=$(stat -c%s "$png")

do_sixel() {
  echo "== SIXEL test (DCS) — expect a rose below:"
  $IM "$png" sixel:-
  echo; echo "== end sixel"
}

do_kitty() {
  echo "== KITTY test (APC) — expect a rose below:"
  # transmit+display, PNG format, chunked
  local data="$b64" chunk
  local first=1
  while [ -n "$data" ]; do
    chunk=${data:0:4000}
    data=${data:4000}
    local more=1; [ -z "$data" ] && more=0
    if [ $first -eq 1 ]; then
      printf '\033_Gf=100,a=T,m=%d;%s\033\\' "$more" "$chunk"
      first=0
    else
      printf '\033_Gm=%d;%s\033\\' "$more" "$chunk"
    fi
  done
  echo; echo "== end kitty"
}

do_iterm2() {
  echo "== ITERM2 test (OSC 1337) — expect a rose below:"
  printf '\033]1337;File=inline=1;size=%d;name=%s:%s\a' "$size" "$(echo -n rose.png | base64)" "$b64"
  echo; echo "== end iterm2"
}

case "${1:-all}" in
  sixel)  do_sixel ;;
  kitty)  do_kitty ;;
  iterm2) do_iterm2 ;;
  all)    do_sixel; echo; do_kitty; echo; do_iterm2 ;;
  *) echo "usage: $0 [sixel|kitty|iterm2|all]"; exit 1 ;;
esac
