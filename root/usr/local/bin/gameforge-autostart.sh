#!/bin/bash
# XFCE autostart: if gfclient (or another known client exe) is already installed, launch it;
# otherwise cache GameforgeInstaller.exe under /config and run the installer via umu-run.
# Disable: GAMEFORGE_AUTOSTART=false.

LOG=/config/Desktop/gameforge-autostart.log
GAMEFORGE_DIR="${GAMEFORGE_DIR:-/config/gameforge}"
INSTALLER="$GAMEFORGE_DIR/GameforgeInstaller.exe"
DOWNLOAD_URL="${GAMEFORGE_DOWNLOAD_URL:-https://install.gameforge.com/download?download_id=7ec0f5a5-21a3-41c6-8b4d-df8831ead6a8&game_id=df8661d6-a76e-417f-82dc-9fada569615e&locale=pl}"
WINEPREFIX="${GAMEFORGE_WINEPREFIX:-/config/wine-gameforge}"

export WINEPREFIX
# Proton/Gameforge need a 64-bit (WoW64) prefix; winetricks before first umu-run could initialize 32-bit-only.
export WINEARCH="${WINEARCH:-win64}"
export GAMEID="${GAMEFORGE_GAMEID:-umu-default}"
export STORE="${GAMEFORGE_STORE:-none}"
# umu-run uses PROTONPATH; prefer an explicit PROTONPATH over GAMEFORGE_PROTONPATH when both are set.
export PROTONPATH="${PROTONPATH:-${GAMEFORGE_PROTONPATH:-}}"

# DXVK needs Vulkan with VK_KHR_surface; Selkies/Xvfb often expose no usable WSI — installer UI dies with
# "Required Vulkan extension VK_KHR_surface not supported". WineD3D (OpenGL) avoids that.
export PROTON_USE_WINED3D="${PROTON_USE_WINED3D:-1}"

# IANA timezone for Wine/Proton during install (inherits container TZ; default Europe/Warsaw).
export TZ="${TZ:-Europe/Warsaw}"

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

update_wine_explorer_desktop_shortcut() {
  local desk=/config/Desktop
  local shortcut="$desk/Wine Explorer.desktop"
  mkdir -p "$desk" 2>/dev/null || return 0
  umask 022
  cat >"$shortcut" << 'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=Wine Explorer
Comment=Windows Explorer in the Wine prefix (umu-run)
Exec=/usr/local/bin/run-wine-explorer.sh
Icon=folder
Terminal=false
Categories=System;FileManager;
StartupNotify=true
EOF
  chmod 755 "$shortcut"
}

mkdir -p "$GAMEFORGE_DIR" /config/Desktop 2>/dev/null || true
update_gameforge_desktop_shortcut
update_wine_explorer_desktop_shortcut
{
  echo "=== $(date -Iseconds) start ==="
  echo "GAMEFORGE_AUTOSTART=${GAMEFORGE_AUTOSTART:-} DISPLAY=${DISPLAY:-} TZ=${TZ:-} WINEPREFIX=$WINEPREFIX"
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

# One-shot MS core fonts via winetricks using Proton's wine (same as umu-run), not /usr/bin/wine.
# Stamped under GAMEFORGE_DIR. First session may skip if Proton not extracted yet — runs again after installer. Disable: WINETRICKS_COREFONTS=false
maybe_winetricks_corefonts() {
  [ "${WINETRICKS_COREFONTS:-true}" = "true" ] || return 0
  command -v winetricks >/dev/null 2>&1 || return 0
  # Do not run winetricks on an empty prefix: first Wine process was 32-bit helpers → prefix stays 32-bit-only
  # and umu-run then fails with "cannot support 64-bit applications". Defer until Proton created system.reg.
  if [ ! -f "$WINEPREFIX/system.reg" ]; then
    echo "winetricks corefonts: skipping until Wine prefix exists (avoid 32-bit-only bottle)" >>"$LOG" 2>/dev/null || true
    return 0
  fi
  local stamp="$GAMEFORGE_DIR/.winetricks-corefonts.done"
  [ -f "$stamp" ] && return 0
  local proton_wine
  proton_wine="$(/usr/local/bin/resolve-proton-wine.sh 2>/dev/null)" || {
    echo "winetricks corefonts: Proton wine not found yet (~/.local/share/umu or PROTONPATH); will retry" >>"$LOG" 2>/dev/null || true
    return 0
  }
  echo "winetricks -q corefonts WINE=$proton_wine (one-time; see $stamp)" >>"$LOG" 2>/dev/null || true
  # Clear Selkies 64-bit LD_PRELOAD so 32-bit wine/regedit from winetricks does not spam ELFCLASS64.
  if ( export WINE="$proton_wine"; export WINEARCH="${WINEARCH:-win64}"; export LD_PRELOAD=; winetricks -q corefonts >>"$LOG" 2>&1 ); then
    touch "$stamp"
    echo "winetricks corefonts finished" >>"$LOG" 2>/dev/null || true
  else
    echo "winetricks corefonts failed; will retry next login" >>"$LOG" 2>/dev/null || true
  fi
}

maybe_winetricks_corefonts

find_client() {
  [ -d "$WINEPREFIX/drive_c" ] || return 1
  find "$WINEPREFIX/drive_c" -type f \( \
    -iname 'GameforgeClient.exe' -o \
    -iname 'gfclient*.exe' -o \
    -iname '*Gameforge*Launcher*.exe' \
  \) 2>/dev/null | LC_ALL=C sort | head -1
}

# Prefer the configured default path; fall back to a search under drive_c.
client_path=""
if [ -f "$CLIENT_EXE" ]; then
  client_path="$CLIENT_EXE"
else
  c="$(find_client)" || true
  if [ -n "$c" ] && [ -f "$c" ]; then
    client_path="$c"
  fi
fi

if [ -n "$client_path" ]; then
  echo "skip install: launching client ($client_path)" >>"$LOG" 2>/dev/null || true
  update_gameforge_desktop_shortcut
  LD_PRELOAD= /usr/local/bin/run-gameforge-client.sh "$client_path" >>"$LOG" 2>&1 &
  disown 2>/dev/null || true
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

# First login often has no Proton tree until umu-run above — retry corefonts now that UMU may have unpacked it.
maybe_winetricks_corefonts

exit 0
