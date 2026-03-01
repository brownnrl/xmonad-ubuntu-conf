#!/usr/bin/env bash
set -uo pipefail

if [ -z "${HOME:-}" ]; then
  HOME="$(getent passwd "$(id -u)" | cut -d: -f6)"
  export HOME
fi

ARTBASE="$HOME/.xmonad/xmobar-artifacts"
mkdir -p "$ARTBASE"

for pid in $(pgrep -u "$(id -u)" -f "/home/nelson/.xmonad/run-xmobar.sh" 2>/dev/null); do
  if [ "$pid" != "$$" ]; then
    kill "$pid" 2>/dev/null || true
  fi
done
pkill -u "$(id -u)" -x xmobar 2>/dev/null || true

ts="$(date -u +%Y%m%dT%H%M%SZ)"
d="$ARTBASE/$ts"
mkdir -p "$d"

{
  echo "DATE_UTC=$ts"
  echo "HOST=$(hostname)"
  echo "DISPLAY=${DISPLAY:-}"
  echo "XAUTHORITY=${XAUTHORITY:-}"
  echo "XDG_SESSION_TYPE=${XDG_SESSION_TYPE:-}"
} > "$d/env.txt"

xrandr --query > "$d/xrandr.txt" 2>&1 || true

TRAY_SLOTS=10
TRAY_SLOT_SIZE=18
TRAY_PX=$((TRAY_SLOTS * TRAY_SLOT_SIZE))

LEFT_LINE=$(xrandr --query | sed -nE 's/^.* connected (primary )?([0-9]+)x([0-9]+)\+([0-9]+)\+([0-9]+).*/\2 \3 \4 \5/p' | sort -n -k3,3 | head -n 1)
LEFT_W=$(echo "$LEFT_LINE" | awk '{print $1}')
LEFT_X=$(echo "$LEFT_LINE" | awk '{print $3}')
BAR_X=$((LEFT_X + TRAY_PX))
BAR_W=$((LEFT_W - TRAY_PX))
BAR_Y=0
BAR_H=18

if [ -z "${BAR_W:-}" ] || [ "$BAR_W" -le 0 ]; then
  BAR_W=100
fi

XMO_CONF="$d/xmobarrc"
sed -E "s/^([[:space:]]*)position[[:space:]]*=.*/\\1position = Static { xpos = ${BAR_X}, ypos = ${BAR_Y}, width = ${BAR_W}, height = ${BAR_H} },/" "$HOME/.xmonad/xmobarrc" > "$XMO_CONF"

# Run xmobar with logs captured.
# stdbuf forces line-buffered output so you see the last lines before death.
exec stdbuf -oL -eL xmobar -x 0 "$XMO_CONF" >"$d/stdout.log" 2>"$d/stderr.log"
