# YAML and quota schema, version 1

The executable strictly deserializes YAML with serde: unknown fields, missing
required fields and invalid value types fail. `models.yaml` is the canonical full
example, read at runtime. There is no compiled model-ID fallback.

| Top-level field | Contents |
| --- | --- |
| `schema_version` | Integer 1; unsupported versions fail |
| `effort_order` | Unique nonempty effort names, cheapest/lowest first |
| `reference_workload` | Positive `input_tokens` and `output_tokens`, used for cost ranking when estimates are absent |
| `quota_policy` | Positive `snapshot_ttl_seconds`; percentages `0 < extreme_remaining_percent < economy_remaining_percent < 100` |
| `modes` | Exactly `normal`, `economy`, `extreme` budgets |
| `tasks` | Nonempty map of task names to requirements |
| `providers` | Nonempty map of provider names to model catalogs |

Each mode has positive `max_output_tokens`, `context_budget_tokens` larger than
output, positive integer `concurrency`, and boolean `optional_delegation`.
Economy modes cannot increase budgets, effort or optional delegation relative to
the preceding mode. Extreme must use concurrency 1 and disable optional delegation.

Each task has positive `min_tier`, unique `required_capabilities`, `min_effort`,
`preferred_effort` (exactly one defined effort for each mode), and `security`.
Security has `min_tier`, `min_effort`, `required_capabilities`; its tier/effort
cannot be below base requirements. Security capabilities are added to base ones.
A task may add `specified`, used only with `--spec-complete`: `min_tier`,
`min_effort` and `preferred_effort` (one per mode, not increasing in economy),
none above the task's own values. It replaces the base tier and effort minimums;
capabilities and security floors are unchanged. Omit it for tasks a specification
does not make easier (lookup, verify, review).
Tier is a numeric policy judgment, not inferred from a model name. Lower mode
effort cannot violate the minimum. A model with fewer supported effort levels is
assigned the closest supported value at/below the preference that meets the floor,
or the lowest supported value above the preference if necessary.

Each provider has `models`, a nonempty list. Each model has:

| Field | Type and constraints |
| --- | --- |
| `id` | Nonempty string, unique in the provider |
| `enabled` | Boolean; disabled entries never compete |
| `tier` | Positive integer |
| `capabilities` | Unique nonempty capability strings |
| `supported_efforts` | Nonempty unique subset of `effort_order` |
| `quota_buckets` | Unique bucket IDs; empty list permits provider-wide quotas only |
| `context_tokens` | Positive model context ceiling, larger than max output |
| `max_output_tokens` | Positive model output ceiling |
| `prices` | Finite nonnegative `input`, `cached_input`, `output` USD/1M; cached input <= input |
| `price_bands` | List sorted by strictly increasing `above_input_tokens`, each with complete `prices` |

The final matching price band applies when input tokens are strictly greater than
its threshold. Price affects the whole request. Ranking uses uncached input/output
cost; `cached_input` is retained as catalog data for transparent maintenance.
No dependency between IDs and model generations is compiled into selection.

## Normalized quota JSON

Root: `provider` (nonempty string), `observed_at` (optional nonnegative integer
Unix seconds), `windows` (list). Each window permits only:

- `name`: optional nonempty string; defaults to its actual duration label.
- `remaining_percent`: optional finite 0..100 number.
- `duration_minutes`: optional positive integer.
- `resets_at`: optional nonnegative integer Unix seconds.
- `bucket`: optional nonempty string; null/absent means provider-wide.

A missing percentage or duration produces a warning and ignores that incomplete
window. Invalid types, out-of-range values and unknown normalized fields fail.
Snapshots over 4 MiB fail. A window is usable only with a fresh, non-future
observation timestamp and a reset time still in the future if one is given.
Different providers and unmatched model buckets never affect a model's decision.

Native wrapper: `{"observed_at":<Unix seconds>,"payload":<native object>}`.
Only these wrapper fields are accepted. Native fields not consumed by the adapter
are ignored for forward compatibility; known malformed fields fail. Codex payloads
may be the full JSON-RPC response or its `result`, containing `rateLimitsByLimitId`
or legacy `rateLimits`; `primary`/`secondary` use `usedPercent`,
`windowDurationMins`, `resetsAt`. Multi-bucket entries win when supplied. Claude
statusline uses `rate_limits.five_hour`/`seven_day`, with `used_percentage` and
`resets_at`. Rates may be null or partial, and remain unknown as appropriate.

`--daily-remaining` and `--weekly-remaining` replace only the chosen provider's
windows of duration 1440/10080 respectively and are fresh current assertions.
Other durations/buckets/providers are retained. Live Codex RPC receives a current
observation time directly; stdin/file native data needs an observation timestamp.
