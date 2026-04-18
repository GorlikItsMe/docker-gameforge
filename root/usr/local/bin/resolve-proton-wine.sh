#!/bin/bash
# Print absolute path to Proton's files/bin/wine (same stack as umu-run). Exit 1 if unknown.
# No fallback to /usr/bin/wine — avoids mixing distro Wine with a Proton-managed WINEPREFIX.
#
# Order: executable wine under resolved PROTONPATH (if set), else newest under
# ~/.local/share/umu only, else newest under Steam compatibilitytools.d.
# UMU-managed trees are preferred over compatibilitytools.d so winetricks matches what
# umu-run typically unpacked, not an arbitrary newer GE build in Steam's folder.

set -euo pipefail

HOME="${HOME:-$(getent passwd "$(id -u)" 2>/dev/null | cut -d: -f6)}"
[ -n "${HOME:-}" ] || HOME=/config

# Print absolute Proton root from PROTONPATH, or empty line. Warn on stderr if set but unusable.
resolve_proton_root() {
  local raw abs
  raw="${PROTONPATH:-}"
  [ -n "$raw" ] || { printf '%s\n' ""; return 0; }

  case "$raw" in
    /*)
      abs="$raw"
      if [ ! -d "$abs" ]; then
        echo "resolve-proton-wine: PROTONPATH is not a directory: $abs" >&2
        printf '%s\n' ""
        return 0
      fi
      ;;
    *)
      if [ -d "$raw" ]; then
        abs="$(cd "$raw" && pwd)"
      elif [ -d "${HOME}/${raw#/}" ]; then
        abs="$(cd "${HOME}/${raw#/}" && pwd)"
      else
        echo "resolve-proton-wine: PROTONPATH is relative but not found: $raw (use an absolute path, cwd, or \$HOME/...)" >&2
        printf '%s\n' ""
        return 0
      fi
      ;;
  esac
  printf '%s\n' "$abs"
}

list_wine_candidates_in() {
  local root="$1"
  [ -d "$root" ] || return 0
  # Include symlinks (-type l): some Proton layouts use wine -> wrapper.
  find "$root" -path '*/files/bin/wine' \( -type f -o -type l \) 2>/dev/null | LC_ALL=C sort -u || true
}

pick_newest_executable() {
  local best="" best_mtime=-1 w m
  while IFS= read -r w; do
    [ -n "$w" ] || continue
    [ -x "$w" ] || continue
    m=$(stat -c %Y "$w" 2>/dev/null || echo 0)
    if [ "$m" -gt "$best_mtime" ]; then
      best_mtime=$m
      best=$w
    fi
  done
  printf '%s\n' "$best"
}

proton_root="$(resolve_proton_root)"
best=""

if [ -n "$proton_root" ] && [ -x "${proton_root}/files/bin/wine" ]; then
  best="${proton_root}/files/bin/wine"
else
  best="$(list_wine_candidates_in "${HOME}/.local/share/umu" | pick_newest_executable)"
  if [ -z "$best" ]; then
    best="$(list_wine_candidates_in "${HOME}/.local/share/Steam/compatibilitytools.d" | pick_newest_executable)"
  fi
fi

if [ -n "$best" ]; then
  printf '%s\n' "$best"
  exit 0
fi
exit 1
