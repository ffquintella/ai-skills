#!/usr/bin/env bash
# Prints Rust capability flags for a directory. Deliberately permissive: a false
# positive only adds a worker. Exit 1 if there are no .rs files.
# Usage: probe.sh [dir]
set -u
root=${1:-.}

count=$(find "$root" -name '*.rs' -not -path '*/target/*' -not -path '*/.git/*' | wc -l | tr -d ' ')
echo "rs_files=$count"
[ "$count" -gt 0 ] || exit 1

has() {
  if grep -rqE --include='*.rs' --exclude-dir=target --exclude-dir=.git -e "$2" "$root"; then
    echo "$1=true"
  else
    echo "$1=false"
  fi
}

has has_unsafe       '\bunsafe\b'
has has_ffi          'extern[[:space:]]+"(C|system|C-unwind)"|#\[(unsafe\()?no_mangle|\blibc::|\bextern[[:space:]]*\{'
has has_concurrency  'std::thread|thread::spawn|\bMutex\b|\bRwLock\b|\bAtomic[A-Z]|mpsc|\bCondvar\b|rayon|crossbeam|tokio::spawn|\bArc<'
has has_async        '\basync[[:space:]]+(fn|move|\{)|\.await\b'
has has_packed_repr  'repr\([^)]*packed'
has has_fs_io        'std::fs|\bfs::|\bFile::|OpenOptions|\bPathBuf\b|\bPath::'
