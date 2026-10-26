#!/usr/bin/env bash
# No live registrations: all vendor commands run against fixture CLIs and HOME.
set -euo pipefail
repo="$(cd "$(dirname "$0")/../.." && pwd)"
fixture_binary="${1:?pass the built native agent-router executable}"
case "$(uname -s)" in MINGW*|MSYS*) fixture_binary="$(cygpath -u "$fixture_binary")" ;; esac
case "$fixture_binary" in /*) ;; *) fixture_binary="$PWD/$fixture_binary" ;; esac
test_root="$(mktemp -d "${TMPDIR:-/tmp}/router-install-test.XXXXXX")"
cleanup() {
  case "$test_root" in "${TMPDIR:-/tmp}"/router-install-test.*)
    [ -d "$test_root" ] && rm -rf -- "$test_root" ;;
  esac
}
trap cleanup EXIT
mkdir -p "$test_root/bin" "$test_root/home/.codex" "$test_root/home/.claude" "$test_root/project with spaces/subfolder" "$test_root/skip project"
for vendor in claude codex; do
  cat > "$test_root/bin/$vendor" <<'CLI'
#!/usr/bin/env bash
printf '%s %s\n' "$(basename "$0")" "$*" >> "$AI_SKILLS_TEST_CLI_LOG"
# Answer install.sh's capability probes the way a current Claude Code CLI does.
case "$*" in
  'plugin list --json'|'plugin marketplace list --json') printf '[]\n' ;;
  'plugin marketplace add --help') printf '  --scope <scope>\n' ;;
  'plugin install --help') printf '  --marketplace <name>\n' ;;
esac
exit 0
CLI
  chmod +x "$test_root/bin/$vendor"
done
export AI_SKILLS_TEST_CLI_LOG="$test_root/cli.log"
export AI_SKILLS_ROUTER_BINARY="$fixture_binary"
export PATH="$test_root/bin:$PATH"
export XDG_DATA_HOME="$test_root/user data"
unset AI_SKILLS_ROUTER_HOME
# The user runtime follows each host's convention, kept inside the fixture HOME.
user_runtime="$XDG_DATA_HOME/ai-skills/agent-router"
case "$(uname -s)" in
  MINGW*|MSYS*) export LOCALAPPDATA="$XDG_DATA_HOME" ;;
  Darwin) user_runtime="$test_root/home/Library/Application Support/ai-skills/agent-router" ;;
esac
installer() {
  HOME="$test_root/home" CODEX_HOME="$test_root/home/.codex" CLAUDE_CONFIG_DIR="$test_root/home/.claude" \
    bash "$repo/install.sh" "$@"
}
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
installer --help > "$test_root/help"
installer --list --project "$test_root/project with spaces" --no-external > "$test_root/list"
grep -q 'agent-router runtime: missing' "$test_root/list" || fail 'list omitted runtime status'
[ ! -d "$test_root/project with spaces/.ai-skills" ] || fail 'list wrote runtime'
installer --all --skills --project "$test_root/skip project" --no-external --no-router > "$test_root/skipped"
[ ! -d "$test_root/skip project/.ai-skills/agent-router" ] || fail 'opt-out was ignored'
installer --all --skills --project "$test_root/project with spaces" --no-external > "$test_root/installed"
runtime="$test_root/project with spaces/.ai-skills/agent-router"
[ -f "$runtime/models.yaml" ] || fail 'runtime policy not installed'
for vendor_dir in .claude .agents; do
  HOME="$test_root/home" bash "$test_root/project with spaces/$vendor_dir/skills/agent-router/scripts/agent-router" \
    --provider openai --task lookup --weekly-remaining 8 > "$test_root/decision"
  grep -q '"mode":"extreme"' "$test_root/decision" || fail 'copied skill launcher failed'
done
printf '\n# my local matrix\n' >> "$runtime/models.yaml"
before="$(cksum < "$runtime/models.yaml")"
installer --all --skills --update --project "$test_root/project with spaces" --no-external > "$test_root/updated"
[ "$(cksum < "$runtime/models.yaml")" = "$before" ] || fail 'custom matrix overwritten'
[ -f "$runtime/models.yaml.dist" ] || fail 'updated default not offered'
# A plugin loaded globally must pick the project runtime from a nested cwd.
(
  cd "$test_root/project with spaces/subfolder"
  HOME="$test_root/home" bash "$repo/scripts/agent-router" -- --provider openai --task lookup --weekly-remaining 8 > "$test_root/plugin-decision"
)
grep -q '"mode":"extreme"' "$test_root/plugin-decision" || fail 'plugin launcher did not use project runtime'
[ ! -d "$user_runtime" ] || fail 'project plugin call wrote user runtime'
installer --all --skills --user --no-external > "$test_root/user-installed"
[ -f "$user_runtime/models.yaml" ] || fail 'user runtime not installed'
for vendor_dir in .claude .agents; do
  HOME="$test_root/home" bash "$test_root/home/$vendor_dir/skills/agent-router/scripts/agent-router" --version > "$test_root/version"
  grep -q '^agent-router ' "$test_root/version" || fail 'user skill launcher failed'
done
AI_SKILLS_ROUTER_HOME="$test_root/plugin override" installer --all --plugin --no-external > "$test_root/plugins"
[ "$(grep -c 'Preparing agent-router runtime at' "$test_root/plugins")" = 1 ] || fail 'plugin prepared runtime multiple times'
[ -f "$test_root/plugin override/models.yaml" ] || fail 'plugin override missing'
grep -q 'codex plugin add ai-skills@ai-skills' "$AI_SKILLS_TEST_CLI_LOG" || fail 'fixture Codex plugin command missing'
grep -q 'claude plugin install ai-skills@ai-skills' "$AI_SKILLS_TEST_CLI_LOG" || fail 'fixture Claude plugin command missing'
printf 'PASS: read-only listing, opt-out, project/user installs, both copied launchers, custom matrix, plugin launcher and fixture plugin installation.\n'
