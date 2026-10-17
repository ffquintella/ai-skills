# Agent router executable implementation

Approved spec: ../specs/2026-10-17-agent-router-cli-design.md (user approved
implementation in chat). Execute in the existing checkout on codex/agent-router-cli,
preserving all previous model-matrix edits. No commit, push or publication requested.

## Interfaces and ownership

One Rust crate at tools/agent-router, binary agent-router. The implementation agent
owns Cargo.toml/Cargo.lock, src/, tests/, models.yaml and a schema reference in
SCHEMA.md. Coordinator owns README, CI workflow, packaging script, vendor skill
integration, version and verification artifacts. Do not share editing ownership.

CLI required contract: --provider openai|anthropic --task
lookup|routine|complex|review|verify, --matrix PATH, --security-sensitive,
--available-models comma,list, --input-tokens, --output-tokens,
--daily-remaining, --weekly-remaining, --quota-file, --quota-stdin,
--quota-source codex, --format json|text. Default matrix beside executable.
JSON errors/exit codes and freshness semantics follow the spec. Missing individual
token estimates use the reference workload for ranking; only expose an estimate
when at least one explicit estimate was passed, and label assumptions.

Configuration top level: schema_version, reference_workload, quota_policy, modes,
tasks, providers. All types reject unknown fields and invalid combinations. Models
list ID, enabled, capability tier, capabilities, supported efforts, quota buckets,
prices and price bands. Tasks declare capability/tier/minimum effort/security
floors and preferred efforts by mode. Modes declare output/context budgets,
concurrency and optional delegation. Nested concrete fields are documented in
SCHEMA.md alongside the implemented types. Capability floor precedes economy.
Respect model-specific context/output ceilings and never recommend context/output
budgets below explicit estimates; report a conflict if the mode cannot accommodate
the requested workload. Capabilities/tiers/efforts are policy data, not model-name
heuristics. Native host adapters preserve real window lengths and bucket IDs.

## Task 1: implement CLI, policy and quota readers

Tier: complex, default agent with current Sol at xhigh (schema and subprocess work).
Write executable integration tests first against a minimal compiling placeholder
binary, run and record expected assertion failures before implementing behavior.
Use Rust serde, serde_json, serde-saphyr and clap; minimize other dependencies.
Keep pure selection and quota parsing testable with explicit current Unix time.
Codex subprocess uses initialize/initialized/account/rateLimits/read, a total
timeout, bounded output, hidden Windows process, and kill/wait on every path.
Native adapters use fixtures; no credentials or network required for tests.
Add a fake app-server subprocess fixture for success/error/timeout tests.

Verification: cargo test --locked; cargo fmt --check; cargo clippy --locked
--all-targets -- -D warnings. Tests must include dynamic YAML model replacement,
unsupported/empty/malformed config, availability, tie break, price bands,
security floors, threshold 25/10/0, unknown/stale/future/reset snapshots, partial
overrides, provider and bucket isolation, malformed native payloads, missing matrix,
compact JSON, text, help, conflicting flags, adapter timeout and protocol errors.

## Task 2: packaging and skill integration

Tier: routine coordinator work, independent of crate internals above.
Create .github/workflows/agent-router.yml with native builds/tests/lints on Windows,
Linux, macOS for x86_64 and arm64, artifacts named by Rust target; trigger relevant
paths and workflow_dispatch; no release publishing or secrets.
Create scripts/package-router.py (stdlib) copying executable, models.yaml, README,
SCHEMA.md into a target-named zip and SHA256 checksum, no shell interpolation.
Document build, install, JSON schema, source freshness wrapping, quota commands and
limitations. Both SKILL.md twins explain executable usage and caller responsibility
to apply budgets. Use plugin version 0.3.0 (new executable capability).

## Task 3: verify and review

Tier: verify/test-runner, then fresh reviewer for whole uncommitted implementation.
Run full suite, fmt/clippy, Windows release build; package and exercise extracted
binary without --matrix to prove sibling YAML discovery. Demo normal/economy/extreme,
security and blocked modes. Optionally query live Codex read-only if available.
Check version agreement, diff whitespace and skill links. Reviewer reads spec,
plan, crate, docs and workflow using git diff plus untracked files.

Review focus: quota buckets must not leak between models/providers; invalid or
stale data must not look like full quota; mode must not bypass safety floors;
subprocess cleanup/timeouts on all paths; distribution must work outside repo.
Fix material findings with failing regression tests and rerun all checks. Report
Windows evidence and explicitly mark Linux/macOS validation as CI pending.
