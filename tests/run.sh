#!/usr/bin/env bash

set -euo pipefail

repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
qt_bin=$(dirname -- "$(readlink -f -- "$(command -v qml6)")")
qmltestrunner="$qt_bin/qmltestrunner"
scratch=$(mktemp -d)
trap 'rm -rf -- "$scratch"' EXIT

bash "$repo/tests/bounded-read.sh" "$repo/BoundedRead.pl"
bash "$repo/tests/atomic-write.sh" "$repo/AtomicWrite.pl"
env -u DISPLAY -u WAYLAND_DISPLAY \
  QT_QPA_PLATFORM=offscreen QT_QPA_PLATFORMTHEME= \
  "$qmltestrunner" -input "$repo/tests"

mkdir -m 700 "$scratch/home" "$scratch/runtime" "$scratch/shell"
cp "$repo/Service.qml" "$repo/ConfigPolicy.js" "$repo/BoundedRead.pl" \
  "$repo/AtomicWrite.pl" \
  "$repo/tests/runtime/shell.qml" "$scratch/shell/"
mkdir -p "$scratch/home/.config/omarchy/messaging"
cat >"$scratch/home/record-launch" <<'SH'
#!/bin/sh
printf '%s\n' "$*" >>"$HOME/launches"
SH
chmod 700 "$scratch/home/record-launch"
printf 'sentinel\n' >"$scratch/sentinel"
ln -s "$scratch/sentinel" \
  "$scratch/home/.config/omarchy/messaging/config.json"
env -u DISPLAY -u WAYLAND_DISPLAY \
  HOME="$scratch/home" XDG_RUNTIME_DIR="$scratch/runtime" \
  XDG_CACHE_HOME="$scratch/cache" XDG_STATE_HOME="$scratch/state" \
  QT_QPA_PLATFORM=offscreen QT_QPA_PLATFORMTHEME= \
  timeout 5 quickshell --no-color --log-rules 'quickshell.ipc=false' \
    -p "$scratch/shell"

written="$scratch/written-config.json"
[[ ! -L $scratch/home/.config/omarchy/messaging/config.json ]]
[[ $(<"$scratch/sentinel") == sentinel ]]
/usr/bin/perl "$repo/BoundedRead.pl" \
  "$scratch/home/.config/omarchy/messaging/config.json" 65536 >"$written"
jq -e '
  .apps.slack.enabled == true
  and .apps.slack.url == "http://localhost:3000/chat"
  and .apps.discord.enabled == true
  and .apps.whatsapp.enabled == true
' "$written" >/dev/null
grep -F -- '--app=http://localhost:3000/chat' "$scratch/home/launches" >/dev/null
grep -F -- '--app=https://discord.com/channels/@me' "$scratch/home/launches" >/dev/null
printf 'service state, launch gate, and atomic write checks passed\n'
