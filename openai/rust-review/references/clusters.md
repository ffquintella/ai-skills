# Clusters and bug classes

Gate `always` runs on every Rust audit; otherwise the cluster needs the flag from
`scripts/probe.sh`. A pass marked (+flag) also needs that second flag. Each pass is one
bug class: the worker searches for the pattern, traces data flow from attacker input to
the sink, checks mitigations, then files or clears it.

| # | Cluster | Gate | Passes (what to look for) |
| --- | --- | --- | --- |
| 1 | `unsafe-boundary` | always | **safe API reaching unsafe** (a safe `pub fn` whose soundness depends on the caller), **`transmute` misuse** (size, validity, lifetime), **raw pointer arithmetic** (out-of-bounds offsets, wrong element size), **pointer casts** (alignment, provenance, type punning), **`repr(C)` layout** assumptions, **enum discriminant** UB (invalid values cast or read), **missing `# Safety` docs** on `unsafe fn`, **`debug_assert!` guarding safety** (vanishes in release) |
| 2 | `memory-safety` | has_unsafe | **uninitialized reads** (`MaybeUninit`, `mem::uninitialized`), **`Vec::set_len`** before init, **invalid free** (`from_raw_parts`/`Box::from_raw` on foreign memory), **use-after-free**, **double free**, **buffer overflow** in unsafe code, **union** reads of wrong field, **panic unwind through unsafe** leaving broken invariants |
| 3 | `concurrency-locking` | has_concurrency | **double lock**, **ABBA** lock ordering, **`Condvar`** misuse (no loop, lost wakeup), **channel starvation**, **`Once`/`OnceCell` reentrancy**, **reentrancy** into non-reentrant code via callbacks |
| 4 | `concurrency-data-race` | has_concurrency | **atomic ordering races** (`Relaxed` where acquire/release needed), **`unsafe impl Sync/Send`** (+has_unsafe), **`Send`/`Sync` bounds** missing on generics, **shared-memory races** (mmap, FFI buffers), **`static mut`** (+has_unsafe) |
| 5 | `panic-dos` | always | **resource exhaustion** (attacker-sized allocation, unbounded loops or queues), **`unwrap`/`expect` on untrusted input**, **arithmetic overflow** (wraps in release, panics in debug), **reachable `assert!`/`unreachable!`**, **out-of-bounds indexing**, **string slicing off a char boundary**, **`RefCell` double borrow** |
| 6 | `recursion-dos` | always | **recursive deserialization**, **recursive `Display`/`Debug`**, **recursive `Drop`** on attacker-shaped nesting (stack overflow). One pass per worker |
| 7 | `error-handling` | always | **discarded `Result`** (`let _ =`, ignored `#[must_use]`), **panic in `Drop`**, **lossy `From`/`Into`** (silent truncation), **lossy `from_utf8_lossy`/`to_string_lossy`** on data later compared or used as a key, **unflushed `BufWriter`** losing the tail on drop |
| 8 | `logic-correctness` | always | **`Ord`/`Eq`/`Hash` inconsistency**, **adversarial trait impls** (user `Borrow`, `Deref`, `Clone` misbehaving; +has_unsafe), **closure panics** mid-operation (+has_unsafe), **float edge cases** (NaN, -0, infinity), **string comparison** pitfalls (case, normalization, non-constant-time on secrets), **serialized struct field mismatch**, **nondeterminism** (hash-map iteration, time, rand) where determinism is required, **mutating a collection key** |
| 9 | `ffi-cross-language` | has_ffi | **`CString` dangling pointer**, **ABI mismatch** (signature, calling convention), **`repr(C)` padding** leaking or mismatched, **opaque pointer** lifetime and null handling, **drop across the boundary** (freeing foreign memory with the wrong allocator), **closures** passed to C, **`dyn Trait`** across FFI |
| 10 | `layout-safety` | has_packed_repr | **references to packed fields** (unaligned, UB) |
| 11 | `async-runtime` | has_async | **blocking calls in async** (starves the executor), **cancel safety** (state lost when a future is dropped at an `.await`), **`select!` bias** starving a branch |
| 12 | `static-hygiene` | always | **lint config** missing hardening (`unsafe_op_in_unsafe_fn`, clippy lints), **MSRV** vs used APIs, **deprecated APIs** with known flaws |
| 13 | `resource-handling` | always | **raw fd lifecycle** (`from_raw_fd`, double close, leaks), **destructor skipped** (`mem::forget`, `ManuallyDrop`, leaks on early return) |
| 14 | `input-os-safety` | has_fs_io | **path traversal** via `Path::join` with absolute or `..` input, **TOCTOU** between check and use |
| 15 | `info-disclosure` | always | **pointer exposure** (addresses in logs, errors or serialized output defeating ASLR) |

Roughly 37 passes run on any audit; up to about 60 when every gate is open.
Low-value hardening gaps (lint config, MSRV) are still filed; the judge rates them LOW.
