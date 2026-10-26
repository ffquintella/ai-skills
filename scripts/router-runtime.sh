#!/usr/bin/env bash
# Shared native runtime for the installer and plugin launchers. Bash 3.2 compatible.
# stdout is reserved for --ensure's path, --status, or the native CLI's output.
set -euo pipefail

runtime_root="$(cd "$(dirname "$0")/.." && pwd)"
runtime_user_data="${XDG_DATA_HOME:-}"
case "$(uname -s)" in
  MINGW*|MSYS*)
    runtime_user_data="${LOCALAPPDATA:-${APPDATA:-}}"
    if [ -z "$runtime_user_data" ] && command -v cygpath >/dev/null 2>&1; then
      runtime_user_data="$(cygpath -F 28 2>/dev/null || true)"
      [ -n "$runtime_user_data" ] || runtime_user_data="$(cygpath -F 26 2>/dev/null || true)"
    fi ;;
  Darwin) runtime_user_data="${HOME}/Library/Application Support" ;;
esac
if [ -z "$runtime_user_data" ]; then runtime_user_data="${XDG_DATA_HOME:-$HOME/.local/share}"; fi
runtime_dir="${AI_SKILLS_ROUTER_HOME:-$runtime_user_data/ai-skills/agent-router}"
runtime_action=run
while [ $# -gt 0 ]; do
  case "$1" in
    --root|--runtime-dir)
      option="$1"; shift
      [ $# -gt 0 ] && [ -n "$1" ] || { printf 'agent-router: %s needs a path\n' "$option" >&2; exit 1; }
      if [ "$option" = --root ]; then runtime_root="$1"; else runtime_dir="$1"; fi ;;
    --ensure) runtime_action=ensure ;;
    --status) runtime_action=status ;;
    --) shift; break ;;
    *) break ;;
  esac
  shift
done

runtime_fail() { printf 'agent-router: %s\n' "$*" >&2; exit 1; }
runtime_log() { printf 'agent-router: %s\n' "$*" >&2; }
runtime_os="$(uname -s)"
runtime_arch="$(uname -m)"
runtime_suffix=''
case "$runtime_os" in
  MINGW*|MSYS*)
    runtime_root="$(cygpath -u "$runtime_root")"
    runtime_dir="$(cygpath -u "$runtime_dir")"
    runtime_suffix=.exe
    case "${PROCESSOR_ARCHITEW6432:-${PROCESSOR_ARCHITECTURE:-}}" in ARM64|arm64) runtime_arch=arm64 ;; esac
    case "$runtime_arch" in
      x86_64|amd64) runtime_target=x86_64-pc-windows-msvc ;;
      aarch64|arm64) runtime_target=aarch64-pc-windows-msvc ;;
      *) runtime_fail "unsupported Windows architecture: $runtime_arch" ;;
    esac ;;
  Linux)
    case "$runtime_arch" in
      x86_64|amd64) runtime_target=x86_64-unknown-linux-gnu ;;
      aarch64|arm64) runtime_target=aarch64-unknown-linux-gnu ;;
      *) runtime_fail "unsupported Linux architecture: $runtime_arch" ;;
    esac ;;
  Darwin)
    case "$runtime_arch" in
      x86_64|amd64) runtime_target=x86_64-apple-darwin ;;
      aarch64|arm64) runtime_target=aarch64-apple-darwin ;;
      *) runtime_fail "unsupported macOS architecture: $runtime_arch" ;;
    esac ;;
  *) runtime_fail "unsupported operating system: $runtime_os" ;;
esac
runtime_root="$(cd "$runtime_root" && pwd -P)"
case "$runtime_dir" in /*) ;; *) runtime_dir="$PWD/$runtime_dir" ;; esac
case "$runtime_dir" in /|*/..|*/.|'') runtime_fail 'choose a dedicated runtime directory' ;; esac
runtime_crate="$runtime_root/tools/agent-router"
runtime_binary="$runtime_dir/agent-router$runtime_suffix"
[ -f "$runtime_crate/Cargo.toml" ] && [ -f "$runtime_crate/Cargo.lock" ] && [ -d "$runtime_crate/src" ] \
  || runtime_fail 'plugin sources missing; reinstall the complete ai-skills plugin or run its installer'
runtime_version="$(sed -n 's/^version = "\([^"]*\)"/\1/p' "$runtime_crate/Cargo.toml" | head -n 1)"
[ -n "$runtime_version" ] || runtime_fail 'could not read the router crate version'
runtime_id="$(
  cd "$runtime_crate"
  { printf '%s\n' "$runtime_target"; cksum Cargo.toml Cargo.lock
    find src -type f -name '*.rs' | LC_ALL=C sort | while IFS= read -r file; do cksum "$file"; done
  } | cksum | awk '{print $1 "-" $2}'
)"

runtime_compatible() {
  [ -f "$1" ] && [ "$("$1" --version 2>/dev/null || true)" = "agent-router $runtime_version" ]
}
runtime_current() {
  [ -f "$runtime_dir/.source-id" ] && [ "$(cat "$runtime_dir/.source-id")" = "$runtime_id" ] \
    && runtime_compatible "$runtime_binary"
}
runtime_status() {
  if [ ! -f "$runtime_binary" ]; then printf 'missing\n'
  elif runtime_current && [ -f "$runtime_dir/models.yaml" ]; then printf 'installed\n'
  else printf 'outdated\n'; fi
}
if [ "$runtime_action" = status ]; then runtime_status; exit 0; fi
[ -f "$runtime_crate/models.yaml" ] || runtime_fail 'distribution models.yaml is missing'

# Serialize builds and policy refreshes. No work is written inside the plugin tree.
mkdir -p "$runtime_dir"
runtime_dir="$(cd "$runtime_dir" && pwd -P)"
runtime_binary="$runtime_dir/agent-router$runtime_suffix"
runtime_lock="$runtime_dir/.prepare-lock"
runtime_attempt=0
until mkdir "$runtime_lock" 2>/dev/null; do
  runtime_attempt=$((runtime_attempt + 1))
  [ "$runtime_attempt" -lt 120 ] || runtime_fail "runtime busy; retry later (lock: $runtime_lock)"
  sleep 1
done
runtime_stage=''
runtime_cleanup() {
  if [ -n "$runtime_stage" ]; then
    case "$runtime_stage" in "$runtime_dir"/.agent-router.*) rm -f -- "$runtime_stage" ;; esac
  fi
  rmdir "$runtime_lock" 2>/dev/null || true
}
trap runtime_cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

