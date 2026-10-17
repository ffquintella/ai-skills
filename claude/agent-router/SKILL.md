---
name: agent-router
description: Decides which agent, Claude model and effort level should handle a task before any work starts, so the coordinator spends the fewest tokens that still hold quality. Use this every time the user asks to implement, fix, refactor, test, review, investigate, document or plan anything, even when the task looks small (the router may answer "inline" for trivial work). Also use it when unsure whether to delegate at all or how many agents to spawn, or when a request bundles several problems that might run in parallel (it decides whether to fan out and hands the split to dispatching-parallel-agents).
argument-hint: [one-line task description]
---

# Agent router (Claude Code edition)

The main conversation is the scarce resource: everything it reads is re-billed on
every turn, and quality drops as it fills. Delegating to an agent moves the verbose
part (file reads, test output, exploration) into a disposable context and returns a
summary. The two cost levers are the **model tier** and the **effort level**
(`low` < `medium` < `high` < `xhigh` < `max`).

Verified 2026-10-17. Standard Claude API text prices in USD per 1M tokens;
subscription usage and partner pricing can differ.

| Tier | Model id | Input $/1M | Output $/1M | Relative input cost |
| --- | --- | --- | --- | --- |
| Haiku 5.5 | `claude-haiku-5-5` | 0.10 / 0.50 | 0.50 / 2.50 | 1x / 5x |
| Sonnet 5.5 | `claude-sonnet-5-5` | 2.00 | 10.00 | 20x |
| Opus 5.5 | `claude-opus-5-5` | 4.00 | 20.00 | 40x |
| Fable 5.1 | `claude-fable-5-1` | 10.00 | 50.00 | 100x |

Haiku's first price applies to prompts up to 100,000 tokens; the second applies
over that threshold. Relative costs use short-prompt Haiku as the baseline.
Haiku 5.5 now supports all five effort levels and defaults to `medium`, as does
Opus 5.5. Sonnet 5.5 and Fable 5.1 default to `high`. Use `low` for short Haiku
lookups and command execution, and raise it for longer instruction-heavy work.
Details and URLs in [references/sources.md](references/sources.md).

Check host access before dispatching. These are general-purpose routing models;
specialized or restricted models are not automatic escalation targets. Preserve an
explicit user model choice. Templates pin full IDs so aliases cannot move the
routing matrix to a different version without review.

For Claude Code routing, pin effort in the agent definition so the project ships
one agent per tier in `.claude/agents/`. Pick from those. If the project does not have
them yet, copy the templates in [assets/agents/](assets/agents/) and fill in the
project-specific placeholders (`<...>`).

## Bundled executable: apply YAML policy and quota budgets

Use the [bundled launcher](scripts/agent-router) before dispatching a nontrivial
task. Resolve it relative to this skill's actual directory, then run it with Bash
(Git Bash on Windows, not the WindowsApps/WSL bash shim):

```sh
bash "<absolute-skill-directory>/scripts/agent-router" --provider anthropic --task routine --daily-remaining 70 --weekly-remaining 8
```

In a full plugin, the launcher locates its bundled Rust sources and prepares a
compatible native runtime outside the plugin cache, compiling with Cargo only if
needed. The installer prepares it upfront for plugins and copied skills. A copied
skill uses its project runtime or the shared user runtime without needing the
original checkout. No PATH or shell-profile edits are required.

Default user path: `${XDG_DATA_HOME:-$HOME/.local/share}/ai-skills/agent-router`;
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
`--quota-file` or `--quota-stdin` with a freshly timestamped Claude Code statusline
snapshot.

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
| **review / security** | Judge an existing diff or design against the project rules (AGENTS.md / CLAUDE.md). No edits. |
| **verify** | Run the build or a test filter and report only failures. |
| **plan** | The user wants a plan or an architecture decision, not code yet. |

When two tiers fit, take the cheaper one and rely on the escalation ladder below.

## Step 2: select agent, model and effort

