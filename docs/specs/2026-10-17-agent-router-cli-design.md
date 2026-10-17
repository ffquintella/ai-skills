# Agent router CLI

Status: approved by the user in chat on 2026-10-17. User requirements: a small executable for Linux,
Windows and macOS; editable YAML decision matrix; quota supplied as parameters or
queried; continuous cost reduction and extreme token economy near quota exhaustion.
Implementation choices below are proposed by the coordinator.

## Delivery

Implement in Rust, whose toolchain is already available here. Ship native binaries
through a CI build matrix for Windows, Linux and macOS, x86_64 and arm64. No Python,
Node or language runtime required on the target machine. Build and run Windows
locally; do not claim Linux/macOS runtime validation without those CI runs.
Source lives in tools/agent-router, with a Cargo lockfile, tests and README.
Name the executable agent-router (.exe on Windows). Archives contain the binary,
models.yaml and README; default discovery is beside the resolved executable.
No automatic PATH or host configuration edits. CI artifacts are downloadable;
publishing a GitHub release is outside this change.
Both vendor skills document invocation. A single canonical models.yaml ships next
to the executable; --matrix selects any other file. Missing YAML is an error,
not a hidden fallback to a compiled model catalog. Package archives include it.

## Inputs and output

CLI accepts --provider openai|anthropic, --task lookup|routine|complex|review|verify,
--security-sensitive, optional --available-models, --input-tokens and
--output-tokens estimates, plus quota inputs below. Task classification is explicit,
avoiding an LLM call or unreliable natural-language classification. No inference,
automatic task execution, credential collection or modification of host settings.
Default output is compact JSON: model, effort, mode, reason, quota status,
estimated API cost when estimates were supplied, recommended max output tokens,
context budget and concurrency. Optional --format text prints a brief explanation.
Token recommendations only take effect when the calling agent applies them.

## YAML policy

Versioned, strictly validated schema: providers, models, supported effort values,
input/output/cache prices (including prompt-size bands), enabled status, capability
tiers, task requirements, security minimums and economy-mode policies. IDs, prices,
thresholds, effort, budgets and task mappings change in YAML without recompiling.
Seed from the current verified skill matrices, retaining Astra/Fable for escalation.
Choose the cheapest enabled, available model satisfying the task's minimum tier
and capabilities, using estimated input/output cost when supplied, otherwise a
documented YAML reference workload. Stable ID ordering breaks ties.
Do not trade away security minimums or required capabilities to save quota.
An empty eligible set returns an actionable error rather than inventing a model.

## Quotas and economy

Accept --daily-remaining and --weekly-remaining percentages (0..100). Also accept
--quota-file JSON, --quota-stdin and --quota-source codex. Sources are mutually
exclusive, except explicit percentages override the matching source windows.
JSON supports a normalized window list and documented native host payloads.
Codex adapter starts codex app-server, performs initialization, calls
account/rateLimits/read, and closes the child with a bounded timeout. Prefer
rateLimitsByLimitId; retain bucket IDs, duration, reset timestamp and source.
Claude adapter reads the statusline JSON from stdin/file, including rate_limits
five_hour/seven_day; it does not scrape credentials or private HTTP endpoints.
Daily means 1440 minutes, weekly means 10080; other windows retain their actual
duration and also influence economy. Never relabel 5h as daily.
Unknown quota stays unknown. If no valid window is known, select conservative
economy rather than assuming 100% remains. Missing or stale windows are reported.
Snapshots expire by a YAML TTL (proposed 5 minutes); past reset data is unknown,
not proof of a replenished quota. Malformed percentages are errors.

Modes are YAML-configurable: normal above 25% remaining, economy at or below 25%,
extreme at or below 10%; use the lowest remaining percentage among applicable
windows. At zero, return a blocked decision with no selected model. Quotas are
provider/bucket-specific; unrelated model buckets must not throttle every model.
Extreme selects the cheapest capable model, lowers effort only to the task's
configured minimum, recommends short output/context budgets and concurrency 1,
and disables optional delegation. If quality floors require an expensive model,
say so explicitly. API-dollar estimates are not subscription-quota forecasts.
Provider selection is explicit; no silent switch to another account/provider.

### Concrete defaults and contracts

Reference workload: 4000 input and 1000 output tokens, configurable in YAML.
Model quota_buckets maps explicit host bucket IDs to models; unrecognized bucket
IDs are reported and ignored for selection. Provider-wide normalized windows apply
to every model of that provider. Seed Codex models with the documented codex bucket;
Claude five_hour/seven_day are provider-wide. Multiple applicable windows use the
minimum remaining value; no matching windows means unknown, conservative economy.
An explicit daily/weekly percentage replaces only windows of that exact duration
for the selected provider and applies provider-wide. Other windows remain active.
No explicit timestamp means a CLI percentage is a current caller assertion.

Normalized JSON: {"provider":"openai","observed_at":<Unix seconds>,"windows":[
{"name":"daily","remaining_percent":12,"duration_minutes":1440,
"resets_at":<optional Unix seconds>,"bucket":<optional ID>}]}.
Native Codex input accepts the account/rateLimits/read result or full JSON-RPC
response; native Claude input accepts the statusline object. Snapshot inputs need
observed_at in a wrapper to establish freshness; absent freshness means unknown.
Partial valid windows can still be used, with missing fields reported; invalid
types/ranges are errors. Unknown normalized/schema fields are rejected.
Exit codes: 0 selected, 2 invalid input/config, 3 quota blocked, 4 no eligible
model, 5 adapter failure. Output errors as JSON with error code and message,
without subprocess credential/log contents. Stale/unknown quotas yield economy
with warnings, not exit errors; an explicitly requested adapter failure is exit 5.
Codex RPC timeout defaults to 10 seconds; implement the documented initialize /
initialized handshake and always reap the subprocess. Exact internal interfaces
and YAML field layout belong in the implementation plan, preserving these rules.

## Verification

Tests cover YAML validation, model replacement without recompilation, cheapest
eligible selection, availability filtering, security floors, cost bands, quota
threshold boundaries, zero/unknown/stale/reset quotas, source precedence, real
window durations, provider/model bucket isolation and timeout/error paths.
Use fixtures for external responses and subprocess tests for CLI JSON/exit codes.
CI runs tests and release builds natively on all supported OS/architecture pairs.
Document official quota-source links, CLI examples, build commands and limitations.

## Sources checked 2026-10-17

- https://learn.chatgpt.com/docs/app-server (account/rateLimits/read)
- https://code.claude.com/docs/en/statusline (rate_limits JSON fields)
- openai/agent-router/references/sources.md and Claude twin for model catalog.
