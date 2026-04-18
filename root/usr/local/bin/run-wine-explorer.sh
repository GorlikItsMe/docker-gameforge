#!/bin/bash
# Open Windows Explorer (Wine) in the Gameforge prefix via umu-run.

WINEPREFIX="${GAMEFORGE_WINEPREFIX:-/config/wine-gameforge}"
EXPLORER="$WINEPREFIX/drive_c/windows/explorer.exe"

export WINEPREFIX
export WINEARCH="${WINEARCH:-win64}"
export GAMEID="${GAMEFORGE_GAMEID:-umu-default}"
export STORE="${GAMEFORGE_STORE:-none}"
export PROTONPATH="${PROTONPATH:-${GAMEFORGE_PROTONPATH:-}}"
export PROTON_USE_WINED3D="${PROTON_USE_WINED3D:-1}"
export TZ="${TZ:-Europe/Warsaw}"

if [ -z "${DISPLAY:-}" ]; then
  for sock in /tmp/.X11-unix/X[0-9]*; do
    [ -S "$sock" ] || continue
    export DISPLAY=":${sock##*/X}"
    break
  done
fi
export DISPLAY="${DISPLAY:-:0}"

if [ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ] && [ -S "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/bus" ]; then
  export DBUS_SESSION_BUS_ADDRESS="unix:path=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/bus"
fi

if [ ! -f "$EXPLORER" ]; then
  msg="Wine Explorer not found (prefix not initialized yet?):\n$EXPLORER"
  command -v zenity >/dev/null 2>&1 && zenity --error --no-wrap --text="$msg" 2>/dev/null
  echo "$msg" >&2
  exit 1
fi

exec env LD_PRELOAD= umu-run "$EXPLORER" "$@"
