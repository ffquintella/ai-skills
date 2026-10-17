#!/usr/bin/env bash
# Installs or updates the skills in this repository into Claude Code and/or
# OpenAI Codex. Interactive by default; flags allow non-interactive use.
#
#   ./install.sh                  interactive: pick vendor, scope, skills
#   ./install.sh --all            install every skill for every detected vendor
#   ./install.sh --update         re-copy already-installed skills (overwrite)
#   ./install.sh --vendor claude  limit to one vendor (claude | openai)
#   ./install.sh --project DIR    install into DIR/.claude/skills and DIR/.agents/skills
#   ./install.sh --user           install into ~/.claude/skills and ~/.agents/skills (default)
#   ./install.sh --agents         also copy agent templates (assets/agents) when present
#   ./install.sh --list           show skills and their install status, then exit
#   ./install.sh --no-external    skip third-party software: the graphify CLI
#                                 and the Cortex plugin / MCP server
#   ./install.sh --no-router      skip preparing the bundled agent-router runtime
#   ./install.sh --plugin         install the ai-skills plugin (all skills plus the
#                                 session-start bootstrap) instead of copying skills
#   ./install.sh --skills         copy individual skills (default without a terminal)
#
# Works with macOS bash 3.2 (no associative arrays, no mapfile).

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENDORS="claude openai"

# Git Bash uses POSIX paths internally; native CLIs and persisted MCP commands
# need Windows paths. Keep Unix behavior unchanged.
IS_WINDOWS="no"
case "$(uname -s)" in MINGW*|MSYS*) IS_WINDOWS="yes" ;; esac
native_path() {
  if [ "$IS_WINDOWS" = "yes" ]; then cygpath -am "$1"; else printf '%s\n' "$1"; fi
}
# Normalize Windows paths supplied by the PowerShell launcher (including spaces).
shell_path() {
  if [ "$IS_WINDOWS" = "yes" ]; then cygpath -u "$1"; else printf '%s\n' "$1"; fi
}
uv_install_hint() {
  if [ "$IS_WINDOWS" = "yes" ]; then
    warn '  In PowerShell: winget install --id astral-sh.uv -e'
    warn '  Restart your terminal, then rerun the installer.'
  else
    warn '  curl -LsSf https://astral.sh/uv/install.sh | sh'
  fi
}

# External skills are generated and versioned by a third-party CLI, so the repo
# does not keep a copy: the installer installs the CLI and lets it write the
# skill. See external_* below.
EXTERNAL_SKILLS="graphify"
GRAPHIFY_PACKAGE="graphifyy"   # PyPI name (double y); the command is `graphify`
GRAPHIFY_CLI_UPDATED="no"

# Skills whose runtime needs Python 3.10+: the Cortex MCP server behind
# cortex-memory and the graphify CLI.
PYTHON310_SKILLS="cortex-memory graphify"
PYTHON_CHECKED="no"

MODE="install"          # install | update
SCOPE="user"            # user | project
PROJECT_DIR=""
VENDOR_FILTER=""
SELECT_ALL="no"
COPY_AGENTS="ask"       # ask | yes | no
LIST_ONLY="no"
WITH_EXTERNAL="yes"
WITH_ROUTER="yes"
ROUTER_PREPARED="no"
NONINTERACTIVE="no"
METHOD="ask"            # ask | plugin | skills

# The repository is also a plugin for both hosts: .claude-plugin/ serves claude/
# plus hooks/ (SessionStart injects using-ai-skills), .codex-plugin/ serves
# openai/. Both marketplaces are named like the plugin.
PLUGIN_ID="ai-skills@ai-skills"
PLUGIN_MARKETPLACE="ai-skills"

# ---------------------------------------------------------------- helpers ---
say()  { printf '%s\n' "$*"; }
info() { printf '  \033[36m%s\033[0m\n' "$*"; }
ok()   { printf '  \033[32m%s\033[0m\n' "$*"; }
warn() { printf '  \033[33m%s\033[0m\n' "$*"; }
err()  { printf '\033[31m%s\033[0m\n' "$*" >&2; }
die()  { err "$*"; exit 1; }

usage() { sed -n '2,/^$/p' "$0" | sed 's/^# \{0,1\}//'; exit 0; }

vendor_label() {
  case "$1" in
    claude) echo "Claude Code" ;;
    openai) echo "OpenAI Codex" ;;
  esac
}

# Is the vendor's tool present on this machine? Checks the CLI first, then the
# home directory the tool creates on first run.
vendor_installed() {
  case "$1" in
    claude) command -v claude >/dev/null 2>&1 || [ -d "$HOME/.claude" ] ;;
    openai) command -v codex  >/dev/null 2>&1 || [ -d "$HOME/.codex" ] ;;
    *) return 1 ;;
  esac
}

vendor_detail() {
  case "$1" in
    claude)
      if command -v claude >/dev/null 2>&1; then echo "cli: $(command -v claude)"; else echo "cli not on PATH, ~/.claude present"; fi ;;
    openai)
      if command -v codex >/dev/null 2>&1; then echo "cli: $(command -v codex)"; else echo "cli not on PATH, ~/.codex present"; fi ;;
  esac
}

# Where skills go for a vendor, given the scope.
skills_root() {
  local vendor="$1" base
  if [ "$SCOPE" = "project" ]; then base="$PROJECT_DIR"; else base="$HOME"; fi
  case "$vendor" in
    claude) echo "$base/.claude/skills" ;;
    openai) echo "$base/.agents/skills" ;;
  esac
}

# Where agent templates go for a vendor, given the scope.
agents_root() {
  local vendor="$1" base
  if [ "$SCOPE" = "project" ]; then base="$PROJECT_DIR"; else base="$HOME"; fi
  case "$vendor" in
    claude) echo "$base/.claude/agents" ;;
    openai) echo "$base/.codex/agents" ;;
  esac
}