| Tier | Agent | Model | Effort | Parallelism |
| --- | --- | --- | --- | --- |
| inline | none (coordinator does it) | current | current | 1 |
| lookup | `scout` | `claude-haiku-5-5` | low | 1, or 2 to 3 only for independent questions |
| routine change | `builder` | `claude-sonnet-5-5` | high | 1 |
| complex change | `architect` | `claude-opus-5-5` | xhigh | 1 (split into independent `builder` sub-tasks only if the architect's plan says so) |
| review / security | `reviewer` | `claude-sonnet-5-5` (override `model: claude-opus-5-5` for security-sensitive paths: auth, secrets, rate limiting) | high | 1 |
| verify | `test-runner` | `claude-haiku-5-5` | low | 1 |
| plan | built-in `Plan` | inherits | inherits | 1 |

Why these defaults: keep focused lookups and verification on Haiku at `low`,
routine implementation and review on Sonnet at `high`, and complex work on Opus at
`xhigh`. These are project routing defaults, not measured quality claims for the
new releases. Try `medium` on mechanical builder work after measuring quality.

Use `claude-fable-5-1` only when the user asks for it by name or an `architect` run
at `xhigh` failed on a frontier problem (novel algorithm, deep concurrency bug).
It costs 2.5x Opus 5.5 at base input and output rates.

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
  building one (`/graphify .`) and let them decide, since the docs/media pass calls a
  model.
- **Requests about the graph itself** ("map this repo", `/graphify`, `--update`,
  exports, hooks) are not lookups: the coordinator follows the graphify skill directly.

If the project also uses Cortex's code graph (`unified_search`, see the
`cortex-memory` skill), use one per project: graphify when `graphify-out/` exists,
otherwise Cortex. Do not query both for the same question.

## Step 3: one agent or several

Default to one agent. Fan out only when the request holds 2 or more problems that pass
all four checks:

- each can be understood without the others;
- fixing one cannot plausibly fix or change another (otherwise they share a root cause);
- they do not edit the same files or share a resource (database, port, fixture, lock
  file, generated output);
- you already know what is broken; exploratory "something is wrong somewhere" work stays
  in one agent or the coordinator.

If any check fails, one agent works through the problems in order, or investigates the
group first and splits afterwards. If all pass, hand the split to the
`dispatching-parallel-agents` skill: it groups the problems into independent domains,
writes one self-contained brief per domain and integrates the results. Route each domain
through Steps 1 and 2 on its own, so a lookup domain gets `scout` while a sibling
complex domain gets `architect`.

Never spawn more agents than there are independent domains. Anthropic's own research
system scales as: simple fact 1 agent, comparison 2 to 4, and 10+ only for broad
research. For code changes cap at 3 to 5 concurrent agents and run the rest in waves.
Dependent steps run in one agent sequentially, not in several.

## Step 4: write the delegation brief

Vague briefs make agents redo each other's work or misread the goal. Every brief has:

1. **Objective**: one sentence of what "done" means.
2. **Boundaries**: files or directories in scope, what not to touch, project rules that apply (from AGENTS.md / CLAUDE.md: auth conventions, endpoint catalogues, routing, no secrets in repo).
3. **Verification target**: the exact command that must pass, taken from the project's build and test section (for security-sensitive changes, always include the project's authentication or security test filter).
4. **Output contract**: what to return and how long. Default: a summary under 30 lines with file paths and line numbers, then the verification output trimmed to failures. Never "paste the whole file".

Preface the delegation with the routing decision so it is visible in the transcript:

```
router: tier=<tier> agent=<agent> model=<model> effort=<effort> agents=<n> verify=<command>
```

When fanning out, print one line per domain with `domain=<name>` added, all of them
before the single message that dispatches the agents.

## Step 5: verify, then escalate one rung at a time

Read the agent's evidence (test output, build exit code). If it fails or the answer is
shallow, do not retry at the same level: climb one rung.

```
scout (haiku 5.5 low) -> builder (sonnet 5.5 high) -> architect (opus 5.5 xhigh) -> architect with model: claude-fable-5-1
```

Escalate with the failure attached to the brief, so the next agent does not rediscover
it. Two failures at the top rung means the task, not the agent, needs re-scoping: stop
and ask the user.

After a fan-out, escalate each failing domain on its own and leave the green ones alone.
Then run the full build and suite once (through `test-runner`): per-agent greens do not
prove the combination. If the combined run fails, the domains were not independent;
stop dispatching and debug the interaction in one agent.

## Coordinator habits that keep this cheap

- Do not read large files or run the full test suite without a filter in the main context when an agent can return the summary instead.
- Ask for evidence, not assurances: the failing test names, the command and its exit code.
- Prefer one well-briefed agent over several thin ones; every agent re-loads CLAUDE.md, AGENTS.md and the tool list.
- Independent agents go in one message so they run concurrently; dependent ones wait.
- Agents that edit files (`builder`, `architect`) run in the foreground (`run_in_background: false`): a background agent auto-denies any tool call that would ask for permission and may report an edit it never made.
- If the router says `inline`, just do it. Explaining why you did not delegate wastes more than the delegation would have saved.
