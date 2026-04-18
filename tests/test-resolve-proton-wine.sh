#!/usr/bin/env bash
# Shell tests for resolve-proton-wine.sh (run on Linux CI or Git Bash with coreutils find).

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RESOLVER="$REPO_ROOT/root/usr/local/bin/resolve-proton-wine.sh"

fail=0

die() {
  echo "FAIL: $*" >&2
  fail=1
}

assert_eq() {
  local got="$1" want="$2" msg="$3"
  if [ "$got" != "$want" ]; then
    die "$msg — want '$want', got '$got'"
  fi
}

make_executable_wine() {
  local f="$1"
  mkdir -p "$(dirname "$f")"
  printf '#!/bin/sh\nexit 0\n' >"$f"
  chmod +x "$f"
}

run_one() {
  HOME="$1" PROTONPATH="${2:-}" bash "$RESOLVER" 2>/dev/null || true
}

TMP_BASE="$(mktemp -d)"
trap 'rm -rf "$TMP_BASE"' EXIT

echo "== resolve-proton-wine tests =="

# 1: single UMU tree
H1="$TMP_BASE/h1"
mkdir -p "$H1/.local/share/umu/p1/files/bin"
W1="$H1/.local/share/umu/p1/files/bin/wine"
make_executable_wine "$W1"
got="$(run_one "$H1")"
assert_eq "$got" "$W1" "single umu wine"

# 2: wine is a symlink to an executable file
H2="$TMP_BASE/h2"
mkdir -p "$H2/.local/share/umu/sy/files/bin"
REAL="$H2/.local/share/umu/sy/files/bin/wine-real"
make_executable_wine "$REAL"
ln -sf wine-real "$H2/.local/share/umu/sy/files/bin/wine"
got="$(run_one "$H2")"
assert_eq "$got" "$H2/.local/share/umu/sy/files/bin/wine" "symlink wine"

# 3: PROTONPATH absolute chooses that tree over newer mtime elsewhere in umu
H3="$TMP_BASE/h3"
mkdir -p "$H3/.local/share/umu/older/files/bin" "$H3/.local/share/umu/newer/files/bin"
WO="$H3/.local/share/umu/older/files/bin/wine"
WN="$H3/.local/share/umu/newer/files/bin/wine"
make_executable_wine "$WO"
make_executable_wine "$WN"
touch -t 201001010000 "$WO" 2>/dev/null || touch "$WO"
touch -t 203501010000 "$WN" 2>/dev/null || touch "$WN"
got="$(run_one "$H3" "$H3/.local/share/umu/older")"
assert_eq "$got" "$WO" "PROTONPATH pins older tree"

# 4: UMU tier wins over Steam compatibilitytools.d even if Steam is newer
H4="$TMP_BASE/h4"
mkdir -p "$H4/.local/share/umu/u/files/bin" "$H4/.local/share/Steam/compatibilitytools.d/s/files/bin"
WU="$H4/.local/share/umu/u/files/bin/wine"
WS="$H4/.local/share/Steam/compatibilitytools.d/s/files/bin/wine"
make_executable_wine "$WU"
make_executable_wine "$WS"
touch -t 202001010000 "$WU" 2>/dev/null || touch "$WU"
touch -t 204001010000 "$WS" 2>/dev/null || touch "$WS"
got="$(run_one "$H4")"
assert_eq "$got" "$WU" "umu before steam when both exist"

# 5: empty umu, steam only
H5="$TMP_BASE/h5"
mkdir -p "$H5/.local/share/Steam/compatibilitytools.d/x/files/bin"
W5="$H5/.local/share/Steam/compatibilitytools.d/x/files/bin/wine"
make_executable_wine "$W5"
got="$(run_one "$H5")"
assert_eq "$got" "$W5" "steam only"

# 6: relative PROTONPATH under HOME
H6="$TMP_BASE/h6"
mkdir -p "$H6/myproton/files/bin"
W6="$H6/myproton/files/bin/wine"
make_executable_wine "$W6"
got="$(run_one "$H6" "myproton")"
assert_eq "$got" "$W6" "relative PROTONPATH via \$HOME"

# 7: bogus relative PROTONPATH exits 1 and prints hint on stderr
H7="$TMP_BASE/h7"
mkdir -p "$H7/.local/share/umu"
set +e
err="$(HOME="$H7" PROTONPATH="does-not-exist" bash "$RESOLVER" 2>&1)"
st=$?
set -e
if [ "$st" -eq 0 ]; then
  die "expected non-zero exit from resolver (got 0)"
fi
if ! printf '%s\n' "$err" | grep -q 'relative but not found'; then
  die "expected stderr hint for bad PROTONPATH, got: $err"
fi

if [ "$fail" -ne 0 ]; then
  echo "Some tests failed." >&2
  exit 1
fi
echo "OK (all tests passed)"
