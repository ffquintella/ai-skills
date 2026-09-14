# Sources behind the routing matrix (OpenAI / Codex)

Collected 2026-09-14. Numbers are quoted as reported by each source; re-check them
when models change. Official OpenAI material first, independent articles after.

## Official OpenAI documentation

- **API pricing** - https://developers.openai.com/api/docs/pricing
  Per 1M tokens (input / cached input / output): `gpt-6-astra` $10 / $1 / $50;
  `gpt-5.6-sol` $4 / $0.40 / $20 (promotional, "available at least through
  November 21, 2026"; list $5 / $30); `gpt-5.6-terra` $2 / $0.20 / $12;
  `gpt-5.6-luna` $0.20 / $0.02 / $1.20. Older line still served: `gpt-5.5` $5 / $30,
  `gpt-5.4` $2.50 / $15, `gpt-5.4-mini` $0.75 / $4.50, `gpt-5.4-nano` $0.20 / $1.25,
  `gpt-5.3-codex` $1.75 / $14. Cached input is 10% of input. Batch API is 50% off;
  Flex matches batch rates; fast mode is 2x.
- **Models overview** - https://developers.openai.com/api/docs/models
  All four flagship tiers have a 1,050,000-token context window and 128K max output.
  Astra: "our most capable model, built for the hardest end-to-end work"; Sol:
  "flagship model for complex professional work"; Terra: "workloads that balance
  intelligence and cost" (mini-tier successor); Luna: "cost-sensitive, high-volume
  workloads" (nano-tier successor).
- **Model pages** - https://developers.openai.com/api/docs/models/gpt-5.6-sol,
  `.../gpt-5.6-terra`, `.../gpt-5.6-luna`, `.../gpt-6-astra`
  Sol, Terra and Luna accept `none, low, medium (default), high, xhigh, max`. Astra
  accepts `low` to `max` and returns HTTP 400 on `none`. Astra is Responses and Chat
  Completions only (no Realtime, Assistants, fine-tuning, embeddings).
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
