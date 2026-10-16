#!/usr/bin/env bash
# Sets the ai-skills version in VERSION and in every plugin manifest, which must
# agree: Codex caches an installed plugin by version, so a reinstall without a
# bump can keep serving the old copy.
#
#   scripts/bump-version.sh 0.3.0     set the version
#   scripts/bump-version.sh --check   exit 1 if any manifest disagrees with VERSION

set -euo pipefail
cd "$(dirname "$0")/.."

MANIFESTS=".claude-plugin/plugin.json .claude-plugin/marketplace.json .codex-plugin/plugin.json"

if [ "${1:-}" = "--check" ]; then
  want="$(tr -d '[:space:]' < VERSION)"; bad=0
  for f in $MANIFESTS; do
    for got in $(sed -n 's/.*"version": *"\([^"]*\)".*/\1/p' "$f"); do
      [ "$got" = "$want" ] || { echo "$f: version $got, VERSION says $want"; bad=1; }
    done
  done
  [ "$bad" = 0 ] && echo "all manifests at $want"
  exit "$bad"
fi

new="${1:-}"
case "$new" in
  [0-9]*.[0-9]*.[0-9]*) ;;
  *) echo "usage: $0 <major.minor.patch> | --check" >&2; exit 2 ;;
esac
printf '%s\n' "$new" > VERSION
for f in $MANIFESTS; do
  sed -i.bak "s/\"version\": *\"[^\"]*\"/\"version\": \"$new\"/" "$f" && rm -f "$f.bak"
done
echo "version set to $new in VERSION and: $MANIFESTS"
