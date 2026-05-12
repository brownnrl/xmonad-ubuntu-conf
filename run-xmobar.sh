#!/usr/bin/env bash
set -uo pipefail

if [ -z "${HOME:-}" ]; then
  HOME="$(getent passwd "$(id -u)" | cut -d: -f6)"
  export HOME
fi

ARTBASE="$HOME/.xmonad/xmobar-artifacts"
mkdir -p "$ARTBASE"

SELF="$HOME/.xmonad/run-xmobar.sh"

for pid in $(pgrep -u "$(id -u)" -f "$SELF" 2>/dev/null); do
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
  echo "PATH=${PATH:-}"
  echo "PWD=$(pwd)"
  echo "ulimit_before=$(ulimit -c)"
} > "$d/env.txt"

xrandr --query > "$d/xrandr.txt" 2>&1 || true

TRAY_SLOTS=10
TRAY_SLOT_SIZE=18
TRAY_PX=$((TRAY_SLOTS * TRAY_SLOT_SIZE))

DP_LINE=$(xrandr --query | sed -nE '/^DP-[^ ]* connected/ s/^.* connected (primary )?([0-9]+)x([0-9]+)\+([0-9]+)\+([0-9]+).*/\2 \3 \4 \5/p' | head -n 1)
LEFT_LINE=${DP_LINE:-$(xrandr --query | sed -nE 's/^.* connected (primary )?([0-9]+)x([0-9]+)\+([0-9]+)\+([0-9]+).*/\2 \3 \4 \5/p' | sort -n -k3,3 | head -n 1)}

LEFT_W=$(echo "$LEFT_LINE" | awk '{print $1}')
LEFT_X=$(echo "$LEFT_LINE" | awk '{print $3}')
BAR_X=$((LEFT_X + TRAY_PX))
BAR_W=$((LEFT_W - TRAY_PX))
BAR_Y=0
BAR_H=18

if [ -z "${BAR_W:-}" ] || [ "$BAR_W" -le 0 ]; then
  BAR_W=100
fi

{
  echo "LEFT_LINE=$LEFT_LINE"
  echo "BAR_X=$BAR_X"
  echo "BAR_W=$BAR_W"
  echo "BAR_Y=$BAR_Y"
  echo "BAR_H=$BAR_H"
} >> "$d/env.txt"

XMO_CONF="$d/xmobarrc"
sed -E \
  "s/^([[:space:]]*)position[[:space:]]*=.*/\\1position = Static { xpos = ${BAR_X}, ypos = ${BAR_Y}, width = ${BAR_W}, height = ${BAR_H} },/" \
  "$HOME/.xmonad/xmobarrc" > "$XMO_CONF"

XMOBAR_BIN="/data-mirrored/projects/xmobar/xmobar/dist-newstyle/build/x86_64-linux/ghc-9.6.7/xmobar-0.50/x/xmobar/build/xmobar/xmobar"
if [ ! -x "$XMOBAR_BIN" ]; then
  XMOBAR_BIN="xmobar"
fi

echo "XMOBAR_BIN=$XMOBAR_BIN" >> "$d/env.txt"

ulimit -c unlimited || true
echo "ulimit_after=$(ulimit -c)" >> "$d/env.txt"

coredumpctl list xmobar --no-pager > "$d/coredump-before.txt" 2>&1 || true

stdbuf -oL -eL "$XMOBAR_BIN" -x 0 "$XMO_CONF" >"$d/stdout.log" 2>"$d/stderr.log"
rc=$?

{
  echo "EXIT_CODE=$rc"
  echo "END_LOCAL=$(date)"
} > "$d/exit.txt"

coredumpctl list xmobar --no-pager > "$d/coredump-after.txt" 2>&1 || true
coredumpctl info xmobar > "$d/coredump-info.txt" 2>&1 || true
journalctl --user -b --no-pager | grep -Ei 'xmobar|xmonad' > "$d/user-journal.txt" 2>&1 || true
journalctl -b --no-pager | grep -Ei 'xmobar|segfault|core dump|coredump|SIGSEGV|SIGABRT' > "$d/system-journal.txt" 2>&1 || true

exit "$rc"
