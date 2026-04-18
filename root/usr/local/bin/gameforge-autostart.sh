#!/bin/bash
# XFCE autostart: cache GameforgeInstaller.exe under /config and run it once via umu-run
# until a client executable appears in the Wine prefix. Disable: GAMEFORGE_AUTOSTART=false.

LOG=/config/Desktop/gameforge-autostart.log
GAMEFORGE_DIR="${GAMEFORGE_DIR:-/config/gameforge}"
INSTALLER="$GAMEFORGE_DIR/GameforgeInstaller.exe"
DOWNLOAD_URL="${GAMEFORGE_DOWNLOAD_URL:-https://install.gameforge.com/download?download_id=7ec0f5a5-21a3-41c6-8b4d-df8831ead6a8&game_id=df8661d6-a76e-417f-82dc-9fada569615e&locale=pl}"
WINEPREFIX="${GAMEFORGE_WINEPREFIX:-/config/wine-gameforge}"

export WINEPREFIX
export GAMEID="${GAMEFORGE_GAMEID:-umu-default}"
export STORE="${GAMEFORGE_STORE:-none}"

# DXVK needs Vulkan with VK_KHR_surface; Selkies/Xvfb often expose no usable WSI — installer UI dies with
# "Required Vulkan extension VK_KHR_surface not supported". WineD3D (OpenGL) avoids that.
export PROTON_USE_WINED3D="${PROTON_USE_WINED3D:-1}"

CLIENT_REL="${GAMEFORGE_CLIENT_EXE_RELPATH:-drive_c/Program Files (x86)/GameforgeClient/gfclient.exe}"
CLIENT_EXE="$WINEPREFIX/$CLIENT_REL"

# Visible launcher on the desktop (Webtop home is /config). /etc/xdg/autostart entries are session-only, not icons.
update_gameforge_desktop_shortcut() {
  local desk=/config/Desktop
  local shortcut="$desk/Gameforge Client.desktop"
  [ -f "$CLIENT_EXE" ] || return 0
  mkdir -p "$desk" 2>/dev/null || return 0
  umask 022
  cat >"$shortcut" << 'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=Gameforge Client
Comment=Gameforge client (umu-run)
Exec=/usr/local/bin/run-gameforge-client.sh
Icon=applications-games
Terminal=false
Categories=Game;
StartupNotify=true
EOF
  chmod 755 "$shortcut"
}

mkdir -p "$GAMEFORGE_DIR" /config/Desktop 2>/dev/null || true
update_gameforge_desktop_shortcut
{
  echo "=== $(date -Iseconds) start ==="
  echo "GAMEFORGE_AUTOSTART=${GAMEFORGE_AUTOSTART:-} DISPLAY=${DISPLAY:-} WINEPREFIX=$WINEPREFIX"
} >>"$LOG" 2>/dev/null || true

if [ "${GAMEFORGE_AUTOSTART:-true}" != "true" ]; then
  echo "skipped (GAMEFORGE_AUTOSTART not true)" >>"$LOG" 2>/dev/null || true
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

if [ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ] && [ -S "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/bus" ]; then
  export DBUS_SESSION_BUS_ADDRESS="unix:path=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/bus"
fi

if ! command -v umu-run >/dev/null 2>&1; then
  echo "error: umu-run not in PATH" >>"$LOG" 2>/dev/null || true
  exit 0
fi

sleep 8

find_client() {
  [ -d "$WINEPREFIX/drive_c" ] || return 1
  find "$WINEPREFIX/drive_c" -type f \( \
    -iname 'GameforgeClient.exe' -o \
    -iname 'gfclient*.exe' -o \
    -iname '*Gameforge*Launcher*.exe' \
  \) 2>/dev/null | head -1
}

if client="$(find_client)" && [ -n "$client" ] && [ -f "$client" ]; then
  echo "skip install: client already present ($client)" >>"$LOG" 2>/dev/null || true
  exit 0
fi

minsize=500000
if [ ! -f "$INSTALLER" ] || [ ! -s "$INSTALLER" ]; then
  need_dl=1
else
  sz=$(stat -c%s "$INSTALLER" 2>/dev/null || echo 0)
  [ "$sz" -lt "$minsize" ] && need_dl=1
fi

if [ "${need_dl:-}" = 1 ]; then
  echo "downloading installer -> $INSTALLER" >>"$LOG" 2>/dev/null || true
  rm -f "$INSTALLER" "$INSTALLER.part"
  if ! curl -fL --retry 3 --retry-delay 2 -o "$INSTALLER.part" "$DOWNLOAD_URL" >>"$LOG" 2>&1; then
    echo "download failed" >>"$LOG" 2>/dev/null || true
    rm -f "$INSTALLER.part"
    exit 0
  fi
  mv "$INSTALLER.part" "$INSTALLER"
fi

echo "running: PROTON_USE_WINED3D=$PROTON_USE_WINED3D umu-run $INSTALLER" >>"$LOG" 2>/dev/null || true
# Selkies injects 64-bit LD_PRELOAD shims; 32-bit Wine PE helpers (e.g. gfservice.exe) log ELFCLASS noise.
LD_PRELOAD= umu-run "$INSTALLER" >>"$LOG" 2>&1 || echo "umu-run exited $?" >>"$LOG" 2>/dev/null || true

if client="$(find_client)" && [ -n "$client" ]; then
  echo "after run: detected client ($client)" >>"$LOG" 2>/dev/null || true
else
  echo "after run: no client exe matched yet (complete the wizard or check log)" >>"$LOG" 2>/dev/null || true
fi
exit 0
