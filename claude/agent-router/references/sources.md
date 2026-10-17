# Sources behind the routing matrix

Model catalog, prices and effort verified 2026-10-17. Other background collected
2026-09-14; historical benchmarks below are not evaluations of the new defaults. Official Anthropic material first, independent articles after.

## Official documentation and Anthropic engineering posts

- **Current model catalog** - https://platform.claude.com/docs/en/models/overview
  General-purpose lineup: claude-haiku-5-5, claude-sonnet-5-5,
  claude-opus-5-5, claude-fable-5-1. All list 1M context and 128K max output.
  Templates use full IDs rather than moving aliases. Specialized/restricted
  models are outside the default routing ladder.
- **Pricing** - https://platform.claude.com/docs/en/about-claude/pricing
  Standard Claude API input/output USD per 1M tokens: Haiku 5.5 $0.10/$0.50
  for prompts up to 100,000 tokens, $0.50/$2.50 above that; Sonnet 5.5 $2/$10;
  Opus 5.5 $4/$20; Fable 5.1 $10/$50. Partner and subscription billing differs.
  Fable is 2.5x current Opus, rather than the old 2x ratio. Haiku-relative cost
  comparisons in the skill use its short-prompt input rate.
- **Effort parameter** - https://platform.claude.com/docs/en/build-with-claude/effort
  All four current models support low/medium/high/xhigh/max. Opus 5.5 and
  Haiku 5.5 default to medium; Sonnet 5.5 and Fable 5.1 to high. Haiku low fits
  short tool tasks, but long prompts can cause skipped checks; raise effort for
  instruction-heavy work. The API supports per-message effort changes with a
  beta header on supported platforms, preserving cache. Agent templates pin
  effort for predictable Claude Code routing; this is not an API limitation.
- **Anthropic cost-optimization guidance** (bundled with Claude Code's `claude-api`
  skill, `shared/cost-optimization.md`, section 2.6). Measured with Fable 5 on research
  benchmarks: `low` gave up 1 to 3 points for a third to a half off cost per task;
  `medium` matched the default at 70% to 85% of its cost. Long-horizon coding on Opus 5:
  `medium` lost about 2 points for half the cost, `low` about 8 points for a quarter.
  "Run everything at `low`, re-run failures at the default" reached about 93% pass for
  about $0.70 per task versus 91.7% for $1.39 at the default. Rule: sweep effort before
  changing the model; judge cost per completed task, not per request.
- **Create custom subagents** - https://code.claude.com/docs/en/sub-agents
  Frontmatter fields incl. `model` (`sonnet`, `opus`, `haiku`, `fable`, full id,
  `inherit`) and `effort` (`low`..`max`, "overrides the session effort"). Model guidance:
  Haiku for fast read-only exploration and simple lookups, Sonnet for review and
  general work, Opus for complex multi-step reasoning. Subagents save context because
  exploration output stays in their window and only the summary returns.
- **Manage costs effectively** - https://code.claude.com/docs/en/costs
  "Sonnet handles most coding tasks well and costs less than Opus. Reserve Opus for
  complex architectural decisions or multi-step reasoning." Use `model: haiku` for
  simple subagent tasks. Delegate verbose operations (tests, docs, logs) to subagents.
  Keep CLAUDE.md under about 200 lines; move workflow detail into skills that load on
  demand. Agent teams cost roughly 7x a normal session.
- **Best practices for Claude Code** - https://code.claude.com/docs/en/best-practices
  Context is the binding constraint and quality degrades as it fills. Use subagents
  for investigation and for adversarial review in a fresh context. Skip plan mode when
  "you could describe the diff in one sentence". Always give a verification target.
- **Agent skills** - https://code.claude.com/docs/en/skills
  Skill frontmatter (`name`, `description`, `argument-hint`, `model`, `effort`,
  `context: fork`), progressive disclosure, keep SKILL.md under 500 lines.
- **Building effective agents** (Anthropic, 2024) -
  https://www.anthropic.com/engineering/building-effective-agents
  Routing pattern: classify input, send easy cases to a cheaper model. Start with the
  simplest solution; "add complexity only when it demonstrably improves outcomes".
- **How we built our multi-agent research system** (Anthropic, 2025) -
  https://www.anthropic.com/engineering/multi-agent-research-system
  Agents use about 4x the tokens of chat, multi-agent about 15x. Embedded scaling rules:
  simple fact-finding 1 agent with 3 to 10 tool calls, comparisons 2 to 4 subagents,
  10+ only for broad research. Each delegation needs objective, output format, tool
  guidance and task boundaries; vague briefs made subagents duplicate each other.

## Independent articles (not Anthropic)

- **Effort levels in practice: I benchmarked low through max on real tasks**
  (Pavel Espitia, DEV Community, Opus 4.8) -
  https://dev.to/pavelespitia/effort-levels-in-practice-i-benchmarked-low-through-max-on-real-tasks-7lf
  Three tasks, three runs each. Classification: quality flat, tokens climb to about 8x
  at `max`. Single-shot code: quality plateaus at `high`. Multi-step audit: `xhigh` used
  the fewest total tokens because better planning meant fewer turns. Recommendation:
  `low` for classification and extraction, `high` for single-shot code, `xhigh` for
  agentic loops, `max` only when the cost of an error beats the token bill.
- **Opus 4.7: the five effort levels in Claude Code explained** (Anthony Maio) -
  https://anthonymaio.substack.com/p/opus-47-the-five-effort-levels-in
  Practical split: Sonnet at `medium` for mechanical edits and boilerplate, Opus at
  `xhigh` for primary coding, `max` only per task after documenting a failure it fixes.
  Anecdote: a batch rename left at `max` cost about 50x what `low` would have.
- **Claude Code subagents and multi-agent orchestration guide** (Hidekazu Konishi) -
  https://hidekazu-konishi.com/entry/claude_code_subagents_and_orchestration_guide.html
  Delegation saves when output volume far exceeds the conclusion (40+ file reads);
  it wastes when the change is already decided and minimal or tightly coupled to
  ongoing iteration. The prompt string is the only channel to the subagent, so restate
  paths, errors and the relevant CLAUDE.md rule. Background subagents auto-deny any
  tool call that would prompt, so keep approval-gated edits in the foreground. Omitting
  `tools` grants everything; scope research agents explicitly. 3 to 5 concurrent
  subagents is the practical ceiling before other architectures make sense.
- **7 practical ways to reduce Claude Code token usage** (KDnuggets) -
  https://www.kdnuggets.com/7-practical-ways-to-reduce-claude-code-token-usage
  Opus costs 5x Sonnet per token; a 5,000-token CLAUDE.md is paid on every turn;
  "subagents are not automatically cheaper" for small operations.
- **Claude Code token optimization: 19 changes to cut costs** (Build to Launch) -
  https://buildtolaunch.substack.com/p/claude-code-token-optimization
  Tiering: Opus for architecture, complex reasoning, multi-file refactors and hard
  debugging; Sonnet for implementation, tests and daily work; Haiku for mechanical
  tasks. "When in doubt, Sonnet is the reliable middle ground" because Haiku fails on
  judgement-heavy work. Delegate when a task touches more than three or four large files.
- **LLM model routing in 2026: cost-quality optimization** (Digital Applied) -
  https://www.digitalapplied.com/blog/llm-model-routing-2026-cost-quality-optimization-engineering-guide
  Cascade pattern ("answer with the cheap model first, escalate only if verification
  fails") is the one that beats a single frontier model on both cost and quality.
  Silent quality regression is the main risk: gate routing changes with an eval, and
  remember that misrouted hard tasks cost more in retries than they save.
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
