# Sources behind the routing matrix (OpenAI / Codex)

Model catalog, prices and effort verified 2026-10-17. Other background collected
2026-09-14; historical benchmarks below are not evaluations of the new defaults. Official OpenAI material first, independent articles after.

## Official OpenAI documentation

- **Current model pages** (standard API text rates, USD per 1M tokens):
  https://developers.openai.com/api/docs/models/gpt-6-luna ($0.10 input,
  $0.01 cached input, $0.50 output),
  https://developers.openai.com/api/docs/models/gpt-6.1-sol ($2 input,
  $0.10 cached input, $10 output), and
  https://developers.openai.com/api/docs/models/gpt-6-astra ($10 input,
  $1 cached input, $50 output).
  All three list 1,050,000 context and 128,000 maximum output tokens. Sol 6.1 and
  Astra support low/medium/high/xhigh/max; Sol 6.1 explicitly rejects none/minimal.
  Luna also supports none. Use Responses for tools; Sol 6.1 Chat Completions has
  no tool calling, and Luna Chat Completions function calling requires none.
- **Previous Sol** - https://developers.openai.com/api/docs/models/gpt-6-sol
  Still available at $2 input/$0.20 cached/$10 output, but its model page points
  to GPT-6.1 Sol as the newer choice. Replaced Terra and Sol 5.6 in our defaults
  with Sol 6.1 at different effort levels; this is routing policy, not a measured
  claim that one model wins every workload.
- **API pricing** - https://developers.openai.com/api/docs/pricing
  Base prices exclude tool charges and service-tier/regional premiums. Current
  model pages specify higher rates for prompts over 272K input tokens: 2x input
  and cache, 1.5x output for the full request. Cached input is model-specific,
  not a universal 10%. API prices do not describe subscription usage allowances.
- **Reasoning guide** - https://developers.openai.com/api/docs/guides/reasoning
  Level guidance: `none` for latency-critical tasks that do not benefit from
  reasoning; `low` for "efficient reasoning with modest latency increase... tool-use,
  planning, search"; `medium` default for most workloads; `high` for "hard reasoning,
  complex debugging, deep planning" in agentic workflows; `xhigh` for deep research
  and asynchronous tasks; `max` for the most complex tasks. `xhigh` exists only on
  models released after GPT-5.1 Codex Max.
- **Codex subagents** - https://learn.chatgpt.com/docs/agent-configuration/subagents
  Custom agents are TOML files in `.codex/agents/` (project) or `~/.codex/agents/`
  (personal). Required keys: `name`, `description`, `developer_instructions`.
  Optional: `model`, `model_reasoning_effort`, `sandbox_mode`, `mcp_servers`,
  `skills.config`. Resolution order: explicit spawn value, then `[agents]` default,
  then the parent's value; a value set in the agent file wins. Built-in roles
  `default`, `worker`, `explorer`; a custom agent with the same name overrides them.
  Subagents run in parallel, inherit the parent's sandbox and approval policy unless
  overridden, and the parent receives a consolidated result.
- **Codex config reference** - https://learn.chatgpt.com/docs/config-file/config-reference
  `model_reasoning_effort = "minimal | low | medium | high | xhigh"` (Responses API
  only); `model_verbosity = "low | medium | high"`. `[agents]` keys: `enabled`,
  `default_subagent_model`, `default_subagent_reasoning_effort`,
  `max_concurrent_threads_per_session`, `interrupt_message`; role tables
  `agents.<name>.config_file` and `agents.<name>.description`. Permission profiles
  `":read-only"`, `":workspace"`, `":danger-full-access"`.
- **Codex skills** - https://learn.chatgpt.com/docs/build-skills
  Skills are folders with `SKILL.md` (frontmatter `name`, `description`) plus optional
  `scripts/`, `references/`, `assets/` and `agents/openai.yaml`. Loaded from
  `.agents/skills` (repo, walking up to the root), `$HOME/.agents/skills`,
  `/etc/codex/skills`, then built-ins. Invoked explicitly with `$skill-name` or
  implicitly by description match. The skills list is capped at about 2% of the
  context window, so descriptions must be short and specific.

## Independent articles (not OpenAI)

