---
name: agent-router
description: Decides which Codex subagent, OpenAI model and reasoning effort should handle a task before any work starts, so the coordinator spends the fewest tokens that still hold quality. Use this every time the user asks to implement, fix, refactor, test, review, investigate, document or plan anything, even when the task looks small (the router may answer "inline" for trivial work). Also use it when unsure whether to delegate at all or how many subagents to spawn, or when a request bundles several problems that might run in parallel (it decides whether to fan out and hands the split to dispatching-parallel-agents).
---

# Agent router (OpenAI Codex edition)

The main thread is the scarce resource: everything it reads is re-billed on every
turn, and quality drops as it fills. Delegating to a subagent moves the verbose part
(file reads, test output, exploration) into a disposable context and returns a
summary. The two cost levers are the **model tier** and the **reasoning effort**
(`low` < `medium` < `high` < `xhigh` < `max` for the recommended defaults).

Verified 2026-10-17. Standard API text prices in USD per 1M tokens; subscription
usage, long prompts and service tiers can differ.

| Tier | Model id | Input $/1M | Output $/1M | Relative input cost |
| --- | --- | --- | --- | --- |
| GPT-6 Luna | `gpt-6-luna` | 0.10 | 0.50 | 1x |
| GPT-6.1 Sol | `gpt-6.1-sol` | 2.00 | 10.00 | 20x |
| GPT-6 Astra | `gpt-6-astra` | 10.00 | 50.00 | 100x |

GPT-6.1 Sol replaces the older Terra/Sol routing defaults: use `high` for routine
changes and `xhigh` for complex changes. GPT-6 Sol remains available at $2/$10,
but GPT-6.1 Sol is the newer choice at the same base price. Cached input is 5% for
GPT-6.1 Sol and 10% for Luna/Astra. All three recommended models support `low`
through `max`; only Luna also supports `none`. Sol 6.1 rejects `none` and `minimal`.
Use the Responses API for tools. Details and URLs in
[references/sources.md](references/sources.md).

Check the host's available models and effort values before dispatching. A model in
the API catalog is not proof that the current Codex host or a pinned agent exposes
it. Keep an explicit user model choice; report unavailable choices instead of
inventing a model ID or silently substituting one.

Effort and model are pinned per agent in `.codex/agents/<name>.toml`
(`model`, `model_reasoning_effort`), with fallbacks in the `[agents]` table of
`config.toml`. Pick from the project's agents. If the project does not have them yet,
copy the templates in [assets/agents/](assets/agents/) into `.codex/agents/` and fill
in the project-specific placeholders (`<...>`).

## Bundled executable: apply YAML policy and quota budgets

Use the [bundled launcher](scripts/agent-router) before dispatching a nontrivial
task. Resolve it relative to this skill's actual directory, then run it with Bash
(Git Bash on Windows, not the WindowsApps/WSL bash shim):

```sh
bash "<absolute-skill-directory>/scripts/agent-router" --provider openai --task routine --daily-remaining 70 --weekly-remaining 8
```

In a full plugin, the launcher locates its bundled Rust sources and prepares a
compatible native runtime outside the plugin cache, compiling with Cargo only if
needed. The installer prepares it upfront for plugins and copied skills. A copied
skill uses its project runtime or the shared user runtime without needing the
original checkout. No PATH or shell-profile edits are required.

