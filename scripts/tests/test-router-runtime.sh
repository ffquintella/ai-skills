#!/usr/bin/env bash
# Isolated runtime contract, with a fake Cargo that copies a real native CLI.
set -euo pipefail
repo="$(cd "$(dirname "$0")/../.." && pwd)"
native_binary="${1:?pass the built native agent-router executable}"
case "$(uname -s)" in MINGW*|MSYS*) native_binary="$(cygpath -u "$native_binary")" ;; esac
[ -f "$native_binary" ] || { echo 'native fixture binary missing' >&2; exit 1; }
test_root="$(mktemp -d "${TMPDIR:-/tmp}/router-runtime-test.XXXXXX")"
# The trap only removes files below the exact unique directory just created.
cleanup() {
  case "$test_root" in "${TMPDIR:-/tmp}"/router-runtime-test.*)
    [ -d "$test_root" ] && rm -rf -- "$test_root" ;;
  esac
}
trap cleanup EXIT
source_root="$test_root/plugin with spaces"
runtime="$test_root/runtime with spaces"
mkdir -p "$source_root/tools/agent-router" "$source_root/scripts" "$test_root/fakebin"
cp -R "$repo/tools/agent-router/src" "$source_root/tools/agent-router/"
for file in Cargo.toml Cargo.lock models.yaml README.md SCHEMA.md; do
  cp "$repo/tools/agent-router/$file" "$source_root/tools/agent-router/"
done
cp "$repo/scripts/router-runtime.sh" "$source_root/scripts/"
export ROUTER_FIXTURE_BINARY="$native_binary"
export ROUTER_TEST_CALLS="$test_root/cargo.calls"
export ROUTER_TEST_FAIL="$test_root/cargo.fail"
cat > "$test_root/fakebin/cargo" <<'CARGO'
#!/usr/bin/env bash
set -eu
printf 'build\n' >> "$ROUTER_TEST_CALLS"
[ ! -f "$ROUTER_TEST_FAIL" ] || { echo 'fixture compile failed' >&2; exit 1; }
target_dir=''; target=''
while [ $# -gt 0 ]; do
  case "$1" in --target-dir) shift; target_dir="$1" ;; --target) shift; target="$1" ;; esac
  shift
done
[ -n "$target_dir" ] && [ -n "$target" ]
case "$(uname -s)" in MINGW*|MSYS*) target_dir="$(cygpath -u "$target_dir")"; suffix='.exe' ;; *) suffix='' ;; esac
mkdir -p "$target_dir/$target/release"
cp "$ROUTER_FIXTURE_BINARY" "$target_dir/$target/release/agent-router$suffix"
chmod +x "$target_dir/$target/release/agent-router$suffix"
CARGO
chmod +x "$test_root/fakebin/cargo"
export PATH="$test_root/fakebin:$PATH"
helper="$source_root/scripts/router-runtime.sh"
run_helper() { bash "$helper" --root "$source_root" --runtime-dir "$runtime" "$@"; }
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }

# A listing must not initialize directories or touch the compiler.
status="$(run_helper --status)"
[ "$status" = 'missing' ] || fail 'initial status should be missing'
[ ! -d "$runtime" ] && [ ! -f "$ROUTER_TEST_CALLS" ] || fail 'status mutated state'
binary="$(run_helper --ensure)"
[ -f "$binary" ] && [ -f "$runtime/models.yaml" ] || fail 'ensure did not install binary/policy'
[ "$(wc -l < "$ROUTER_TEST_CALLS" | tr -d ' ')" = 1 ] || fail 'first ensure must compile once'
[ "$(run_helper --status)" = installed ] || fail 'status should now be installed'
[ "$(run_helper --ensure)" = "$binary" ] || fail 'warm ensure path changed'
[ "$(wc -l < "$ROUTER_TEST_CALLS" | tr -d ' ')" = 1 ] || fail 'warm ensure rebuilt'
run_helper -- --provider openai --task lookup --weekly-remaining 8 > "$test_root/decision.json"
grep -q '"mode":"extreme"' "$test_root/decision.json" || fail 'launcher did not forward args or emitted non-JSON'

