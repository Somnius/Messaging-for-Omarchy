#!/usr/bin/env bash

set -euo pipefail

script="${1:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)/AtomicWrite.pl}"
scratch=$(mktemp -d)
trap 'rm -rf -- "$scratch"' EXIT

expect_rejected() {
  local expected="$1" path="$2" limit="$3" data="$4" actual
  set +e
  timeout 2 /usr/bin/perl "$script" "$path" "$limit" "$data" \
    >"$scratch/output" 2>"$scratch/error"
  actual=$?
  set -e
  [[ $actual -eq $expected ]] || {
    echo "unexpected write exit for $path: got $actual, expected $expected" >&2
    return 1
  }
  [[ $actual -ne 124 ]] || {
    echo "writer timed out: $path" >&2
    return 1
  }
}

payload='12345678'
printf 'old\n' >"$scratch/config.json"
timeout 2 /usr/bin/perl "$script" "$scratch/config.json" 8 "$payload"
printf '%s' "$payload" >"$scratch/expected"
cmp "$scratch/expected" "$scratch/config.json"

printf 'sentinel\n' >"$scratch/sentinel"
ln -s sentinel "$scratch/symlink.json"
timeout 2 /usr/bin/perl "$script" "$scratch/symlink.json" 8 "$payload"
[[ ! -L $scratch/symlink.json ]]
cmp "$scratch/expected" "$scratch/symlink.json"
printf 'sentinel\n' >"$scratch/expected-sentinel"
cmp "$scratch/expected-sentinel" "$scratch/sentinel"

printf 'unchanged\n' >"$scratch/rejected.json"
expect_rejected 5 "$scratch/rejected.json" 8 '123456789'
printf 'unchanged\n' >"$scratch/expected-unchanged"
cmp "$scratch/expected-unchanged" "$scratch/rejected.json"

invalid_utf8=$'\377'
expect_rejected 7 "$scratch/rejected.json" 8 "$invalid_utf8"
cmp "$scratch/expected-unchanged" "$scratch/rejected.json"

mkdir "$scratch/destination"
expect_rejected 6 "$scratch/destination" 8 "$payload"
[[ -z $(find "$scratch" -maxdepth 1 -name '.destination.tmp.*' -print -quit) ]]

printf 'atomic writer adversarial checks passed\n'
