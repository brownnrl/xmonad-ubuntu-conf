#!/usr/bin/env bash
set -uo pipefail

ARTBASE="$HOME/.xmonad/xmobar-artifacts"
mkdir -p "$ARTBASE"

while true; do
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

  # Run xmobar with logs captured.
  # stdbuf forces line-buffered output so you see the last lines before death.
  stdbuf -oL -eL xmobar -x 0 "$HOME/.xmonad/xmobarrc" >"$d/stdout.log" 2>"$d/stderr.log"
  rc=$?

  echo "xmobar exited rc=$rc at $(date -u +%Y-%m-%dT%H:%M:%S%z)" > "$d/exit.log"

  # Capture session journal slice around the exit time (best-effort).
  journalctl --user -S "5 minutes ago" -u xmonad --no-pager > "$d/journal_user_xmonad.log" 2>&1 || true

  # If it exits due to SIGTERM (143) you probably killed it; still restart.
  sleep 1
done
