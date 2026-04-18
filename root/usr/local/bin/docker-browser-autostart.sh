#!/bin/bash
# XFCE autostart helper. Disable: BROWSER_AUTOSTART=false in docker-compose.
# Log: /config/Desktop/browser-autostart.log (if /config is writable).
LOG=/config/Desktop/browser-autostart.log
mkdir -p /config/Desktop 2>/dev/null || true
{
  echo "=== $(date -Iseconds) start ==="
  echo "BROWSER_AUTOSTART=${BROWSER_AUTOSTART:-} DISPLAY=${DISPLAY:-} XDG_CURRENT_DESKTOP=${XDG_CURRENT_DESKTOP:-}"
} >>"$LOG" 2>/dev/null || true

if [ "${BROWSER_AUTOSTART:-true}" != "true" ]; then
  echo "skipped (BROWSER_AUTOSTART not true)" >>"$LOG" 2>/dev/null || true
  exit 0
fi

if [ -z "${DISPLAY:-}" ]; then
  for sock in /tmp/.X11-unix/X[0-9]*; do
    [ -S "$sock" ] || continue
    DISPLAY=":${sock##*/X}"
    break
  done
fi
export DISPLAY="${DISPLAY:-:0}"

# Session D-Bus (exo-open / Chromium often need this in containers)
if [ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ] && [ -S "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/bus" ]; then
  export DBUS_SESSION_BUS_ADDRESS="unix:path=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/bus"
fi

sleep 5

launch() {
  if command -v exo-open >/dev/null 2>&1; then
    echo "trying exo-open" >>"$LOG" 2>/dev/null || true
    exo-open --launch WebBrowser && return 0
  fi
  if command -v chromium >/dev/null 2>&1; then
    echo "trying chromium" >>"$LOG" 2>/dev/null || true
    chromium --no-first-run about:blank && return 0
  fi
  if command -v firefox >/dev/null 2>&1; then
    echo "trying firefox" >>"$LOG" 2>/dev/null || true
    firefox about:blank && return 0
  fi
  echo "trying x-www-browser" >>"$LOG" 2>/dev/null || true
  x-www-browser about:blank 2>/dev/null && return 0
  return 1
}

if launch; then
  echo "launch ok" >>"$LOG" 2>/dev/null || true
else
  echo "launch failed (all backends)" >>"$LOG" 2>/dev/null || true
fi
exit 0
