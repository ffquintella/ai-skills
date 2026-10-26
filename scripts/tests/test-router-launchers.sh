#!/usr/bin/env bash
# Different model IDs prove which scope a copied launcher actually consumed.
set -euo pipefail
repo="$(cd "$(dirname "$0")/../.." && pwd)"
native_binary="${1:?pass the built native agent-router executable}"
suffix=''
case "$(uname -s)" in MINGW*|MSYS*) native_binary="$(cygpath -u "$native_binary")"; suffix=.exe ;; esac
case "$native_binary" in /*) ;; *) native_binary="$PWD/$native_binary" ;; esac
test_root="$(mktemp -d "${TMPDIR:-/tmp}/router-launcher-test.XXXXXX")"
cleanup() {
  case "$test_root" in "${TMPDIR:-/tmp}"/router-launcher-test.*)
    [ -d "$test_root" ] && rm -rf -- "$test_root" ;;
  esac
}
trap cleanup EXIT
project="$test_root/project with spaces"
fixture_home="$test_root/home"
# The user fallback follows each host's convention; LOCALAPPDATA is passed below.
user_runtime="$test_root/user data/ai-skills/agent-router"
case "$(uname -s)" in Darwin) user_runtime="$fixture_home/Library/Application Support/ai-skills/agent-router" ;; esac
project_runtime="$project/.ai-skills/agent-router"
mkdir -p "$project/child" "$user_runtime" "$project_runtime"
for runtime in "$user_runtime" "$project_runtime"; do
  cp "$native_binary" "$runtime/agent-router$suffix"
  chmod +x "$runtime/agent-router$suffix"
done
sed 's/gpt-6-luna/user-cheap/g' "$repo/tools/agent-router/models.yaml" > "$user_runtime/models.yaml"
sed 's/gpt-6-luna/project-cheap/g' "$repo/tools/agent-router/models.yaml" > "$project_runtime/models.yaml"
unset AI_SKILLS_ROUTER_HOME
for vendor in openai claude; do
  case "$vendor" in openai) skills_dir=.agents ;; claude) skills_dir=.claude ;; esac
  launcher="$fixture_home/$skills_dir/skills/agent-router/scripts/agent-router"
  mkdir -p "$(dirname "$launcher")"
  cp "$repo/$vendor/agent-router/scripts/agent-router" "$launcher"
  (
    cd "$project/child"
    HOME="$fixture_home" XDG_DATA_HOME="$test_root/user data" LOCALAPPDATA="$test_root/user data" bash "$launcher" --provider openai --task lookup > "$test_root/decision"
  )
  grep -q '"model":"project-cheap"' "$test_root/decision" || { echo "FAIL: $vendor user-scope launcher ignored project matrix" >&2; exit 1; }
  (
    cd "$project/child"
    HOME="$fixture_home" XDG_DATA_HOME="$test_root/user data" LOCALAPPDATA="$test_root/user data" AI_SKILLS_ROUTER_HOME="$user_runtime" bash "$launcher" --provider openai --task lookup > "$test_root/decision"
  )
  grep -q '"model":"user-cheap"' "$test_root/decision" || { echo "FAIL: $vendor override not respected" >&2; exit 1; }
  (
    cd "$test_root"
    HOME="$fixture_home" XDG_DATA_HOME="$test_root/user data" LOCALAPPDATA="$test_root/user data" bash "$launcher" --provider openai --task lookup > "$test_root/decision"
  )
  grep -q '"model":"user-cheap"' "$test_root/decision" || { echo "FAIL: $vendor user fallback failed" >&2; exit 1; }
done
printf 'PASS: both copied user launchers honor current-project matrix, explicit override and user fallback.\n'
