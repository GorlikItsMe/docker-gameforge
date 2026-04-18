#!/bin/bash
# Launch installed Gameforge client via umu-run (double-click from Desktop or run in terminal).

WINEPREFIX="${GAMEFORGE_WINEPREFIX:-/config/wine-gameforge}"
CLIENT_REL="${GAMEFORGE_CLIENT_EXE_RELPATH:-drive_c/Program Files (x86)/GameforgeClient/gfclient.exe}"

export WINEPREFIX
export GAMEID="${GAMEFORGE_GAMEID:-umu-default}"
export STORE="${GAMEFORGE_STORE:-none}"
export PROTON_USE_WINED3D="${PROTON_USE_WINED3D:-1}"

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

exe="$WINEPREFIX/$CLIENT_REL"
if [ ! -f "$exe" ]; then
  msg="Gameforge Client not found at:\n$exe"
  command -v zenity >/dev/null 2>&1 && zenity --error --no-wrap --text="$msg" 2>/dev/null
  echo "$msg" >&2
  exit 1
fi

exec env LD_PRELOAD= umu-run "$exe" "$@"
