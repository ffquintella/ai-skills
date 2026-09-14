#!/usr/bin/env bash

set -euo pipefail

OVERWRITE="false"
POSITIONAL_ARGS=()
for arg in "$@"; do
  if [[ "$arg" == "--overwrite" ]]; then
    OVERWRITE="true"
  else
    POSITIONAL_ARGS+=("$arg")
  fi
done

if [[ ${#POSITIONAL_ARGS[@]} -lt 1 || ${#POSITIONAL_ARGS[@]} -gt 2 ]]; then
  echo "Usage: $0 <claude|codex|all> [target_base_dir] [--overwrite]"
  exit 1
fi

FORMAT="${POSITIONAL_ARGS[0]}"
TARGET_BASE="${POSITIONAL_ARGS[1]:-$HOME}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ "$TARGET_BASE" == "/" ]]; then
  echo "Refusing unsafe target base directory: /"
  exit 1
fi

validate_format() {
  local format="$1"
  local source_dir="$ROOT_DIR/skills/$format"
  local target_dir="$TARGET_BASE/.${format}/skills"

  if [[ ! -d "$source_dir" ]]; then
    echo "Missing source directory: $source_dir"
    exit 1
  fi

  if [[ -z "$target_dir" || "$target_dir" == "/" ]]; then
    echo "Unsafe target directory: $target_dir"
    exit 1
  fi
  case "$target_dir" in
    */".${format}"/skills) ;;
    *)
      echo "Unexpected target directory: $target_dir"
      exit 1
      ;;
  esac

  if [[ -d "$target_dir" ]] && find "$target_dir" -mindepth 1 -print -quit | grep -q .; then
    if [[ "$OVERWRITE" != "true" ]]; then
      echo "Target already contains skills: $target_dir"
      echo "Re-run with --overwrite to replace existing files."
      exit 1
    fi
  fi
}

install_format() {
  local format="$1"
  local source_dir="$ROOT_DIR/skills/$format"
  local target_dir="$TARGET_BASE/.${format}/skills"
  local target_parent
  local temp_target_dir
  local backup_target_dir=""

  cleanup_install() {
    if [[ -n "${temp_target_dir:-}" && -d "$temp_target_dir" ]]; then
      rm -rf "$temp_target_dir"
    fi
    if [[ -n "${backup_target_dir:-}" && -d "$backup_target_dir" && ! -d "$target_dir" ]]; then
      mv "$backup_target_dir" "$target_dir"
    fi
  }
  trap cleanup_install RETURN

  target_parent="$(dirname "$target_dir")"
  mkdir -p "$target_parent"
  temp_target_dir="$(mktemp -d "$target_parent/skills.tmp.XXXXXX")"

  if ! cp -R "$source_dir"/. "$temp_target_dir"/; then
    echo "Failed to copy $format skills from $source_dir"
    exit 1
  fi
  if [[ -d "$target_dir" ]]; then
    backup_target_dir="$(mktemp -d "$target_parent/skills.bak.XXXXXX")"
    rmdir "$backup_target_dir"
    if ! mv "$target_dir" "$backup_target_dir"; then
      echo "Failed to stage existing skills directory: $target_dir"
      exit 1
    fi
    if mv "$temp_target_dir" "$target_dir"; then
      rm -rf "$backup_target_dir"
      temp_target_dir=""
      backup_target_dir=""
    else
      echo "Failed to install $format skills to $target_dir"
      exit 1
    fi
  else
    if ! mv "$temp_target_dir" "$target_dir"; then
      echo "Failed to install $format skills to $target_dir"
      exit 1
    fi
    temp_target_dir=""
  fi

  echo "Installed $format skills to $target_dir"
}

FORMATS=()
case "$FORMAT" in
  claude|codex)
    FORMATS=("$FORMAT")
    ;;
  all)
    FORMATS=("claude" "codex")
    ;;
  *)
    echo "Invalid format: $FORMAT"
    echo "Expected: claude, codex, or all"
    exit 1
    ;;
esac

for item in "${FORMATS[@]}"; do
  validate_format "$item"
done

for item in "${FORMATS[@]}"; do
  install_format "$item"
done
