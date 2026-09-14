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
#
# Works with macOS bash 3.2 (no associative arrays, no mapfile).

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENDORS="claude openai"

MODE="install"          # install | update
SCOPE="user"            # user | project
PROJECT_DIR=""
VENDOR_FILTER=""
SELECT_ALL="no"
COPY_AGENTS="ask"       # ask | yes | no
LIST_ONLY="no"
NONINTERACTIVE="no"

# ---------------------------------------------------------------- helpers ---
say()  { printf '%s\n' "$*"; }
info() { printf '  \033[36m%s\033[0m\n' "$*"; }
ok()   { printf '  \033[32m%s\033[0m\n' "$*"; }
warn() { printf '  \033[33m%s\033[0m\n' "$*"; }
err()  { printf '\033[31m%s\033[0m\n' "$*" >&2; }
die()  { err "$*"; exit 1; }

usage() { sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'; exit 0; }

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

# Skills available in the repo for a vendor (directory names).
repo_skills() {
  local vendor="$1" d
  [ -d "$REPO_DIR/$vendor" ] || return 0
  for d in "$REPO_DIR/$vendor"/*/; do
    [ -f "${d}SKILL.md" ] && basename "$d"
  done
}

# installed | outdated | missing
skill_status() {
  local vendor="$1" skill="$2" src dst
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
    *) die "Unknown option: $1 (try --help)" ;;
  esac
  shift
done

case "$VENDOR_FILTER" in
  ""|claude|openai) ;;
  *) die "--vendor must be claude or openai" ;;
esac

if [ "$SCOPE" = "project" ]; then
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
    [ -d "$PROJECT_DIR" ] || die "Project directory not found: $PROJECT_DIR"
    PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)"
    SCOPE="project"
  fi
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
    printf '  %2d) %-13s %-24s %b\n' "$n" "$(vendor_label "$v")" "$s" "$tag"
  done
done
[ "$n" -gt 0 ] || die "No skills found in the repo for: $AVAILABLE"
[ "$LIST_ONLY" = "yes" ] && exit 0

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