# Keep mutable runtime/policy outside copied skills and plugin caches. An explicit
# override wins over both project and user defaults.
router_runtime_dir() {
  if [ -n "${AI_SKILLS_ROUTER_HOME:-}" ]; then
    shell_path "$AI_SKILLS_ROUTER_HOME"
  elif [ "$SCOPE" = "project" ]; then
    printf '%s\n' "$PROJECT_DIR/.ai-skills/agent-router"
  else
    shell_path "${XDG_DATA_HOME:-$HOME/.local/share}/ai-skills/agent-router"
  fi
}

ensure_agent_router() {
  local dest binary
  [ "$ROUTER_PREPARED" = "no" ] || return 0
  ROUTER_PREPARED="yes"
  if [ "$WITH_ROUTER" = "no" ]; then
    info "--no-router given, skipping the agent-router runtime"
    return 0
  fi
  dest="$(router_runtime_dir)"
  info "Preparing agent-router runtime at $dest"
  binary="$(bash "$REPO_DIR/scripts/router-runtime.sh" --root "$REPO_DIR" --runtime-dir "$dest" --ensure)" \
    || die "agent-router runtime preparation failed; see the diagnostic above (or use --no-router to skip)."
  ok "agent-router runtime: $binary"
}

# Skills available in the repo for a vendor (directory names), then the
# external ones.
repo_skills() {
  local vendor="$1" d
  if [ -d "$REPO_DIR/$vendor" ]; then
    for d in "$REPO_DIR/$vendor"/*/; do
      [ -f "${d}SKILL.md" ] && basename "$d"
    done
  fi
  if [ "$WITH_EXTERNAL" = "yes" ]; then
    for d in $EXTERNAL_SKILLS; do echo "$d"; done
  fi
  return 0
}

is_external() {
  case " $EXTERNAL_SKILLS " in *" $1 "*) return 0 ;; *) return 1 ;; esac
}

needs_python310() {
  case " $PYTHON310_SKILLS " in *" $1 "*) return 0 ;; *) return 1 ;; esac
}

py_version() {
  "$1" -c 'import sys; print("%d.%d" % sys.version_info[:2])' 2>/dev/null || true
}

py_is_310() {
  "$1" -c 'import sys; sys.exit(0 if sys.version_info >= (3, 10) else 1)' 2>/dev/null
}

# Newest Python 3.10+ on PATH, as a path: python3 first, then versioned
# binaries such as Homebrew's python3.14, which do not replace python3.
find_python310() {
  local cand
  if [ "$IS_WINDOWS" = "yes" ] && command -v python >/dev/null 2>&1 && py_is_310 python; then
    command -v python; return 0
  fi
  if command -v python3 >/dev/null 2>&1 && py_is_310 python3; then
    command -v python3; return 0
  fi
  for cand in $(compgen -c python3. | grep -E '^python3\.[0-9]+$' | sort -t. -k2,2nr -u); do
    if py_is_310 "$cand"; then command -v "$cand"; return 0; fi
  done
  return 1
}

# Report once per run which interpreter cortex-memory and graphify will get.
# The Cortex plugin starts from python3 and, below 3.10, provisions its own
# 3.12 (with uv, or a pinned uv it installs through pip). graphify goes through
# uv or pipx; pipx needs a 3.10+ interpreter, taken from PYTHON310.
PYTHON310=""
check_python310() {
  local base=""
  [ "$PYTHON_CHECKED" = "no" ] || return 0
  PYTHON_CHECKED="yes"
  command -v python3 >/dev/null 2>&1 && base="$(py_version python3)"
  PYTHON310="$(find_python310 || true)"
  if [ -n "$PYTHON310" ] && [ "$(command -v python3 2>/dev/null)" = "$PYTHON310" ]; then
    return 0
  fi
  if [ -n "$PYTHON310" ]; then
    info "Python 3.10+ (needed by: $PYTHON310_SKILLS): found $(basename "$PYTHON310") $(py_version "$PYTHON310") at $PYTHON310; python3 on PATH is ${base:-not found}."
    info "  The Cortex plugin starts from python3 and downloads its own 3.12 on first launch; graphify uses uv, or pipx with $(basename "$PYTHON310")."
    return 0
  fi
  warn "Python 3.10+ is required by: $PYTHON310_SKILLS, and none is on PATH (python3: ${base:-not found})."
  if command -v uv >/dev/null 2>&1; then
    warn "  uv is installed and downloads a 3.10+ interpreter for both, so they will work."
  else
    warn "  The Cortex plugin can still provision its own Python on first launch, but graphify needs uv or a 3.10+ python3:"
    uv_install_hint
  fi
  if [ "$IS_WINDOWS" = "yes" ]; then
    warn "  With uv: uv python install 3.12"
  else
    warn "  For a system-wide python3: brew install python@3.12, or uv python install 3.12 --default"
  fi
}

# ------------------------------------------------------- external: graphify ---
# graphify (https://github.com/Graphify-Labs/graphify) ships a 700-line skill
# generated per assistant and stamped with the CLI version in
# .graphify_version. `graphify install` writes it, so the repo only drives that
# command. On Claude it also adds a short registration block to CLAUDE.md.

# Path of the graphify CLI, or empty. uv puts it in ~/.local/bin, which may not
# be on PATH right after `uv tool install`.
graphify_bin() {
  if command -v graphify >/dev/null 2>&1; then command -v graphify
  elif [ "$IS_WINDOWS" = "yes" ] && [ -x "$HOME/.local/bin/graphify.exe" ]; then echo "$HOME/.local/bin/graphify.exe"
  elif [ -x "$HOME/.local/bin/graphify" ]; then echo "$HOME/.local/bin/graphify"
  fi
}

# Any graphify run re-copies user-scope skills whose stamp is older than the
# CLI; the opt-out keeps --list read-only and the status honest.
graphify_cli_version() {
  local bin
  bin="$(graphify_bin)"
  [ -n "$bin" ] || return 0
  GRAPHIFY_NO_AUTO_REFRESH=1 "$bin" --version 2>/dev/null | awk '{print $NF; exit}'
}

# Where `graphify install` puts the skill. Codex uses graphify's codex platform
# (~/.codex/skills), not ~/.agents/skills: that variant carries the
# Codex-specific instructions ($graphify, multi_agent).
graphify_skill_dir() {
  local vendor="$1" base
  if [ "$SCOPE" = "project" ]; then base="$PROJECT_DIR"; else base="$HOME"; fi
  case "$vendor" in
    claude)
      if [ "$SCOPE" = "user" ] && [ -n "${CLAUDE_CONFIG_DIR:-}" ]; then
        echo "$CLAUDE_CONFIG_DIR/skills/graphify"
      else
        echo "$base/.claude/skills/graphify"
      fi ;;
    openai) echo "$base/.codex/skills/graphify" ;;
  esac
}

graphify_platform() {
  case "$1" in claude) echo "claude" ;; openai) echo "codex" ;; esac
}

# Install the CLI when missing; with "upgrade", also upgrade it (once per run)
# using whichever tool installed it.
ensure_graphify_cli() {
  local upgrade="${1:-}"
  if [ -n "$(graphify_bin)" ]; then
    [ "$upgrade" = "upgrade" ] && [ "$GRAPHIFY_CLI_UPDATED" = "no" ] || return 0
    GRAPHIFY_CLI_UPDATED="yes"
    if command -v uv >/dev/null 2>&1 && uv tool list 2>/dev/null | grep -q "^$GRAPHIFY_PACKAGE "; then
      info "graphify: upgrading the CLI (uv tool upgrade $GRAPHIFY_PACKAGE)"
      uv tool upgrade "$GRAPHIFY_PACKAGE" 2>&1 | sed 's/^/    /'
    elif command -v pipx >/dev/null 2>&1 && pipx list --short 2>/dev/null | grep -q "^$GRAPHIFY_PACKAGE "; then
      info "graphify: upgrading the CLI (pipx upgrade $GRAPHIFY_PACKAGE)"
      pipx upgrade "$GRAPHIFY_PACKAGE" 2>&1 | sed 's/^/    /'
    else
      warn "graphify: CLI at $(graphify_bin) was not installed by uv or pipx; upgrade it the way you installed it."
    fi
    return 0
  fi
  GRAPHIFY_CLI_UPDATED="yes"
  if command -v uv >/dev/null 2>&1; then
    info "graphify: installing the CLI (uv tool install $GRAPHIFY_PACKAGE)"
    uv tool install "$GRAPHIFY_PACKAGE" 2>&1 | sed 's/^/    /'
  elif command -v pipx >/dev/null 2>&1; then
    info "graphify: installing the CLI (pipx install $GRAPHIFY_PACKAGE)"
    # pipx's own interpreter may be older than graphify's 3.10 floor.
    pipx install ${PYTHON310:+--python "$PYTHON310"} "$GRAPHIFY_PACKAGE" 2>&1 | sed 's/^/    /'
  else
    warn "graphify: needs uv or pipx to install the CLI (Python 3.10+). Install uv, then rerun:"
    uv_install_hint
    return 1
  fi
  [ -n "$(graphify_bin)" ] || { warn "graphify: CLI installed but not found; run 'uv tool update-shell' and rerun."; return 1; }
}

# installed | outdated | missing. Outdated means the skill's version stamp does
# not match the CLI (or the CLI is gone).
graphify_status() {
  local dir stamp cli
  dir="$(graphify_skill_dir "$1")"
  [ -f "$dir/SKILL.md" ] || { echo "missing"; return; }
  cli="$(graphify_cli_version)"
  stamp="$(cat "$dir/.graphify_version" 2>/dev/null || true)"
  if [ -n "$cli" ] && [ "$cli" = "$stamp" ]; then echo "installed"; else echo "outdated"; fi
}

run_graphify_install() {
  local vendor="$1" bin platform
  bin="$(graphify_bin)"
  platform="$(graphify_platform "$vendor")"
  if [ "$SCOPE" = "project" ]; then
    # graphify has no skill-only project install: --project also writes the
    # always-on block and PreToolUse hooks.
    info "graphify: project install also writes the always-on block ($([ "$vendor" = claude ] && echo 'CLAUDE.md, .claude/settings.json hooks' || echo 'AGENTS.md, .codex/hooks.json')); remove with 'graphify uninstall --project'"
    (cd "$PROJECT_DIR" && "$bin" install --project --platform "$platform") 2>&1 | sed 's/^/    /'
  else
    "$bin" install --platform "$platform" 2>&1 | sed 's/^/    /'
  fi
}

install_graphify() {
  local vendor="$1" status dir
  dir="$(graphify_skill_dir "$vendor")"
  status="$(graphify_status "$vendor")"
  if [ "$MODE" = "install" ]; then
    case "$status" in
      installed) ok "graphify: already up to date at $dir (CLI $(graphify_cli_version))"; return 0 ;;
      outdated)
        warn "graphify: installed at $dir but does not match the CLI version. Run with --update (or choose update) to refresh."
        return 0 ;;
    esac
    ensure_graphify_cli || return 0
  else
    ensure_graphify_cli upgrade || return 0
  fi
  if run_graphify_install "$vendor"; then
    ok "graphify: skill $([ "$status" = "missing" ] && echo installed || echo updated) at $dir (CLI $(graphify_cli_version))"
  else
    warn "graphify: 'graphify install --platform $(graphify_platform "$vendor")' failed; see the output above."
  fi
}

# ------------------------------------------------- runtime: cortex-memory ---
# The cortex-memory skill only teaches how to use Cortex
# (https://github.com/cdeust/Cortex); the tools come from its MCP server. On
# Claude Code that is the hypermnesia-mcp plugin (server plus lifecycle hooks).
# On Codex it is the PyPI package registered with `codex mcp add`, by absolute
# path so it starts even when Codex runs without ~/.local/bin on PATH.
CORTEX_MARKETPLACE="cdeust/Cortex"
CORTEX_PLUGIN="hypermnesia-mcp@cortex-plugins"
CORTEX_PACKAGE="hypermnesia-mcp"
CORTEX_EXTRA="sqlite"           # sqlite-vec vector search on the default store
CORTEX_MCP_NAME="cortex"
CORTEX_PYTHON="3.12"

# Run a claude CLI command in the scope's directory, so project-scope plugins
# resolve against the project.
claude_in_scope() {
  if [ "$SCOPE" = "project" ]; then (cd "$PROJECT_DIR" && claude "$@"); else claude "$@"; fi
}

# installed | legacy | missing. "legacy" is the pre-4.15 `cortex` plugin id.
cortex_plugin_status() {
  local list
  list="$(claude_in_scope plugin list --json 2>/dev/null || true)"
  case "$list" in
    *"\"$CORTEX_PLUGIN\""*) echo "installed" ;;
    *'"cortex@'*) echo "legacy" ;;
    *) echo "missing" ;;
  esac
}

install_cortex_plugin() {
  local status
  if ! command -v claude >/dev/null 2>&1; then
    warn "cortex-memory: the claude CLI is not on PATH, so the Cortex plugin was not installed. Run:"
    warn "  claude plugin install hypermnesia-mcp --marketplace $CORTEX_MARKETPLACE --scope $SCOPE"
    return 0
  fi
  status="$(cortex_plugin_status)"
  case "$status" in
    legacy)
      warn "cortex-memory: the old 'cortex' plugin is installed. Rename it (memories are kept):"
      warn "  claude plugin uninstall cortex && claude plugin install hypermnesia-mcp --marketplace $CORTEX_MARKETPLACE"
      return 0 ;;
    installed)
      if [ "$MODE" = "update" ]; then
        info "cortex-memory: updating the Cortex plugin"
        claude_in_scope plugin marketplace update cortex-plugins 2>&1 | sed 's/^/    /' || true
        claude_in_scope plugin update "$CORTEX_PLUGIN" --scope "$SCOPE" 2>&1 | sed 's/^/    /' \
          || warn "cortex-memory: plugin update failed; see the output above."
      else
        ok "cortex-memory: Cortex plugin already installed ($CORTEX_PLUGIN)"
      fi
      return 0 ;;
  esac
  info "cortex-memory: installing the Cortex plugin ($CORTEX_PLUGIN, scope $SCOPE)"
  if claude_in_scope plugin install hypermnesia-mcp --marketplace "$CORTEX_MARKETPLACE" --scope "$SCOPE" 2>&1 | sed 's/^/    /'; then
    ok "cortex-memory: Cortex plugin installed. Its first launch sets up its own runtime and the SQLite store"
    info "  (~/.claude/methodology/memory.db); the tools appear once that finishes."
  else
    warn "cortex-memory: plugin install failed; see the output above."
  fi
}

# Absolute path of the hypermnesia-mcp command, or empty.
cortex_bin() {
  if command -v "$CORTEX_PACKAGE" >/dev/null 2>&1; then command -v "$CORTEX_PACKAGE"
  elif [ "$IS_WINDOWS" = "yes" ] && [ -x "$HOME/.local/bin/$CORTEX_PACKAGE.exe" ]; then echo "$HOME/.local/bin/$CORTEX_PACKAGE.exe"
  elif [ -x "$HOME/.local/bin/$CORTEX_PACKAGE" ]; then echo "$HOME/.local/bin/$CORTEX_PACKAGE"
  fi
}

# Install (or, with "upgrade", upgrade) the PyPI server with its sqlite extra.
ensure_cortex_package() {
  local upgrade="${1:-}"
  if [ -n "$(cortex_bin)" ]; then
    [ "$upgrade" = "upgrade" ] || return 0
    if command -v uv >/dev/null 2>&1 && uv tool list 2>/dev/null | grep -q "^$CORTEX_PACKAGE "; then
      info "cortex-memory: upgrading the Cortex server (uv tool upgrade $CORTEX_PACKAGE)"
      uv tool upgrade "$CORTEX_PACKAGE" 2>&1 | sed 's/^/    /' || true
    elif command -v pipx >/dev/null 2>&1 && pipx list --short 2>/dev/null | grep -q "^$CORTEX_PACKAGE "; then
      info "cortex-memory: upgrading the Cortex server (pipx upgrade $CORTEX_PACKAGE)"
      pipx upgrade "$CORTEX_PACKAGE" 2>&1 | sed 's/^/    /' || true
    fi
    return 0
  fi
  if command -v uv >/dev/null 2>&1; then
    # Pin the interpreter: uv would otherwise take the first python3 on PATH,
    # which may be older than Cortex's 3.10 floor. 3.12 is what Cortex's own
    # launcher pins, since every dependency ships wheels for it.
    info "cortex-memory: installing the Cortex server (uv tool install --python $CORTEX_PYTHON \"$CORTEX_PACKAGE[$CORTEX_EXTRA]\")"
    uv tool install --python "$CORTEX_PYTHON" "$CORTEX_PACKAGE[$CORTEX_EXTRA]" 2>&1 | sed 's/^/    /' \
      || { warn "cortex-memory: installing the Cortex server failed; see the output above."; return 1; }
  elif command -v pipx >/dev/null 2>&1; then
    info "cortex-memory: installing the Cortex server (pipx install \"$CORTEX_PACKAGE[$CORTEX_EXTRA]\")"
    pipx install ${PYTHON310:+--python "$PYTHON310"} "$CORTEX_PACKAGE[$CORTEX_EXTRA]" 2>&1 | sed 's/^/    /' \
      || { warn "cortex-memory: installing the Cortex server failed; see the output above."; return 1; }
  else
    warn "cortex-memory: needs uv or pipx to install the Cortex server for Codex:"
    uv_install_hint
    return 1
  fi
  [ -n "$(cortex_bin)" ] || { warn "cortex-memory: Cortex server installed but $CORTEX_PACKAGE not found; run 'uv tool update-shell' and rerun."; return 1; }
}

# Codex keeps MCP servers in ~/.codex/config.toml only, so this runs at user
# scope even for a project install.
install_cortex_mcp() {
  local bin backend env_args=""
  if ! command -v codex >/dev/null 2>&1; then
    warn "cortex-memory: the codex CLI is not on PATH, so the Cortex MCP server was not registered."
    return 0
  fi
  if codex mcp get "$CORTEX_MCP_NAME" >/dev/null 2>&1; then
    if [ "$MODE" = "update" ]; then ensure_cortex_package upgrade || true; fi
    ok "cortex-memory: Codex MCP server '$CORTEX_MCP_NAME' already registered"
    return 0
  fi
  ensure_cortex_package || return 0
  bin="$(native_path "$(cortex_bin)")"
  # Claude Code and Codex share one store through backend.json. Pin SQLite only
  # when no marker chose another backend, so an existing PostgreSQL setup wins.
  backend="$(sed -n 's/.*"backend"[^"]*"\([a-z]*\)".*/\1/p' "$HOME/.claude/methodology/backend.json" 2>/dev/null | head -1 || true)"
  if [ -z "$backend" ] || [ "$backend" = "sqlite" ]; then
    env_args="--env CORTEX_MEMORY_STORE_BACKEND=sqlite"
  fi
  info "cortex-memory: registering the Cortex MCP server in Codex ($CORTEX_MCP_NAME -> $bin)"
  # shellcheck disable=SC2086
  if codex mcp add "$CORTEX_MCP_NAME" $env_args -- "$bin" 2>&1 | sed 's/^/    /'; then
    ok "cortex-memory: Codex MCP server '$CORTEX_MCP_NAME' registered (all 57 Cortex tools)"
  else
    warn "cortex-memory: 'codex mcp add' failed; see the output above."
  fi
}

