#!/bin/bash
# Run winetricks against the Gameforge Wine prefix.
# Examples: run-winetricks.sh corefonts
#           run-winetricks.sh --gui
# See: https://wiki.winehq.org/Winetricks — there is no official verb for Segoe UI Emoji.

WINEPREFIX="${GAMEFORGE_WINEPREFIX:-/config/wine-gameforge}"
export WINEPREFIX

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

if ! command -v winetricks >/dev/null 2>&1; then
  echo "winetricks not found" >&2
  exit 1
fi

exec winetricks "$@"