runtime_recent() {
  runtime_compatible "$1" || return 1
  [ ! "$runtime_crate/Cargo.toml" -nt "$1" ] && [ ! "$runtime_crate/Cargo.lock" -nt "$1" ] || return 1
  while IFS= read -r file; do [ ! "$file" -nt "$1" ] || return 1; done < <(find "$runtime_crate/src" -type f -name '*.rs')
}

if ! runtime_current; then
  runtime_candidate=''
  if [ -n "${AI_SKILLS_ROUTER_BINARY:-}" ]; then
    runtime_candidate="$AI_SKILLS_ROUTER_BINARY"
    case "$runtime_os" in MINGW*|MSYS*) runtime_candidate="$(cygpath -u "$runtime_candidate")" ;; esac
    runtime_compatible "$runtime_candidate" || runtime_fail 'AI_SKILLS_ROUTER_BINARY is incompatible or has the wrong version'
  else
    for candidate in "$runtime_crate/prebuilt/$runtime_target/agent-router$runtime_suffix" \
      "$runtime_crate/target/$runtime_target/release/agent-router$runtime_suffix" \
      "$runtime_crate/target/release/agent-router$runtime_suffix"; do
      if runtime_recent "$candidate"; then runtime_candidate="$candidate"; break; fi
    done
  fi
  if [ -z "$runtime_candidate" ]; then
    runtime_cargo="${CARGO:-cargo}"
    command -v "$runtime_cargo" >/dev/null 2>&1 || runtime_fail 'Cargo is required to compile agent-router; install Rust 1.89+ (and platform build tools), provide AI_SKILLS_ROUTER_BINARY, or use --no-router with install.sh'
    runtime_log "compiling $runtime_target (first install or source change)"
    if ! "$runtime_cargo" build --locked --release --manifest-path "$runtime_crate/Cargo.toml" \
      --target "$runtime_target" --target-dir "$runtime_dir/build" >&2; then
      runtime_fail "compilation failed; existing runtime preserved. Check Rust 1.89+, native build tools and target $runtime_target."
    fi
    runtime_candidate="$runtime_dir/build/$runtime_target/release/agent-router$runtime_suffix"
    runtime_compatible "$runtime_candidate" || runtime_fail 'compiler did not produce a compatible agent-router binary'
  else runtime_log "using compatible native binary for $runtime_target"; fi
  runtime_stage="$(mktemp "$runtime_dir/.agent-router.XXXXXX")"
  cp "$runtime_candidate" "$runtime_stage"
  chmod +x "$runtime_stage"
  mv -f "$runtime_stage" "$runtime_binary"
  runtime_stage=''
  printf '%s\n' "$runtime_id" > "$runtime_dir/.source-id"
fi

runtime_policy="$runtime_dir/models.yaml"
[ -f "$runtime_crate/models.yaml" ] || runtime_fail 'distribution models.yaml is missing'
runtime_default_id="$(cksum < "$runtime_crate/models.yaml")"
runtime_policy_id=''
[ ! -f "$runtime_policy" ] || runtime_policy_id="$(cksum < "$runtime_policy")"
runtime_managed_id=''
[ ! -f "$runtime_dir/.models-managed-id" ] || runtime_managed_id="$(cat "$runtime_dir/.models-managed-id")"
if [ ! -f "$runtime_policy" ] || [ "$runtime_policy_id" = "$runtime_managed_id" ] || [ "$runtime_policy_id" = "$runtime_default_id" ]; then
  cp "$runtime_crate/models.yaml" "$runtime_policy"
  printf '%s\n' "$runtime_default_id" > "$runtime_dir/.models-managed-id"
else
  cp "$runtime_crate/models.yaml" "$runtime_dir/models.yaml.dist"
  runtime_log "custom models.yaml preserved; new defaults: $runtime_dir/models.yaml.dist"
fi
for document in README.md SCHEMA.md; do
  [ ! -f "$runtime_crate/$document" ] || cp "$runtime_crate/$document" "$runtime_dir/$document"
done

# Release the lock before running the user's CLI request.
runtime_cleanup
trap - EXIT INT TERM
if [ "$runtime_action" = ensure ]; then printf '%s\n' "$runtime_binary"; exit 0; fi
exec "$runtime_binary" "$@"
