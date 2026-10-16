---
name: writing-skills
description: Authoring discipline for agent skills, treating a SKILL.md like code - no new skill and no edit to an existing one until an agent has been seen failing without it. Covers the four skill types, description wording that makes a skill trigger, token budget, when to split into references/, and this repository's rules for Claude and Codex twins, sources.md and the README table. Use when creating a skill, editing or tightening one, adapting a skill from another repository, checking whether a skill works before deploying it, or when a skill is not triggering or is ignored under pressure ("write a skill for", "this skill doesn't get used", "add a rule to the skill"). Not for project conventions, which belong in AGENTS.md or CLAUDE.md. Pairs with test-driven-development (same cycle) and, when installed, Anthropic's skill-creator for eval-driven iteration.
argument-hint: [skill name or change]
---

# Writing skills

**Rule: no skill, and no edit to a skill, without first watching an agent fail without
it.** Writing a skill is test-driven development applied to process documentation. The
pressure scenario is the test, the baseline failure is the red run, the skill is the
production code, and the re-run with the skill is the green run. If you never saw the
failure, you do not know what the skill has to prevent, and you will write what you
*think* agents get wrong instead of what they actually get wrong. Background on the cycle:
`test-driven-development`.

Anthropic's own authoring guidance:
https://docs.anthropic.com/en/docs/agents-and-tools/agent-skills/best-practices. This skill
is the discipline on top of it. When Anthropic's `skill-creator` skill is installed, use it
for eval-driven iteration (benchmarks, description tuning); the rules here still apply to
what you write.

## Should this be a skill

Write one when the technique was not obvious, you would use it again across projects, and
it applies broadly. Do not write one for:

- a one-off solution or a narrative of how you solved something once;
- standard practice that is well documented elsewhere (link it instead);
- a project-specific convention: that goes in `AGENTS.md` or `CLAUDE.md`;
- a mechanical constraint that a linter, regex or test can enforce: automate it, and keep
  skills for judgment calls.

## Skill types

The type decides how you test it.

| Type | What it is | Test with | Done when |
| --- | --- | --- | --- |
| Discipline | Rules that cost effort and invite shortcuts (`test-driven-development`) | Pressure scenarios combining 3 or more pressures | The agent follows the rule under maximum pressure |
| Technique | A method with steps (`systematic-debugging`) | A new task where the method applies, plus variations and a missing-information probe | The agent applies it correctly to a case it has not seen |
| Pattern | A way of thinking about a problem class | Recognition (does it apply here?), application, and counter-examples (when not to) | The agent picks the right cases and skips the wrong ones |
| Reference | Syntax, API or tool documentation | Retrieval (can it find the answer?) and use of what it found | The common questions are answered and the gaps are known |

## The cycle

1. **Red.** Write a scenario that makes an agent want to break the rule or hit the gap.
   Run it with an agent that does not have the skill. Record what it did and, for
   discipline skills, the rationalizations word for word. No failure means no skill is
   needed for this case: stop.
2. **Green.** Write the smallest skill that addresses those recorded failures, nothing for
   hypothetical cases. Run the same scenario with the skill. It should comply.
3. **Refactor.** An agent that still breaks the rule or invents a new excuse is a failing
   test: add a specific counter, re-run, repeat until a new scenario finds nothing new.

This applies to edits as well: a "small addition" gets a scenario first. Untested text is
dead weight at best and a new loophole at worst.

How to build scenarios, which pressures to combine, how to run baseline and re-runs with
agents, wording micro-tests and meta-testing:
[references/testing-skills-with-agents.md](references/testing-skills-with-agents.md).

## Match the form to the failure

Classify the baseline failure before choosing how to write the guidance. The form that
fixes one failure type can make another worse.

| Baseline failure | Write | Avoid |
| --- | --- | --- |
| Knows the rule, skips it under pressure | A bright-line rule with its reason, the specific excuses named and answered, a red-flags list | Soft wording ("prefer", "consider") |
| Complies, but the output has the wrong shape | A recipe: what the output is, its parts, in order | A list of things not to do (agents negotiate with prohibitions when another goal competes) |
| Leaves out a required element | A required field or slot in the template the agent fills in | A reminder in prose near the template |
| Behavior depends on a condition | A conditional on something observable ("if the brief file exists, cite it") | A blanket rule with exemption clauses |

Two more rules for any form. No nuance clauses: "don't X unless it matters" reopens the
negotiation, so state a real exception as its own conditional. Exemptions do not scope:
"this limit does not apply to code blocks" still suppresses code blocks, so restructure
instead. For tone on discipline skills see
[references/persuasion-principles.md](references/persuasion-principles.md).

## Frontmatter

- `name`: letters, numbers and hyphens, equal to the folder name. Prefer a verb-first or
  insight-first name (`condition-based-waiting`, not `async-test-helpers`).
- `description`: at most 1024 characters, third person, because it is injected into the
  system prompt. It is what the agent reads to decide whether to open the skill.
- `argument-hint` (Claude twin only): what to pass after `/name`.

**The description says what the skill is for and when to use it. It does not summarize the
steps.** An agent that can get the gist from the description may follow the gist and skip
the body. In upstream testing, a description that said "code review between tasks" got one
review done, while the body specified two reviews in order. State the purpose and the
triggers; leave the procedure to the body.

