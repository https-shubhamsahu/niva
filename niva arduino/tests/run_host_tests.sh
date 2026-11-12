#!/usr/bin/env bash
# Builds and runs every off-target test with g++, and checks that the
# shared headers in niva_hardware/ and niva_protected_steps/ are identical.
# Run from anywhere:  bash "niva arduino/tests/run_host_tests.sh"
# These are software tests with synthetic signals, not evidence about
# sensors or people.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fw="$(dirname "$here")"
out="${TMPDIR:-/tmp}/niva_host_tests"
mkdir -p "$out"
flags=(-std=gnu++17 -Wall -Wextra -Werror -O1)
status=0

for f in niva_signal.h niva_acq.h niva_frame.h; do
  [ -f "$fw/niva_hardware/$f" ] || continue   # older niva_hardware sketch without the shared headers
  if ! cmp -s "$fw/niva_hardware/$f" "$fw/niva_protected_steps/$f"; then
    echo "FAIL shared copy differs: $f (copy niva_hardware/$f to niva_protected_steps/)"
    status=1
  fi
done

run() {
  local name="$1"; shift
  echo "== $name"
  g++ "${flags[@]}" "$@" -o "$out/$name" && "$out/$name" || status=1
}
run contact_detector_test -I"$here/stub" -I"$fw/niva_protected_steps" "$here/contact_detector_test.cpp"
run frame_test -I"$here/stub" -I"$fw/niva_protected_steps" "$here/frame_test.cpp"
run ps_logic_test -I"$fw/niva_protected_steps" "$here/ps_logic_test.cpp"
run board_logic_test -I"$fw/niva_protected_steps" "$here/board_logic_test.cpp"

if [ "$status" -eq 0 ]; then echo "ALL HOST TESTS PASSED"; else echo "HOST TESTS FAILED"; fi
exit "$status"