# One-word runtime state for --list.
cortex_memory_runtime_status() {
  case "$1" in
    claude)
      command -v claude >/dev/null 2>&1 || { echo "plugin: claude CLI missing"; return; }
      echo "plugin: $(cortex_plugin_status)" ;;
    openai)
      command -v codex >/dev/null 2>&1 || { echo "MCP: codex CLI missing"; return; }
      if codex mcp get "$CORTEX_MCP_NAME" >/dev/null 2>&1; then echo "MCP: registered"; else echo "MCP: missing"; fi ;;
  esac
}

# Called after the skill copy for every vendor, whatever the copy's status:
# the runtime can be missing while the skill is current.
cortex_memory_runtime() {
  [ "$WITH_EXTERNAL" = "yes" ] || { info "cortex-memory: --no-external given, skipping the Cortex plugin/MCP server"; return 0; }
  case "$1" in
    claude) install_cortex_plugin ;;
    openai) install_cortex_mcp ;;
  esac
}

# installed | outdated | missing
skill_status() {
  local vendor="$1" skill="$2" src dst
  if is_external "$skill"; then "${skill}_status" "$vendor"; return; fi
  src="$REPO_DIR/$vendor/$skill"
  dst="$(skills_root "$vendor")/$skill"
  if [ ! -d "$dst" ]; then echo "missing"; return; fi
  if diff -rq "$src" "$dst" >/dev/null 2>&1; then echo "installed"; else echo "outdated"; fi
}

