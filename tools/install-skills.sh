#!/usr/bin/env bash

set -euo pipefail

if [[ $# -lt 1 || $# -gt 2 ]]; then
  echo "Usage: $0 <claude|codex|all> [target_base_dir]"
  exit 1
fi

FORMAT="$1"
TARGET_BASE="${2:-$HOME}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

install_format() {
  local format="$1"
  local source_dir="$ROOT_DIR/skills/$format"
  local target_dir="$TARGET_BASE/.${format}/skills"

  if [[ ! -d "$source_dir" ]]; then
    echo "Missing source directory: $source_dir"
    exit 1
  fi

  rm -rf "$target_dir"
  mkdir -p "$target_dir"
  cp -R "$source_dir"/. "$target_dir"/
  echo "Installed $format skills to $target_dir"
}

case "$FORMAT" in
  claude|codex)
    install_format "$FORMAT"
    ;;
  all)
    install_format "claude"
    install_format "codex"
    ;;
  *)
    echo "Invalid format: $FORMAT"
    echo "Expected: claude, codex, or all"
    exit 1
    ;;
esac