# Custom matrices survive default updates, and YAML changes do not rebuild Rust.
printf '\n# my custom policy\n' >> "$runtime/models.yaml"
printf '\n# new distributed policy\n' >> "$source_root/tools/agent-router/models.yaml"
run_helper --ensure >/dev/null
grep -q 'my custom policy' "$runtime/models.yaml" || fail 'custom policy was overwritten'
grep -q 'new distributed policy' "$runtime/models.yaml.dist" || fail 'new defaults missing'
[ "$(wc -l < "$ROUTER_TEST_CALLS" | tr -d ' ')" = 1 ] || fail 'YAML-only change rebuilt binary'

# Source changes require rebuild; a compiler failure must preserve installed data.
printf '\n// fixture changed\n' >> "$source_root/tools/agent-router/src/main.rs"
[ "$(run_helper --status)" = outdated ] || fail 'source fingerprint did not invalidate runtime'
cksum < "$binary" > "$test_root/binary.before"
touch "$ROUTER_TEST_FAIL"
if run_helper --ensure > "$test_root/fail.stdout" 2> "$test_root/fail.stderr"; then fail 'compile failure succeeded'; fi
cksum < "$binary" > "$test_root/binary.after"
cmp "$test_root/binary.before" "$test_root/binary.after" || fail 'failed build replaced existing binary'
grep -q 'my custom policy' "$runtime/models.yaml" || fail 'failed build altered policy'
rm "$ROUTER_TEST_FAIL"
run_helper --ensure >/dev/null
[ "$(run_helper --status)" = installed ] || fail 'source rebuild not installed'

# Explicit native prebuilt must work without invoking Cargo.
prebuilt_runtime="$test_root/prebuilt runtime"
AI_SKILLS_ROUTER_BINARY="$native_binary" bash "$helper" --root "$source_root" --runtime-dir "$prebuilt_runtime" --ensure >/dev/null
[ -f "$prebuilt_runtime/models.yaml" ] || fail 'prebuilt policy missing'
printf '\n# refreshed default\n' >> "$source_root/tools/agent-router/models.yaml"
bash "$helper" --root "$source_root" --runtime-dir "$prebuilt_runtime" --ensure >/dev/null
grep -q 'refreshed default' "$prebuilt_runtime/models.yaml" || fail 'managed policy not refreshed'

# A missing compiler is actionable, not a silently successful partial install.
if CARGO="$test_root/does-not-exist" bash "$helper" --root "$source_root" --runtime-dir "$test_root/no compiler runtime" --ensure > "$test_root/no-cargo.stdout" 2> "$test_root/no-cargo.stderr"; then
  fail 'missing Cargo was silently ignored'
fi
grep -q 'Cargo is required' "$test_root/no-cargo.stderr" || fail 'missing Cargo message not actionable'
[ ! -d "$test_root/no compiler runtime/.prepare-lock" ] || fail 'failed prepare left its lock'

# A damaged distribution must fail before changing installed runtime metadata.
before_id="$(cat "$runtime/.source-id")"
cp "$source_root/tools/agent-router/models.yaml" "$test_root/policy.saved"
rm "$source_root/tools/agent-router/models.yaml"
printf '\n// another source change\n' >> "$source_root/tools/agent-router/src/main.rs"
if run_helper --ensure >/dev/null 2> "$test_root/no-policy.stderr"; then fail 'missing distribution policy succeeded'; fi
[ "$(cat "$runtime/.source-id")" = "$before_id" ] || fail 'missing distribution policy changed installed source metadata'
cp "$test_root/policy.saved" "$source_root/tools/agent-router/models.yaml"

# Both callers of a concurrent preparation must receive a valid installed path.
run_helper --ensure > "$test_root/concurrent-one" & first=$!
run_helper --ensure > "$test_root/concurrent-two" & second=$!
wait "$first"; wait "$second"
cmp "$test_root/concurrent-one" "$test_root/concurrent-two" || fail 'concurrent preparations disagreed'
printf 'PASS: read-only status, first build, reuse, JSON forwarding, custom/default YAML, stale source, compile-failure preservation and prebuilt reuse.\n'