copy_tree() {
  # copy_tree SRC DST : replace DST with a copy of SRC
  local src="$1" dst="$2"
  mkdir -p "$(dirname "$dst")"
  rm -rf "$dst"
  cp -R "$src" "$dst"
}

install_skill() {
  local vendor="$1" skill="$2" src dst status
  needs_python310 "$skill" && check_python310 "$skill"
  if is_external "$skill"; then "install_${skill}" "$vendor"; return; fi
  src="$REPO_DIR/$vendor/$skill"
  dst="$(skills_root "$vendor")/$skill"
  status="$(skill_status "$vendor" "$skill")"
  case "$status" in
    installed)
      ok "$skill: already up to date at $dst" ;;
    outdated)
      if [ "$MODE" = "update" ]; then
        copy_tree "$src" "$dst"; ok "$skill: updated at $dst"
      else
        warn "$skill: installed at $dst but differs from the repo. Run with --update (or choose update) to overwrite."
      fi ;;
    missing)
      copy_tree "$src" "$dst"; ok "$skill: installed at $dst" ;;
  esac
  # Skills backed by third-party software install it through <skill>_runtime.
  if declare -F "${skill//-/_}_runtime" >/dev/null; then "${skill//-/_}_runtime" "$vendor"; fi
}

# Copy agent templates (assets/agents/*) without overwriting existing agents.
install_agents() {
  local vendor="$1" skill="$2" src dst f name copied=0 skipped=0
  src="$REPO_DIR/$vendor/$skill/assets/agents"
  [ -d "$src" ] || return 0
  dst="$(agents_root "$vendor")"
  mkdir -p "$dst"
  for f in "$src"/*; do
    [ -f "$f" ] || continue
    name="$(basename "$f")"
    if [ -e "$dst/$name" ]; then
      skipped=$((skipped + 1))
    else
      cp "$f" "$dst/$name"; copied=$((copied + 1))
    fi
  done
  ok "$skill agents: $copied copied to $dst, $skipped already present (left untouched)"
  if [ "$vendor" = "openai" ] && [ -f "$REPO_DIR/$vendor/$skill/assets/config.toml.example" ]; then
    info "Codex also needs an [agents] table; see $REPO_DIR/$vendor/$skill/assets/config.toml.example"
  fi
  if grep -rq '<[a-z][a-z ,/-]*>' "$dst" 2>/dev/null; then
    warn "Agent templates contain <placeholders> (build command, test filter, project rules). Edit them in $dst."
  fi
}

# ------------------------------------------------------ the ai-skills plugin ---
# Claude Code reads a directory marketplace live from this checkout, so edits
# show up on the next session. Codex copies the committed tree into
# ~/.codex/plugins/cache/ai-skills/ai-skills/<version>: uncommitted changes are
# not installed, and `codex plugin add` again is how it updates. Codex plugins
# are user-level only and carry no hook; the skills rely on their descriptions.

# installed | missing | no-cli
plugin_status() {
  case "$1" in
    claude)
      command -v claude >/dev/null 2>&1 || { echo "no-cli"; return; }
      case "$(claude_in_scope plugin list --json 2>/dev/null || true)" in
        *"\"$PLUGIN_ID\""*) echo "installed" ;;
        *) echo "missing" ;;
      esac ;;
    openai)
      command -v codex >/dev/null 2>&1 || { echo "no-cli"; return; }
      if codex plugin list 2>/dev/null | grep -q "^$PLUGIN_ID  *installed"; then echo "installed"; else echo "missing"; fi ;;
  esac
}

# Copied skills that the plugin would duplicate (same name, also listed as
# ai-skills:<name>). Reported, never deleted.
plugin_duplicates() {
  local vendor="$1" root d dups=""
  root="$(skills_root "$vendor")"
  for d in "$REPO_DIR/$vendor"/*/; do
    [ -f "${d}SKILL.md" ] || continue
    [ -d "$root/$(basename "$d")" ] && dups="$dups $(basename "$d")"
  done
  if [ -n "$dups" ]; then
    warn "These skills are also copied into $root and will show up twice, once from the plugin:"
    warn " $dups"
    warn "  Remove the copies once the plugin works, e.g.: cd \"$root\" && rm -rf$dups"
  fi
}