- **GPT-5 benchmarks and analysis** (Artificial Analysis) -
  https://artificialanalysis.ai/articles/gpt-5-benchmarks-and-analysis
  Across the four reasoning levels of GPT-5, token usage and cost spread about 23x
  between the highest and lowest setting, with a large intelligence gap as well.
  Classification-style work is flat across levels; agentic work is not.
- **Controlling reasoning effort in LLMs** (Sebastian Raschka) -
  https://magazine.sebastianraschka.com/p/controlling-reasoning-effort-in-llms
  Effort is a spend dial, not a quality switch: sweep it per task type and measure,
  because the marginal gain from `high` to `xhigh` is workload-dependent.
- **Codex CLI custom agent definitions** (Daniel Vaughan) -
  https://codex.danielvaughan.com/2026/04/27/codex-cli-custom-agent-definitions-toml-specialised-subagents/
  Worked TOML examples (`reviewer`, `security_auditor`) with `model`,
  `model_reasoning_effort = "high"` and `sandbox_mode = "read-only"`. "Unless an agent
  must write files, lock it to `read-only`."
- **From one agent to a team: understanding Codex subagents** (Towards Data Science) -
  https://towardsdatascience.com/from-one-agent-to-a-team-understanding-codex-subagents/
  Subagents pay off when the exploration output is far larger than the conclusion;
  for small, already-decided edits the spawn overhead exceeds the savings.
- **Codex subagents: parallel work without losing control** (AgentsCamp) -
  https://agentscamp.com/guides/advanced/codex-subagents
  Keep concurrency at 3 to 5 threads, name the agent in the request, and restate
  paths, errors and the relevant AGENTS.md rule in the brief because the prompt is
  the only channel to the subagent.
- **LLM model routing in 2026: cost-quality optimization** (Digital Applied) -
  https://www.digitalapplied.com/blog/llm-model-routing-2026-cost-quality-optimization-engineering-guide
  Cascade pattern ("answer with the cheap model first, escalate only if verification
  fails") beats a single frontier model on both cost and quality. Silent quality
  regression is the main risk: gate routing changes with an eval, and remember that
  misrouted hard tasks cost more in retries than they save.
- **AI model routing explained** (Inworld AI) -
  https://inworld.ai/resources/ai-model-routing-cost-reduction
  Reports 40% to 85% bill reductions from tuned routing, because most traffic never
  needed a frontier model. Savings evaporate if the router under-sizes hard prompts.

## Code graph lookups

- **graphify** (Graphify-Labs) - https://github.com/Graphify-Labs/graphify, v0.9.91,
  read 2026-10-15. CLI `query`, `explain`, `path`, `affected` and `update` against
  `graphify-out/graph.json`; edges tagged `EXTRACTED` or `INFERRED`; exit 3 for an
  ambiguous name, 4 for no match (checked against a locally built graph). The README
  warns against stacking two unconditional "query the graph first" instruction blocks
  when an MCP graph is also connected, which is why the router picks one graph per
  project.

## Executable quota sources (verified 2026-10-17)

- Codex App Server: https://learn.chatgpt.com/docs/app-server,
  initialize/initialized and account/rateLimits/read; retain native durations,
  bucket IDs, usedPercent and resetsAt. No model inference is needed for a query.
- Claude Code statusline: https://code.claude.com/docs/en/statusline,
  rate_limits.five_hour/seven_day use used_percentage and resets_at. Fields can
  be absent; native stdin/file snapshots need a capture timestamp for freshness.
- CLI policy and schema live in tools/agent-router in this repository. Recommendations
  must be applied by the caller; subscription quota cannot be derived from API prices.

## Plugin/runtime integration (2026-10-17)

- Both host packages carry the skill-local scripts/agent-router launcher and the
  root Rust source/runtime helper. No unsupported native-install manifest fields
  are used. Complete plugin roots can build on first launcher use; copied skills
  depend on the installer's user/project runtime. No writes go to plugin caches.
- Sources: https://developers.openai.com/plugins/build/plugins and
  https://code.claude.com/docs/en/plugins-reference (bundled scripts and resources).
- install.sh prepares the bundled runtime even with --no-external; --no-router is
  the explicit preparation opt-out. Native binaries are reused or compiled with
  Cargo. Custom policy is preserved separately from distributed defaults.
