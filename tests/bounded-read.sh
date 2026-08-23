#!/usr/bin/env bash

set -euo pipefail

script="${1:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)/BoundedRead.pl}"
scratch=$(mktemp -d)
trap 'rm -rf -- "$scratch"' EXIT

expect_rejected() {
  local expected="$1" path="$2" limit="$3" actual
  set +e
  timeout 2 /usr/bin/perl "$script" "$path" "$limit" \
    >"$scratch/output" 2>"$scratch/error"
  actual=$?
  set -e
  [[ $actual -eq $expected ]] || {
    echo "unexpected exit for $path: got $actual, expected $expected" >&2
    return 1
  }
  [[ $actual -ne 124 ]] || {
    echo "reader timed out: $path" >&2
    return 1
  }
  [[ ! -s $scratch/output ]] || {
    echo "rejected input leaked output: $path" >&2
    return 1
  }
}

printf 'bounded\n' >"$scratch/regular"
timeout 2 /usr/bin/perl "$script" "$scratch/regular" 8 >"$scratch/output"
cmp "$scratch/regular" "$scratch/output"

ln "$scratch/regular" "$scratch/hardlink"
timeout 2 /usr/bin/perl "$script" "$scratch/hardlink" 8 >"$scratch/output"
cmp "$scratch/regular" "$scratch/output"

printf '123456789' >"$scratch/overflow"
expect_rejected 5 "$scratch/overflow" 8

expect_rejected 2 "$scratch/missing" 8

ln -s regular "$scratch/symlink"
expect_rejected 3 "$scratch/symlink" 8

mkfifo "$scratch/fifo"
expect_rejected 4 "$scratch/fifo" 8
expect_rejected 4 "$scratch" 8
expect_rejected 4 /dev/null 8
expect_rejected 4 /dev/zero 8

printf '\377' >"$scratch/invalid-utf8"
expect_rejected 7 "$scratch/invalid-utf8" 8

printf 'bounded reader adversarial checks passed\n'
