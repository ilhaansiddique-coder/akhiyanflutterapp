#!/usr/bin/env bash
# scripts/unstuck-emulator.sh
#
# Unstick a frozen Android emulator. When the emulator crashes or is killed
# without cleanup, lock files remain in the AVD directory and the next
# launch fails with "Running multiple emulators with the same AVD".
# This script kills zombie processes and removes the stale locks.
#
# Usage (from any directory in Git Bash):
#   ./scripts/unstuck-emulator.sh          # kill + clean locks only
#   ./scripts/unstuck-emulator.sh launch   # also re-launch the first AVD
#
# Requires: flutter on PATH (only needed for the `launch` subcommand).

set -u

AVD_DIR="$HOME/.android/avd"

echo "==> Killing zombie emulator / qemu processes"
killed=0
for proc in qemu-system-x86_64.exe emulator.exe emu64-x86_64.exe emulator-headless.exe; do
  if taskkill //F //IM "$proc" 2>/dev/null | grep -qi "SUCCESS"; then
    echo "    killed: $proc"
    killed=$((killed + 1))
  fi
done
[ "$killed" = "0" ] && echo "    no zombies"

# Let Windows release file handles before touching locks
sleep 1

echo "==> Cleaning lock files in $AVD_DIR"
if [ ! -d "$AVD_DIR" ]; then
  echo "    AVD dir not found — nothing to clean"
else
  cleaned=0
  blocked=0
  while IFS= read -r -d '' f; do
    if rm -rf "$f" 2>/dev/null; then
      echo "    removed: ${f#"$AVD_DIR"/}"
      cleaned=$((cleaned + 1))
    else
      echo "    blocked (still locked): ${f#"$AVD_DIR"/}"
      blocked=$((blocked + 1))
    fi
  done < <(find "$AVD_DIR" -maxdepth 3 \( -name "*.lock" -o -name "multiinstance.lock" \) -print0 2>/dev/null)
  [ "$cleaned" = "0" ] && [ "$blocked" = "0" ] && echo "    no lock files found"
fi

# Optional: re-launch the first AVD
if [ "${1:-}" = "launch" ]; then
  if ! command -v flutter >/dev/null 2>&1; then
    echo "==> flutter not on PATH — cannot launch"
    exit 1
  fi
  first_avd=$(ls -1 "$AVD_DIR" 2>/dev/null | grep '\.avd$' | head -1 | sed 's/\.avd$//')
  if [ -z "$first_avd" ]; then
    echo "==> No AVDs found in $AVD_DIR"
    exit 1
  fi
  echo "==> Launching: $first_avd"
  flutter emulators --launch "$first_avd"
fi

echo "==> Done"
