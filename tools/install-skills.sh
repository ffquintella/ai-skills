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

if ! command -v tar >/dev/null 2>&1; then
  echo "Missing required dependency: tar"
  exit 1
fi

if ! command -v mktemp >/dev/null 2>&1; then
  echo "Missing required dependency: mktemp"
  exit 1
fi

if [[ "$FORMAT" == "all" && "$OVERWRITE" == "true" ]]; then
  echo "Combined overwrite for 'all' is not supported."
  echo "Run separate overwrite installs for claude and codex."
  exit 1
fi

dir_has_entries() {
  local dir="$1"
  if [[ ! -r "$dir" ]]; then
    echo "Cannot read target directory: $dir"
    exit 1
  fi

  local entries
  local had_nullglob="false"
  local had_dotglob="false"
  if shopt -q nullglob; then
    had_nullglob="true"
  fi
  if shopt -q dotglob; then
    had_dotglob="true"
  fi

  shopt -s nullglob dotglob
  entries=("$dir"/*)
  if [[ "$had_nullglob" == "false" ]]; then
    shopt -u nullglob
  fi
  if [[ "$had_dotglob" == "false" ]]; then
    shopt -u dotglob
  fi

  [[ ${#entries[@]} -gt 0 ]]
}

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

  if [[ -e "$target_dir" && ! -d "$target_dir" ]]; then
    echo "Target path exists but is not a directory: $target_dir"
    exit 1
  fi

  if [[ -d "$target_dir" ]] && dir_has_entries "$target_dir"; then
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
  local backup_parent_dir=""

  make_temp_dir() {
    local base_dir="$1"
    local prefix="$2"
    local temp_dir
    if temp_dir="$(mktemp -d "$base_dir/${prefix}.XXXXXX" 2>/dev/null)"; then
      echo "$temp_dir"
      return 0
    fi
    if temp_dir="$(cd "$base_dir" && mktemp -d "${prefix}.XXXXXX" 2>/dev/null)"; then
      echo "$base_dir/$temp_dir"
      return 0
    fi
    echo "Failed to create temporary directory in $base_dir"
    exit 1
  }

  copy_tree() {
    local source="$1"
    local destination="$2"
    (cd "$source" && tar -cf - .) | (cd "$destination" && tar -xf -)
  }

  target_parent="$(dirname "$target_dir")"
  mkdir -p "$target_parent"

  temp_target_dir="$(make_temp_dir "$target_parent" "skills.tmp")"

  if ! copy_tree "$source_dir" "$temp_target_dir"; then
    rm -rf "$temp_target_dir"
    echo "Failed to copy $format skills from $source_dir"
    exit 1
  fi
  if ! dir_has_entries "$temp_target_dir"; then
    rm -rf "$temp_target_dir"
    echo "Staged skills directory is empty after copy: $temp_target_dir"
    exit 1
  fi
  if [[ -d "$target_dir" ]] && ! dir_has_entries "$target_dir"; then
    if ! rmdir "$target_dir"; then
      rm -rf "$temp_target_dir"
      echo "Failed to prepare empty target directory: $target_dir"
      exit 1
    fi
  fi
  if [[ -d "$target_dir" ]]; then
    backup_parent_dir="$(make_temp_dir "$target_parent" "skills.bak")"
    backup_target_dir="$backup_parent_dir/skills"
    if ! mv "$target_dir" "$backup_target_dir"; then
      rm -rf "$temp_target_dir"
      rm -rf "$backup_parent_dir"
      echo "Failed to stage existing skills directory: $target_dir"
      exit 1
    fi
    if mv "$temp_target_dir" "$target_dir"; then
      rm -rf "$backup_parent_dir"
    else
      rm -rf "$temp_target_dir"
      if ! mv "$backup_target_dir" "$target_dir"; then
        echo "Failed to install $format skills and failed to restore backup from $backup_target_dir"
        echo "Backup preserved at: $backup_parent_dir"
        exit 1
      fi
      rm -rf "$backup_parent_dir"
      echo "Failed to install $format skills to $target_dir (restored previous version)"
      exit 1
    fi
  else
    if ! mv "$temp_target_dir" "$target_dir"; then
      rm -rf "$temp_target_dir"
      echo "Failed to install $format skills to $target_dir"
      exit 1
    fi
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
