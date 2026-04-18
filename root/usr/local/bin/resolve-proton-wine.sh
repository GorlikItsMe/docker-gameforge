#!/bin/bash
# Print absolute path to Proton's files/bin/wine (same stack as umu-run). Exit 1 if unknown.
# No fallback to /usr/bin/wine — avoids mixing distro Wine with a Proton-managed WINEPREFIX.

set -euo pipefail

HOME="${HOME:-$(getent passwd "$(id -u)" 2>/dev/null | cut -d: -f6)}"
[ -n "${HOME:-}" ] || HOME=/config

candidates=()
if [ -n "${PROTONPATH:-}" ]; then
  case "${PROTONPATH}" in
    /*)
      if [ -x "${PROTONPATH}/files/bin/wine" ]; then
        candidates+=("${PROTONPATH}/files/bin/wine")
      fi
      ;;
  esac
fi

for root in "${HOME}/.local/share/umu" "${HOME}/.local/share/Steam/compatibilitytools.d"; do
  [ -d "$root" ] || continue
  while IFS= read -r w; do
    candidates+=("$w")
  done < <(find "$root" -path '*/files/bin/wine' -type f 2>/dev/null)
done

best=""
best_mtime=-1
declare -A seen=()
for w in "${candidates[@]}"; do
  [ -n "$w" ] && [ -x "$w" ] || continue
  [ -n "${seen[$w]:-}" ] && continue
  seen[$w]=1
  m=$(stat -c %Y "$w" 2>/dev/null || echo 0)
  if [ "$m" -gt "$best_mtime" ]; then
    best_mtime=$m
    best=$w
  fi
done

if [ -n "$best" ]; then
  printf '%s\n' "$best"
  exit 0
fi
exit 1
