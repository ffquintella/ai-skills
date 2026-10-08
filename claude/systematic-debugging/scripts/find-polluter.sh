#!/usr/bin/env bash
# Finds the first test file that leaves a given file or directory behind.
#
# Usage: find-polluter.sh <path-that-should-not-exist> <test-command> <test-file>...
#   e.g. find-polluter.sh .git 'npm test --' src/*.test.ts
#
# <test-command> is word-split and run once per file with the file appended.
# Files run one at a time, in the order given, so cost is up to one run per file.
set -u

if [ "$#" -lt 3 ]; then
  echo "usage: $0 <path> <test-command> <test-file>..." >&2
  exit 2
fi

path=$1
cmd=$2
shift 2

if [ -e "$path" ]; then
  echo "'$path' already exists; remove it first so a test can be blamed" >&2
  exit 2
fi

total=$#
i=0
for file in "$@"; do
  i=$((i + 1))
  echo "[$i/$total] $file"
  # shellcheck disable=SC2086
  $cmd "$file" >/dev/null 2>&1 || true
  if [ -e "$path" ]; then
    echo "POLLUTER: $file created '$path'"
    ls -ld "$path"
    echo "Rerun alone: $cmd '$file'"
    exit 1
  fi
done

echo "No test file created '$path'"