install_plugin_claude() {
  local status
  status="$(plugin_status claude)"
  if [ "$status" = "no-cli" ]; then
    warn "Claude Code: the claude CLI is not on PATH, so the plugin was not installed. Run:"
    warn "  claude plugin marketplace add \"$REPO_DIR\" && claude plugin install $PLUGIN_ID --scope $SCOPE"
    return 0
  fi
  if ! claude_in_scope plugin marketplace list --json 2>/dev/null | grep -q "\"name\": *\"$PLUGIN_MARKETPLACE\""; then
    info "Claude Code: adding this checkout as the '$PLUGIN_MARKETPLACE' marketplace (scope $SCOPE)"
    claude_in_scope plugin marketplace add "$(native_path "$REPO_DIR")" --scope "$SCOPE" 2>&1 | sed 's/^/    /' \
      || { warn "Claude Code: 'claude plugin marketplace add' failed; see the output above."; return 0; }
  fi
  case "$status" in
    installed)
      if [ "$MODE" = "update" ]; then
        info "Claude Code: updating $PLUGIN_ID"
        claude_in_scope plugin marketplace update "$PLUGIN_MARKETPLACE" 2>&1 | sed 's/^/    /' || true
        claude_in_scope plugin update "$PLUGIN_ID" --scope "$SCOPE" 2>&1 | sed 's/^/    /' \
          || warn "Claude Code: plugin update failed; see the output above."
      else
        ok "Claude Code: $PLUGIN_ID already installed (it reads this checkout, so edits apply on the next session)"
      fi ;;
    missing)
      info "Claude Code: installing $PLUGIN_ID (scope $SCOPE)"
      if claude_in_scope plugin install "$PLUGIN_ID" --scope "$SCOPE" 2>&1 | sed 's/^/    /'; then
        ok "Claude Code: plugin installed; skills are named ai-skills:<name>"
      else
        warn "Claude Code: plugin install failed; see the output above."
      fi ;;
  esac
  plugin_duplicates claude
}