Default user path: Windows `%LOCALAPPDATA%/ai-skills/agent-router` (falling back
to `%APPDATA%`), macOS `~/Library/Application Support/ai-skills/agent-router`,
and Linux/other Unix `${XDG_DATA_HOME:-$HOME/.local/share}/ai-skills/agent-router`;
project install: `<project>/.ai-skills/agent-router`; `AI_SKILLS_ROUTER_HOME`
overrides either. The full plugin also discovers a nearby project runtime from
the current working directory. Existing custom `models.yaml` is preserved on
update; new defaults are offered as `models.yaml.dist`. Model edits need no rebuild.
[Build/install details](https://github.com/ffquintella/ai-skills/tree/main/tools/agent-router).

Percentages are **remaining**, not used. Supply only known values and restrict
`--available-models` to host-supported IDs. Apply returned model, effort, token and
context budgets, concurrency and optional delegation to the actual host; a
recommendation alone enforces nothing. At <=25% remaining use economy, at <=10%
extreme (YAML-configurable); exhausted applicable quota blocks routing. Unknown
or stale quota uses conservative economy. Security/capability floors remain
mandatory. Keep real window durations: 5h is not a daily limit. Use
`--quota-source codex` for a live read-only App Server query, or timestamped
`--quota-file`/`--quota-stdin` snapshots.

Exit 3 means quota blocked; exit 4 means no eligible model. Report either instead
of dispatching anyway. If preparing the runtime fails (for example Cargo/build
tools are missing), report the prerequisite and use the manual matrix below,
stating that quota-aware selection could not be applied. `--no-router` skips
installer preparation; it does not disable a later explicit launcher invocation.

## Step 1: classify the task

| Tier | Signals |
| --- | --- |
| **inline** | Answerable from what is already in context; one-line edit; a git or shell command whose output is short. A subagent costs more than doing it. |
| **lookup** | "Where is X", "how does Y work", "which files use Z". Read-only, no judgement about design. |
| **routine change** | Scope is clear, 1 to 3 files, an existing pattern to copy (new endpoint like an existing one, a new test for a known case, a config field). |
| **complex change** | Multi-file, new abstraction, unclear approach, or touches security-sensitive code (authentication, authorization, secrets, connection pooling, the startup/composition root, configuration schema). Also: a bug nobody has localised yet. |
| **review / security** | Judge an existing diff or design against the project rules (AGENTS.md). No edits. |
| **verify** | Run the build or a test filter and report only failures. |
| **plan** | The user wants a plan or an architecture decision, not code yet. |

When two tiers fit, take the cheaper one and rely on the escalation ladder below.

## Step 2: select agent, model and effort

| Tier | Agent | Model | Effort | Sandbox | Parallelism |
| --- | --- | --- | --- | --- | --- |
| inline | none (coordinator does it) | current | current | current | 1 |
| lookup | `scout` | `gpt-6-luna` | low | read-only | 1, or 2 to 3 only for independent questions |
| routine change | `builder` | `gpt-6.1-sol` | high | workspace-write | 1 |
| complex change | `architect` | `gpt-6.1-sol` | xhigh | workspace-write | 1 (split into independent `builder` sub-tasks only if the architect's plan says so) |
| review / security | `reviewer` | `gpt-6.1-sol` | high (xhigh for security-sensitive paths: auth, secrets, rate limiting) | read-only | 1 |
| verify | `test-runner` | `gpt-6-luna` | low | workspace-write (needs to run the build) | 1 |
| plan | coordinator in plan mode, or `architect` with the instruction "plan only, no edits" | inherits | inherits | read-only | 1 |

Why these defaults: keep focused lookups and verification on Luna at `low`, and
use Sol 6.1 for implementation and review. Routine and complex work now share a
model but differ in effort. Try `medium` on mechanical builder work only after
measuring that it preserves quality; these routing defaults are project policy,
not a benchmark result for the new models.

Use `gpt-6-astra` only when the user asks for it by name or an `architect` run at
`xhigh` failed on a frontier problem (novel algorithm, deep concurrency bug).
It costs 5x Sol 6.1 at base input and output rates and does not accept `none`.

For security review, set `model_reasoning_effort = "xhigh"` in the reviewer
agent definition before dispatch when the host gives pinned values precedence.
A spawn-time request alone does not override a pinned agent setting.

### Lookups: query the code graph first when one exists

[graphify](https://github.com/Graphify-Labs/graphify) (installed by `install.sh` as an
external skill) keeps a knowledge graph of the repository in `graphify-out/graph.json`.
Before routing a lookup, check for that file (one `ls`, inline).

- **Graph present**: route to `scout` as usual and say in the brief that the graph comes
  first. Pick the command by question shape, all against the local graph:

  | Question | Command |
  | --- | --- |
  | "How does Y work", broad context | `graphify query "<question>" --budget 1500` |
  | One symbol: what it is, who uses it | `graphify explain "<Symbol>"` |
  | "How does A reach B" | `graphify path "<A>" "<B>"` |
  | "Which files use Z", impact of a change | `graphify affected "<Z>"` |

  `scout` then opens only the `path:line` ranges the graph names, to confirm. Edges
  tagged `EXTRACTED` come straight from the source; `INFERRED` edges are graphify's
  resolution and must be confirmed in the code before they are reported as fact. Exit
  code 3 means an ambiguous name (retry with `<path>::<symbol>` from the listed
  candidates), 4 means no node matched: fall back to grep and say so.
- **Graph stale** (older than the last commit, or the files in question have
  uncommitted edits): run `graphify update .` inline first. It re-parses code only,
  locally, with no LLM call. `scout` never builds or updates the graph itself.
- **No graph**: plain grep and reads. Do not build a graph for a single lookup; when
  the user keeps asking architecture questions about a large repository, suggest
  building one (`$graphify .`) and let them decide, since the docs/media pass calls a
  model.
- **Requests about the graph itself** ("map this repo", `$graphify`, `--update`,
  exports, hooks) are not lookups: the coordinator follows the graphify skill directly.

If the project also uses Cortex's code graph (`unified_search`, see the
`cortex-memory` skill), use one per project: graphify when `graphify-out/` exists,
otherwise Cortex. Do not query both for the same question.

## Step 3: one subagent or several

Default to one subagent. Fan out only when the request holds 2 or more problems that
pass all four checks:

- each can be understood without the others;
- fixing one cannot plausibly fix or change another (otherwise they share a root cause);
- they do not edit the same files or share a resource (database, port, fixture, lock
  file, generated output);
- you already know what is broken; exploratory "something is wrong somewhere" work stays
  in one subagent or the coordinator.

If any check fails, one subagent works through the problems in order, or investigates
the group first and splits afterwards. If all pass, hand the split to the
`dispatching-parallel-agents` skill: it groups the problems into independent domains,
writes one self-contained brief per domain and integrates the results. Route each domain
through Steps 1 and 2 on its own, so a lookup domain gets `scout` while a sibling
complex domain gets `architect`.

Never spawn more subagents than there are independent domains: simple fact 1 agent,
comparison 2 to 4, and 10+ only for broad research. For code changes keep
`agents.max_concurrent_threads_per_session` at 3 to 5 and run the rest in waves.
Dependent steps run in one agent sequentially, not in several.

## Step 4: write the delegation brief

Vague briefs make subagents redo each other's work or misread the goal. Every brief
has:

1. **Objective**: one sentence of what "done" means.
2. **Boundaries**: files or directories in scope, what not to touch, AGENTS.md rules that apply (auth conventions, endpoint catalogues, routing, no secrets in repo).
3. **Verification target**: the exact command that must pass, taken from the project's build and test section (for security-sensitive changes, always include the project's authentication or security test filter).
4. **Output contract**: what to return and how long. Default: a summary under 30 lines with file paths and line numbers, then the verification output trimmed to failures. Never "paste the whole file".

