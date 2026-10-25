# Agent router CLI

Select the cheapest available model that meets a task's configured quality floors.
The decision is local: no LLM calls, inference, tokens or API keys are needed for
selection. Models, prices, effort, quality floors and token budgets live in the
editable [models.yaml](models.yaml). The [schema reference](SCHEMA.md) explains it.

## Install and run

### Through the ai-skills plugin or installer

The plugin bundles the Rust source, default YAML and launchers. From the checkout:

```sh
./install.sh --all --plugin --no-external
./install.sh --all --skills --project /path/to/project --no-external
bash scripts/agent-router -- --provider openai --task routine --weekly-remaining 8
```

Windows: `./install.ps1 --all --plugin --no-external` in PowerShell (Git for Windows
required), then invoke the printed `.exe` path directly. For shell launchers use
Git Bash, not a WSL `bash` shim. The existing PowerShell installer shares the Bash
implementation. `--no-router` explicitly skips router preparation; `--help` and
`--list` never compile or initialize it. `--no-external` skips third-party tools,
and keeps this bundled runtime enabled.

Source/plugin launchers prepare a runtime outside the plugin tree. They reuse a
matching installed build, prefer a compatible current local release binary, and
otherwise run `cargo build --locked --release` for the detected host target. Cargo
and native platform build tools are required when compilation is needed; Rust is
not installed automatically. `AI_SKILLS_ROUTER_BINARY` can point to a trusted
matching native binary; its reported version must match the crate. Build output
goes to stderr so JSON stdout remains clean.

Runtime paths:

- User: Windows `%LOCALAPPDATA%/ai-skills/agent-router` (falling back to
  `%APPDATA%`); macOS `~/Library/Application Support/ai-skills/agent-router`;
  Linux/other Unix `${XDG_DATA_HOME:-$HOME/.local/share}/ai-skills/agent-router`.
- Project installer: `<project>/.ai-skills/agent-router`.
- `AI_SKILLS_ROUTER_HOME` overrides either; source launcher `--runtime-dir PATH`
  also selects an explicit destination.

Launchers first discover an existing runtime in the nearest enclosing project
from the current working directory. Copied skill launchers then try their
installation's project runtime and the user runtime, without depending on the checkout.
Both vendors share one runtime for a given scope. Keep using the same override
when launching a skill installed with a nondefault runtime. No PATH or profile
files are changed. `--no-router` does not disable a later explicit launcher call.

Preparation is serialized. Cargo sources/lockfile changes invalidate the cached
build; YAML-only changes do not. Failure leaves the previous installed binary and
policy intact. The runtime contains `build/` for Cargo's incremental build cache,
which is larger than the executable. A custom `models.yaml` is preserved; updated
defaults are saved as `models.yaml.dist`. An unmodified managed policy refreshes
automatically. A source fingerprint detects changes; it is not an authenticity
signature for third-party binaries.

### Standalone archive

Download the artifact for your OS/CPU from the **Agent router CLI** GitHub Actions
workflow after a successful run. Verify the accompanying SHA256 and extract the
zip. Keep `agent-router` (`agent-router.exe` on Windows) and `models.yaml` together.
No Rust, Python or Node runtime is required to run the binary. Add its directory to
PATH if desired. On Linux/macOS, `chmod +x agent-router` if your unzip tool drops
the executable permission. macOS binaries are unsigned and not notarized.

```sh
agent-router --provider openai --task routine --daily-remaining 70 --weekly-remaining 8
agent-router --provider anthropic --task review --security-sensitive --weekly-remaining 5
agent-router --provider openai --task complex --available-models gpt-6.1-sol,gpt-6-astra
agent-router --provider openai --task lookup --matrix /path/to/models.yaml --format text
```

In PowerShell, use `./agent-router.exe` when the executable is in the current
directory. Tasks are explicit `lookup`, `routine`, `complex`, `review` and `verify`;
the YAML can add tasks and providers. The tool does not guess task complexity from
natural language. Model tier/capability assignments are policy judgments, not
benchmark guarantees. Restrict `--available-models` to what your host actually
offers; YAML catalog membership alone does not prove account access.

## Economy behavior

Economizing is always an objective: candidates are ranked by uncached input/output
API cost, using explicit estimates or the YAML reference workload (4000 input,
1000 output tokens). A lexicographic model-ID tie break makes runs deterministic.
`--input-tokens` and `--output-tokens` are optional; a missing estimate uses the
reference value for ranking. Dollar estimates appear only if at least one estimate
was supplied, with assumptions in the output. Price bands apply above the listed
input threshold to the whole request. Prices exclude tools, reasoning overhead,
cache writes, regional/service premiums and subscription quota accounting.

Default modes use the lowest known remaining percentage applicable to each model:

| Remaining | Mode | Max output | Context budget | Concurrency |
| --- | --- | --- | --- | --- |
| More than 25% | normal | 8192 | 128000 | 2 |
| At most 25%, or no known quota | economy | 2048 | 32768 | 1 |
| At most 10% | extreme | 768 | 8192 | 1 |
| 0% | blocked | 0 | 0 | 0 |

YAML configures these thresholds and budgets. Extreme disables optional delegation.
Effort never drops below task/security floors. Explicit workload estimates must fit
the selected mode and model; incompatible requests fail instead of silently losing
input. Returned output budgets also reserve room inside the context ceiling.
An exhausted model bucket can leave another eligible model available; a depleted
provider-wide window blocks every model it covers. Providers never switch silently.