install_plugin_openai() {
  local status
  status="$(plugin_status openai)"
  if [ "$status" = "no-cli" ]; then
    warn "Codex: the codex CLI is not on PATH, so the plugin was not installed. Run:"
    warn "  codex plugin marketplace add \"$REPO_DIR\" && codex plugin add $PLUGIN_ID"
    return 0
  fi
  [ "$SCOPE" = "project" ] && warn "Codex: plugins are user-level only; installing for the user, not for $PROJECT_DIR."
  if [ -n "$(git -C "$REPO_DIR" status --porcelain -- openai .codex-plugin .agents tools/agent-router scripts/router-runtime.sh scripts/agent-router 2>/dev/null)" ]; then
    warn "Codex: skills, router source/launchers or the Codex manifests have uncommitted changes. Codex installs the committed tree, so commit first to include them."
  fi
  if ! codex plugin marketplace list 2>/dev/null | grep -q "^$PLUGIN_MARKETPLACE "; then
    info "Codex: adding this checkout as the '$PLUGIN_MARKETPLACE' marketplace"
    codex plugin marketplace add "$(native_path "$REPO_DIR")" 2>&1 | sed 's/^/    /' \
      || { warn "Codex: 'codex plugin marketplace add' failed; see the output above."; return 0; }
  fi
  if [ "$status" = "installed" ] && [ "$MODE" != "update" ]; then
    ok "Codex: $PLUGIN_ID already installed (run with --update to reinstall from the current commit)"
  else
    info "Codex: installing $PLUGIN_ID from the current commit"
    if codex plugin add "$PLUGIN_ID" 2>&1 | sed 's/^/    /'; then
      ok "Codex: plugin installed. Subagent skills need multi_agent = true under [features] in ~/.codex/config.toml."
    else
      warn "Codex: 'codex plugin add' failed; see the output above."
    fi
  fi
  plugin_duplicates openai
}

