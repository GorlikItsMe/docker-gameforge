#!/bin/bash
# Run winetricks against the Gameforge Wine prefix using Proton's wine (umu-run stack), not distro /usr/bin/wine.
# Examples: run-winetricks.sh corefonts
#           run-winetricks.sh --gui
# See: https://wiki.winehq.org/Winetricks — there is no official verb for Segoe UI Emoji.

WINEPREFIX="${GAMEFORGE_WINEPREFIX:-/config/wine-gameforge}"
export WINEPREFIX

# Inherit GAMEID / STORE / PROTONPATH from the environment so resolution matches umu-run (compose).
export GAMEID="${GAMEFORGE_GAMEID:-${GAMEID:-umu-default}}"
export STORE="${GAMEFORGE_STORE:-${STORE:-none}}"
export PROTONPATH="${PROTONPATH:-${GAMEFORGE_PROTONPATH:-}}"

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

proton_wine="$(/usr/local/bin/resolve-proton-wine.sh)" || {
  echo "Could not find Proton files/bin/wine. Run any umu-run once, or set PROTONPATH to an unpacked Proton directory." >&2
  exit 1
}
export WINE="$proton_wine"
# Selkies sets 64-bit preload shims; winetricks runs 32-bit wine — avoid ld.so ELFCLASS noise.
export LD_PRELOAD=

exec winetricks "$@"