Write the "Use when" part from situations, symptoms and the words a user or an error would
contain: "flaky", "hangs", "ENOTEMPTY", "again", "stop guessing". Describe the problem, not
the tool, unless the skill is tool-specific, and then say so. Add the symptoms of being
about to violate the rule once testing shows them. Say when not to use it, and name the
sibling skill that covers that case. Compare existing descriptions in this repository.

## Body

- **Open with the rule or the core idea** in one or two sentences, with the reason.
- **Then what a reader scans for**: when to use and not use, the steps or the pattern, a
  quick-reference table, common mistakes. Not every skill needs every section.
- **One good example** in the most relevant language, complete enough to run, commented on
  why, taken from a real case. Not the same example in five languages, not a fill-in
  template.
- **Flowcharts** only for non-obvious decisions or loops where an agent might stop early.
  Steps are a numbered list, reference material is a table, code is a code block.
- **Cross-reference other skills by name** in backticks (`systematic-debugging`) and say
  whether it is required background or optional. Do not `@`-link files: it force-loads
  them. Do not restate what the other skill says.
- Invoke bundled scripts through their interpreter in the prose (`bash scripts/x.sh`), so a
  packager that drops the executable bit does not break them.

## Token budget

Every installed skill puts its description in context on every turn, and the body loads
when the skill triggers. Frequently loaded skills should be short; others concise.

- Move flag lists to the tool's `--help`, and say that is where they are.
- Link to another skill instead of repeating its workflow.
- Compress examples; cut the second example of the same pattern.
- Cut what is obvious from the command or from the surrounding text.

Aim for a SKILL.md under about 250 lines, as the skills here are. Split when the body
grows past that or a section is only needed sometimes:

- **`references/`**: heavy reference (API tables, long checklists), prompt templates for
  delegated agents, and anything read only on one branch of the skill. Link each file from
  SKILL.md with one line saying when to open it.
- **`scripts/`**: code that is run, not read, and is reusable. Keep the executable bit.
- **`assets/`**: files copied into the user's project (agent templates, config examples).
- Keep inline: principles, short patterns, anything needed on every use.

## In this repository

Each skill exists twice, `claude/<name>/` for Claude Code and `openai/<name>/` for OpenAI
Codex, and the two change together. Edit one, edit the other in the same change, and diff
them to confirm only vendor wording differs.

- **Claude twin**: has `argument-hint` in the frontmatter; "agent" vocabulary, the `Agent`
  tool with `subagent_type`, agent templates in `.claude/agents/`, invoked as `/name`. For
  an expensive skill that must only run on request, add `disable-model-invocation: true`
  (see `claude/rust-review`).
- **Codex twin**: no `argument-hint`; "subagent" vocabulary, `spawn_agent` and `wait_agent`,
  roles in `.codex/agents/`, invoked as `$name`. For an expensive skill add
  `agents/openai.yaml` with `policy.allow_implicit_invocation: false` (see
  `openai/rust-review`).
- **Adapted skills** carry `references/sources.md` in both twins: the upstream link, the
  date and commit read, and a `Changes:` sentence. Rewrite adapted material in this
  repository's voice and link other skills by plain name; do not copy it over. If a
  decision about why the skill was adapted rather than copied is not already in
  `sources.md`, `remember` it with the `cortex-memory` skill when Cortex is connected.
- **README**: add the skill's row to the table in `README.md`, with both links.
- **Delegation inside a skill** goes through `agent-router` and its agents (`scout`,
  `builder`, `architect`, `reviewer`, `test-runner`), falling back to a general-purpose
  agent when the project has not installed them. Link `test-driven-development`,
  `systematic-debugging` and `dispatching-parallel-agents` instead of restating them.
- **Check**: `./install.sh --list` should show the new skill for both vendors. The
  installer and, when it is installed, the ai-skills plugin pick skills up from the
  `claude/` and `openai/` folders, so the files are the only registration.
- **Style**: sentence-case title, no emoji, no em dashes in prose, no shouting, state each
  rule once with its reason. Before finishing, grep both folders for a leftover upstream
  brand name (outside `sources.md`) and for the em dash character.

## Excuses for skipping the test

| Excuse | Reality |
| --- | --- |
| "The skill is obviously clear" | Clear to the author is not clear to an agent that has other goals |
| "It is only a reference" | References have gaps and buried answers; test retrieval |
| "It is a small edit" | Small edits change what the agent does; scenario first |
| "I will test if problems appear" | A problem means an agent already could not use it |
| "Testing takes too long" | One baseline run is minutes; a bad skill is paid for on every use |
| "I will batch several skills, then test" | Each skill is tested and checked before the next one starts |

Written the skill before the baseline? Set the draft aside, run the baseline, and write
again from the recorded failures. Do not keep the draft as a reference: you will adapt it
instead of answering what you saw.

## Checklist

Before reporting a skill as done:

- Red: at least one baseline scenario run without the skill, failures recorded (3 or more
  combined pressures for a discipline skill).
- Green: same scenarios run with the skill, agent complies; guidance form matches the
  failure type.
- Refactor: new excuses countered, red flags and description updated, re-run clean.
- Frontmatter: `name` equals folder, description under 1024 characters, third person,
  purpose plus "Use when", no steps summarized.
- Body: rule first, one example, no narrative, supporting files only where needed, under
  about 250 lines.
- Both twins written and diffed; `references/sources.md` if adapted; README row added;
  `./install.sh --list` shows it.
