#!/bin/bash
# After XFCE starts: optional xfce4-panel /size (px); empty = no-op.

SIZE="${XFCE_PANEL_SIZE:-}"

if [ -z "$SIZE" ]; then
  exit 0
fi

if [ -z "${DISPLAY:-}" ]; then
  for sock in /tmp/.X11-unix/X[0-9]*; do
    [ -S "$sock" ] || continue
    export DISPLAY=":${sock##*/X}"
    break
  done
fi
export DISPLAY="${DISPLAY:-:0}"

sleep 4

read_int_prop() {
  xfconf-query -c xfce4-panel -p "$1" 2>/dev/null | grep -oE '[0-9]+' | head -1
}

set_int_prop() {
  local prop="$1" val="$2"
  if xfconf-query -c xfce4-panel -p "$prop" -s "$val" -t int 2>/dev/null; then
    return 0
  fi
  xfconf-query -c xfce4-panel -p "$prop" -n -t int -s "$val" 2>/dev/null || true
}

for n in 1 0 2 3; do
  prop="/panels/panel-$n/size"
  cur=$(read_int_prop "$prop")
  [ -z "$cur" ] && continue
  set_int_prop "$prop" "$SIZE"
done
exit 0
