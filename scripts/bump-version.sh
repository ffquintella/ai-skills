#!/usr/bin/env bash
# Sets the ai-skills version in VERSION, in every plugin manifest and in the
# agent-router crate (Cargo.toml and its Cargo.lock entry), which must all agree:
# Codex caches an installed plugin by version, so a reinstall without a bump can
# keep serving the old copy, and scripts/router-runtime.sh rebuilds an installed
# agent-router only when `agent-router --version` differs from the crate.
#
#   scripts/bump-version.sh 0.3.0     set the version
#   scripts/bump-version.sh --check   exit 1 if any manifest or the crate disagrees with VERSION

set -euo pipefail
cd "$(dirname "$0")/.."

MANIFESTS=".claude-plugin/plugin.json .claude-plugin/marketplace.json .codex-plugin/plugin.json"
CRATE_TOML="tools/agent-router/Cargo.toml"
CRATE_LOCK="tools/agent-router/Cargo.lock"

# The version line of [package] in Cargo.toml, and the line after the crate's
# name in Cargo.lock. No `$` anchors, so CRLF checkouts on Windows still match.
TOML_RANGE='/^\[package\]/,/^\[/'
LOCK_ENTRY='/^name = "agent-router"/'

if [ "${1:-}" = "--check" ]; then
  want="$(tr -d '[:space:]' < VERSION)"; bad=0
  for f in $MANIFESTS; do
    for got in $(sed -n 's/.*"version": *"\([^"]*\)".*/\1/p' "$f"); do
      [ "$got" = "$want" ] || { echo "$f: version $got, VERSION says $want"; bad=1; }
    done
  done
  got="$(sed -n "$TOML_RANGE"'s/^version = "\([^"]*\)".*/\1/p' "$CRATE_TOML")"
  [ "$got" = "$want" ] || { echo "$CRATE_TOML: version ${got:-missing}, VERSION says $want"; bad=1; }
  got="$(sed -n "$LOCK_ENTRY"'{n;s/^version = "\([^"]*\)".*/\1/p;}' "$CRATE_LOCK")"
  [ "$got" = "$want" ] || { echo "$CRATE_LOCK: version ${got:-missing}, VERSION says $want"; bad=1; }
  [ "$bad" = 0 ] && echo "all manifests and the agent-router crate at $want"
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
sed -i.bak "$TOML_RANGE"'s/^version = "[^"]*"/version = "'"$new"'"/' "$CRATE_TOML" && rm -f "$CRATE_TOML.bak"
sed -i.bak "$LOCK_ENTRY"'{n;s/^version = "[^"]*"/version = "'"$new"'"/;}' "$CRATE_LOCK" && rm -f "$CRATE_LOCK.bak"
echo "version set to $new in VERSION, $CRATE_TOML, $CRATE_LOCK and: $MANIFESTS"
