#!/bin/bash
# Launch installed Gameforge client via umu-run (double-click from Desktop or run in terminal).
# Optional first argument: absolute path to the client .exe (when discovered outside the default CLIENT_REL).

WINEPREFIX="${GAMEFORGE_WINEPREFIX:-/config/wine-gameforge}"
CLIENT_REL="${GAMEFORGE_CLIENT_EXE_RELPATH:-drive_c/Program Files (x86)/GameforgeClient/gfclient.exe}"

export WINEPREFIX
export WINEARCH="${WINEARCH:-win64}"
export GAMEID="${GAMEFORGE_GAMEID:-umu-default}"
export STORE="${GAMEFORGE_STORE:-none}"
export PROTONPATH="${PROTONPATH:-${GAMEFORGE_PROTONPATH:-}}"
export PROTON_USE_WINED3D="${PROTON_USE_WINED3D:-1}"

# IANA timezone for Wine/Proton + .NET/CEF (inherits container TZ; default Europe/Warsaw).
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

exe=""
if [ -n "${1:-}" ] && [ -f "$1" ]; then
  exe="$1"
  shift
fi
if [ -z "$exe" ]; then
  exe="$WINEPREFIX/$CLIENT_REL"
fi
if [ ! -f "$exe" ]; then
  msg="Gameforge Client not found at:\n$exe"
  command -v zenity >/dev/null 2>&1 && zenity --error --no-wrap --text="$msg" 2>/dev/null
  echo "$msg" >&2
  exit 1
fi

# CEF uses Chromium; mirror /etc/chromium.d/gameforge-webgl so the in-app browser/WebGL
# sees the same baseline as system Chromium (Docker + llvmpipe). Set GAMEFORGE_CEF_CHROME_FLAGS=0 to skip.
cef_args=()
if [ "${GAMEFORGE_CEF_CHROME_FLAGS:-1}" != "0" ]; then
  cef_args+=(--disable-gpu-sandbox --disable-dev-shm-usage --ignore-gpu-blocklist)
fi

LOG="${GAMEFORGE_CLIENT_LOG:-/config/Desktop/gameforge-client.log}"
mkdir -p "$(dirname "$LOG")" 2>/dev/null || true
{
  echo "=== $(date -Iseconds) Gameforge Client start ==="
  echo "DISPLAY=$DISPLAY TZ=$TZ WINEPREFIX=$WINEPREFIX"
  echo "exe=$exe"
  printf 'cef_args=%q ' "${cef_args[@]}"; echo
  echo "extra_args=$*"
} >>"$LOG"

if [ -t 1 ]; then
  env LD_PRELOAD= umu-run "$exe" "${cef_args[@]}" "$@" 2>&1 | tee -a "$LOG"
  exit "${PIPESTATUS[0]}"
fi

exec env LD_PRELOAD= umu-run "$exe" "${cef_args[@]}" "$@" >>"$LOG" 2>&1