Name the agent explicitly in the request ("use the `builder` agent to ...") so Codex
does not fall back to the built-in `default`/`worker`/`explorer` roles. Preface the
delegation with the routing decision so it is visible in the transcript:

```
router: tier=<tier> agent=<agent> model=<model> effort=<effort> agents=<n> verify=<command>
```

When fanning out, print one line per domain with `domain=<name>` added, all of them
before the single request that spawns the subagents.

## Step 5: verify, then escalate one rung at a time

Read the agent's evidence (test output, build exit code). If it fails or the answer is
shallow, do not retry at the same level: climb one rung.

```
scout (luna low) -> builder (sol 6.1 high) -> architect (sol 6.1 xhigh) -> architect with model = "gpt-6-astra"
```

Escalate with the failure attached to the brief, so the next agent does not rediscover
it. Two failures at the top rung means the task, not the agent, needs re-scoping: stop
and ask the user.

After a fan-out, escalate each failing domain on its own and leave the green ones alone.
Then run the full build and suite once (through `test-runner`): per-agent greens do not
prove the combination. If the combined run fails, the domains were not independent;
stop dispatching and debug the interaction in one subagent.

## Coordinator habits that keep this cheap

- Do not read large files or run the full test suite without a filter in the main thread when a subagent can return the summary instead.
- Ask for evidence, not assurances: the failing test names, the command and its exit code.
- Prefer one well-briefed subagent over several thin ones; every subagent re-loads AGENTS.md, the skills list and the tool list.
- Independent subagents are requested together so they run concurrently; dependent ones wait.
- Lock every agent that does not need to write files to `sandbox_mode = "read-only"`; subagents inherit the parent's approval policy, so an approval-gated edit in a subagent may be denied silently. Keep edits in `builder`/`architect` and check their reported diff with `git diff`.
- If the router says `inline`, just do it. Explaining why you did not delegate wastes more than the delegation would have saved.
