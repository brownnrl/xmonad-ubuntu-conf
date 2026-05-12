#!/usr/bin/env bash
# Print the X clipboard image to the Brother as US Letter via gtklp preview.
set -euo pipefail

WORKDIR="$(mktemp -d /tmp/clip-print-XXXXXX)"
trap 'rm -rf "$WORKDIR"' EXIT

targets="$(xclip -selection clipboard -t TARGETS -o 2>/dev/null || true)"
src_mime=""
for mime in image/png image/jpeg image/bmp; do
  if grep -qx "$mime" <<<"$targets"; then
    src_mime="$mime"
    break
  fi
done

if [[ -z "$src_mime" ]]; then
  notify-send -u critical "Clipboard print" "No image found on clipboard"
  exit 1
fi

RAW="$WORKDIR/clip.${src_mime##*/}"
FITTED="$WORKDIR/fitted.png"
PDF="$WORKDIR/page.pdf"

xclip -selection clipboard -t "$src_mime" -o > "$RAW"

convert "$RAW" \
  -background white -alpha remove -alpha off \
  -density 300 -units PixelsPerInch \
  -resize 2400x3150 \
  -gravity center -extent 2550x3300 \
  "$FITTED"

img2pdf "$FITTED" --output "$PDF"

exec evince "$PDF"