# Plugin mode: the plugin replaces the per-skill copies, but third-party
# runtimes (Cortex, graphify) and the agent templates still install here.
install_plugin() {
  local vendor="$1"
  "install_plugin_$vendor"
  if [ "$WITH_EXTERNAL" = "yes" ]; then
    check_python310
    cortex_memory_runtime "$vendor"
    install_graphify "$vendor"
  else
    info "--no-external given, skipping the Cortex plugin/MCP server and graphify"
  fi
  [ "$COPY_AGENTS" = "yes" ] && install_agents "$vendor" agent-router
  return 0
}

# read with a default; returns default when stdin is not a tty (non-interactive)
ask() {
  local prompt="$1" default="$2" answer
  if [ "$NONINTERACTIVE" = "yes" ] || [ ! -t 0 ]; then echo "$default"; return; fi
  printf '%s' "$prompt" >&2
  IFS= read -r answer || answer=""
  [ -n "$answer" ] && echo "$answer" || echo "$default"
}

# ------------------------------------------------------------ parse flags ---
while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help) usage ;;
    --all) SELECT_ALL="yes"; NONINTERACTIVE="yes" ;;
    --update) MODE="update" ;;
    --vendor) shift; VENDOR_FILTER="${1:-}"; [ -n "$VENDOR_FILTER" ] || die "--vendor needs claude or openai" ;;
    --project) shift; PROJECT_DIR="${1:-}"; [ -n "$PROJECT_DIR" ] || die "--project needs a directory"; SCOPE="project" ;;
    --user) SCOPE="user" ;;
    --agents) COPY_AGENTS="yes" ;;
    --no-agents) COPY_AGENTS="no" ;;
    --list) LIST_ONLY="yes" ;;
    --no-external) WITH_EXTERNAL="no" ;;
    --no-router) WITH_ROUTER="no" ;;
    --plugin) METHOD="plugin" ;;
    --skills) METHOD="skills" ;;
    *) die "Unknown option: $1 (try --help)" ;;
  esac
  shift
done

case "$VENDOR_FILTER" in
  ""|claude|openai) ;;
  *) die "--vendor must be claude or openai" ;;
esac

if [ "$SCOPE" = "project" ]; then
  PROJECT_DIR="$(shell_path "$PROJECT_DIR")"
  [ -d "$PROJECT_DIR" ] || die "Project directory not found: $PROJECT_DIR"
  PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)"
fi

# --------------------------------------------------------- detect vendors ---
say ""
say "ai-skills installer  (repo: $REPO_DIR)"
say ""
say "Detecting installed tools:"
AVAILABLE=""
for v in $VENDORS; do
  [ -n "$VENDOR_FILTER" ] && [ "$v" != "$VENDOR_FILTER" ] && continue
  if vendor_installed "$v"; then
    ok "$(vendor_label "$v"): found ($(vendor_detail "$v"))"
    AVAILABLE="$AVAILABLE $v"
  else
    warn "$(vendor_label "$v"): not found (no CLI on PATH and no home directory). Skipping."
  fi
done
AVAILABLE="${AVAILABLE# }"
[ -n "$AVAILABLE" ] || die "Neither Claude Code nor OpenAI Codex is installed. Nothing to do."

# ------------------------------------------------------- scope (interactive) ---
if [ "$NONINTERACTIVE" = "no" ] && [ -t 0 ] && [ "$SCOPE" = "user" ] && [ -z "$PROJECT_DIR" ]; then
  say ""
  say "Where should the skills be installed?"
  say "  1) User level (~/.claude/skills, ~/.agents/skills)  [default]"
  say "  2) A project directory (DIR/.claude/skills, DIR/.agents/skills)"
  choice="$(ask "Choice [1]: " "1")"
  if [ "$choice" = "2" ]; then
    PROJECT_DIR="$(ask "Project directory [$(pwd)]: " "$(pwd)")"
    PROJECT_DIR="$(shell_path "$PROJECT_DIR")"
    [ -d "$PROJECT_DIR" ] || die "Project directory not found: $PROJECT_DIR"
    PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)"
    SCOPE="project"
  fi
fi

# ---------------------------------------------------------- install method ---
if [ "$METHOD" = "ask" ]; then
  if [ "$NONINTERACTIVE" = "no" ] && [ -t 0 ] && [ "$LIST_ONLY" = "no" ]; then
    say ""
    say "How should they be installed?"
    say "  1) As the ai-skills plugin: every skill, plus a session-start bootstrap on Claude Code  [default]"
    say "  2) As individual skills copied into the skills folder (pick which ones)"
    choice="$(ask "Choice [1]: " "1")"
    [ "$choice" = "2" ] && METHOD="skills" || METHOD="plugin"
  else
    METHOD="skills"
  fi
fi

if [ "$METHOD" = "plugin" ] && [ "$LIST_ONLY" = "no" ]; then
  if [ "$NONINTERACTIVE" = "no" ] && [ -t 0 ]; then
    say ""
    say "Action:"
    say "  1) Install (leave an installed plugin as it is)  [default]"
    say "  2) Update (refresh the marketplace and reinstall the plugin)"
    choice="$(ask "Choice [$([ "$MODE" = "update" ] && echo 2 || echo 1)]: " "$([ "$MODE" = "update" ] && echo 2 || echo 1)")"
    [ "$choice" = "2" ] && MODE="update" || MODE="install"
    if [ "$COPY_AGENTS" = "ask" ]; then
      a="$(ask "Copy the agent-router agent templates too (existing agents are never overwritten)? [y/N]: " "n")"
      case "$a" in y|Y|yes|YES) COPY_AGENTS="yes" ;; *) COPY_AGENTS="no" ;; esac
    fi
  fi
  [ "$COPY_AGENTS" = "ask" ] && COPY_AGENTS="no"
  say ""
  say "Applying ($MODE, plugin):"
  ensure_agent_router
  for v in $AVAILABLE; do install_plugin "$v"; done
  say ""
  say "Done. Restart Claude Code / Codex (or start a new session) so the plugin is loaded."
  exit 0