The executable returns a recommendation. The calling agent must apply its `model`,
`effort`, `max_output_tokens`, `context_budget_tokens`, `concurrency` and
`optional_delegation` values, respecting the host's supported settings. It does not
rewrite pinned agent templates or enforce limits inside another running process.

## Quota inputs

`--daily-remaining` and `--weekly-remaining` mean **percentage remaining**, not used,
and accept 0..100. They are current caller assertions. Automatic/native usage fields
mean percentage **used**, so the adapters subtract them from 100. Five-hour windows
stay five-hour windows; no adapter invents a daily limit for an account.

Use one source: `--quota-file PATH`, `--quota-stdin`, or `--quota-source codex`.
Manual percentages may accompany any source; they replace windows of the same
duration for that provider, leaving other windows active. Daily is 1440 minutes;
weekly is 10080. Provider-wide windows cover all its models. A bucket ID applies
only to models whose YAML `quota_buckets` contains that ID. Unknown buckets are
reported and ignored; update mappings from actual host documentation when needed.

### Live Codex query

```sh
agent-router --provider openai --task routine --quota-source codex
agent-router --provider openai --task lookup --quota-source codex --codex-path /path/to/codex
```

Requires an installed native Codex executable already logged into a supported
account. This uses the official [App Server](https://learn.chatgpt.com/docs/app-server)
`initialize`, `initialized`, `account/rateLimits/read` protocol. It starts no
inference, reads no credential files and never consumes earned quota-reset credits.
It prefers the multi-bucket `rateLimitsByLimitId` response over the legacy view.
Timeout is 10 seconds, configurable with `--quota-timeout-seconds 1..120`. The child
is terminated and reaped on every outcome. Protocol output is bounded to 4 MiB and
server error text is not echoed. Explicit query failures return exit 5; they do not
pretend the quota is full or silently fall back to supplied percentages.

Windows npm installations are searched for their native `codex.exe` under supported
vendor layouts. `--codex-path` accepts the native executable, not a `.cmd`, `.bat`
or `.ps1` shim, so shell interpolation and wrapper-process leaks are avoided.
If discovery fails, point it to the native executable in your Codex installation.

### Normalized snapshots

```json
{"provider":"openai","observed_at":1792242000,"windows":[{"name":"daily","remaining_percent":20,"duration_minutes":1440,"bucket":null}]}
```

`observed_at` must be the **actual observation time** in Unix seconds; the number
above illustrates the shape and must not be copied as a current snapshot. Optional
`resets_at` is also Unix seconds. Without observation time, after the default
300-second TTL, in the future, or after a reset, a window is unusable and generates
a warning. No usable applicable windows means conservative economy. A reset time
in the past is not evidence that the account has replenished its quota.

Native Codex response/result or Claude statusline JSON can be wrapped as:

```json
{"observed_at":1792242000,"payload":{"rate_limits":{"five_hour":{"used_percentage":95},"seven_day":{"used_percentage":70}}}}
```

Then pass it to `--quota-file` or `--quota-stdin`. A native payload without a fresh
timestamp remains unknown. Capture a timestamp when observing the source; do not
retimestamp an old snapshot to make it look fresh.

Claude Code's documented [statusline](https://code.claude.com/docs/en/statusline)
provides `rate_limits.five_hour` and `rate_limits.seven_day` on supported accounts
after the first API response. The router reads this supplied JSON, not a private
Claude HTTP endpoint. An optional POSIX statusline pipeline using `jq` can wrap
the live stdin (`jq` is needed only by this example):

```sh
jq -c '{observed_at: (now | floor), payload: .}' |
  agent-router --provider anthropic --task routine --quota-stdin --format text
```

Do not install that as your statusline automatically; choose a task that reflects
the decision you are making. Rate limits may be absent for an account or early in
a session; the resulting unknown quota is reported honestly.

## Output and exit codes

JSON is the default, one object per line. Decisions include provider, task, model,
effort, mode, reason, quota windows/warnings, optional estimated API cost, assumptions
and resource budgets. A blocked decision has `model: null` and no executable budget.
`--format text` prints a brief decision and sends warnings to stderr.

| Exit | Meaning |
| --- | --- |
| 0 | Model selected; `--help`/`--version` also exit 0 |
| 2 | Invalid CLI, YAML, quota input or missing file |
| 3 | Applicable quota exhausted, no usable eligible model |
| 4 | No model meets availability, capabilities, effort or budget requirements |
| 5 | Explicit Codex query failed, timed out or returned invalid data |

Errors are JSON `{"error":{"code":"...","message":"..."}}`. The CLI never
includes raw quota-file content or server diagnostics in error messages.

## Build and verify

Requires Rust 1.89 or newer for development (stable recommended):

```sh
cd tools/agent-router
cargo test --locked
cargo fmt --check
cargo clippy --locked --all-targets -- -D warnings
cargo build --locked --release
# Use an explicit matrix when running a bare Cargo build:
./target/release/agent-router --matrix models.yaml --provider openai --task lookup
```

From the repository root, package a native Windows build (Python is build tooling
only; replace target/executable for other platforms):

```sh
python scripts/package-router.py --target x86_64-pc-windows-msvc --binary tools/agent-router/target/release/agent-router.exe
python scripts/tests/smoke_package_router.py --target x86_64-pc-windows-msvc
```

The workflow tests/lints/builds natively on Windows, Linux and macOS for x86_64 and
arm64, packages YAML and documentation beside the binary, and smoke-tests each
archive outside the checkout. Artifacts are not GitHub releases. Linux GNU builds
use the hosted Ubuntu runner's glibc; older distributions may need a local build.
Tests use simulated Codex protocol responses, not live accounts. CI execution is
required before claiming native validation on platforms other than the local host.