fi

# ------------------------------------------------------------ list skills ---
# Build a numbered catalogue: "vendor skill status"
CATALOGUE=""
n=0
say ""
say "Skills (scope: $SCOPE$([ "$SCOPE" = "project" ] && printf ' at %s' "$PROJECT_DIR")):"
for v in $AVAILABLE; do
  for s in $(repo_skills "$v"); do
    n=$((n + 1))
    st="$(skill_status "$v" "$s")"
    CATALOGUE="$CATALOGUE
$n $v $s $st"
    case "$st" in
      installed) tag="\033[32m[installed]\033[0m" ;;
      outdated)  tag="\033[33m[update available]\033[0m" ;;
      missing)   tag="\033[90m[not installed]\033[0m" ;;
    esac
    is_external "$s" && tag="$tag \033[90m(external, via the $s CLI)\033[0m"
    if [ "$WITH_EXTERNAL" = "yes" ] && declare -F "${s//-/_}_runtime_status" >/dev/null; then
      tag="$tag \033[90m($("${s//-/_}_runtime_status" "$v"))\033[0m"
    fi
    printf '  %2d) %-13s %-28s %b\n' "$n" "$(vendor_label "$v")" "$s" "$tag"
  done
done
[ "$n" -gt 0 ] || die "No skills found in the repo for: $AVAILABLE"
if [ "$LIST_ONLY" = "yes" ]; then
  router_dest="$(router_runtime_dir)"
  router_status="$(bash "$REPO_DIR/scripts/router-runtime.sh" --root "$REPO_DIR" --runtime-dir "$router_dest" --status)"
  say ""
  say "agent-router runtime: $router_status ($router_dest)"
  say ""
  say "ai-skills plugin ($PLUGIN_ID):"
  for v in $AVAILABLE; do
    case "$(plugin_status "$v")" in
      installed) tag="\033[32m[installed]\033[0m" ;;
      missing)   tag="\033[90m[not installed]\033[0m" ;;
      no-cli)    tag="\033[90m[CLI not on PATH]\033[0m" ;;
    esac
    printf '      %-13s %b\n' "$(vendor_label "$v")" "$tag"
  done
  exit 0
fi

# --------------------------------------------------------- mode + selection ---
if [ "$NONINTERACTIVE" = "no" ] && [ -t 0 ]; then
  say ""
  say "Action:"
  say "  1) Install (add missing skills, leave installed ones untouched)  [default]"
  say "  2) Update (install missing and overwrite installed skills with the repo version)"
  choice="$(ask "Choice [$([ "$MODE" = "update" ] && echo 2 || echo 1)]: " "$([ "$MODE" = "update" ] && echo 2 || echo 1)")"
  [ "$choice" = "2" ] && MODE="update" || MODE="install"

  say ""
  say "Which skills? Enter numbers separated by spaces, or 'a' for all."
  sel="$(ask "Selection [a]: " "a")"
else
  sel="a"
fi

SELECTED=""
if [ "$sel" = "a" ] || [ "$sel" = "all" ] || [ "$SELECT_ALL" = "yes" ]; then
  SELECTED="$(printf '%s' "$CATALOGUE" | awk 'NF {print $1}')"
else
  for tok in $sel; do
    case "$tok" in
      ''|*[!0-9]*) die "Invalid selection: $tok" ;;
    esac
    [ "$tok" -ge 1 ] && [ "$tok" -le "$n" ] || die "Selection out of range: $tok"
    SELECTED="$SELECTED $tok"
  done
fi

# ----------------------------------------------------------- agents prompt ---
HAS_AGENTS="no"
for idx in $SELECTED; do
  line="$(printf '%s' "$CATALOGUE" | awk -v i="$idx" '$1 == i')"
  v="$(echo "$line" | awk '{print $2}')"; s="$(echo "$line" | awk '{print $3}')"
  [ -d "$REPO_DIR/$v/$s/assets/agents" ] && HAS_AGENTS="yes"
done
if [ "$HAS_AGENTS" = "yes" ] && [ "$COPY_AGENTS" = "ask" ]; then
  if [ "$NONINTERACTIVE" = "no" ] && [ -t 0 ]; then
    a="$(ask "Some skills ship agent templates. Copy them too (existing agents are never overwritten)? [y/N]: " "n")"
    case "$a" in y|Y|yes|YES) COPY_AGENTS="yes" ;; *) COPY_AGENTS="no" ;; esac
  else
    COPY_AGENTS="no"
  fi
fi

# ------------------------------------------------------------------ apply ---
# Fail before copying skills if a selected router cannot be prepared. Both
# vendor copies share the same runtime, so prepare it at most once per run.
for idx in $SELECTED; do
  s="$(printf '%s' "$CATALOGUE" | awk -v i="$idx" '$1 == i {print $3}')"
  [ "$s" = "agent-router" ] && ensure_agent_router
done
say ""
say "Applying ($MODE):"
for idx in $SELECTED; do
  line="$(printf '%s' "$CATALOGUE" | awk -v i="$idx" '$1 == i')"
  v="$(echo "$line" | awk '{print $2}')"; s="$(echo "$line" | awk '{print $3}')"
  install_skill "$v" "$s"
  [ "$COPY_AGENTS" = "yes" ] && install_agents "$v" "$s"
done

say ""
say "Done. Restart Claude Code / Codex (or start a new session) so the skills list is reloaded."
