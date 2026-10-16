---
name: brainstorming
description: Turns a vague request into an approved design before anything is built - finds out what the user actually wants and why through one question at a time, proposes 2 to 3 approaches with a recommendation, presents the design in sections for approval, writes the design document, has a fresh subagent read it as the builder would, and hands off to writing-plans. Use before any creative or behavior-changing work - "add a feature", "build X", "I want to change how Y works", "let's plan Z", "help me think through", or a request where something non-trivial is missing. Runs before Plan mode and before writing-plans. Skip when the request already says everything that matters (a one-line fix, "make the icon blue"), for pure bug fixes (use systematic-debugging), and when the user says to skip the questions.
---

# Brainstorming

Find out what the user wants, and why, before anything gets built. People often have not
finished working out what they want; good questions help them get there, and knowing the
why lets you make the hundred small decisions they never mention the way they would have.
This skill ends with an approved design and a hand-off to `writing-plans`. It writes no
product code.

Runs before Plan mode and before `writing-plans`: brainstorm first, plan second, build
third.

## Step 1: what do you already know

Ask yourself what you know about what they want and why.

- Everything that matters is in the request ("make the icon cornflower blue"): it is a
  quick task. Do it and say what you did. This skill is done.
- Something non-trivial is missing: start the conversation.

Before asking questions about existing code, look instead of asking:

- If `graphify-out/` exists, query it first (`graphify query|explain`).
- If Cortex is connected, `recall` for prior decisions on the topic (`cortex-memory`).

Questions the code or memory already answers waste the user's time.

## Step 2: open the conversation

Your first message has two parts and nothing else:

1. One line saying that if they would rather skip the questions and have you start, they
   can say so. If they do, this skill is done: state any significant how-it-gets-made
   choice (platform, language, medium) in one plain line, then do the work through the
   normal workflow.
2. One open question that gets them describing a concrete picture: "What is the moment
   you find yourself wishing this existed?"

## Step 3: ask one question at a time

- Each message ends with exactly one question, a single sentence with no list of example
  answers hanging off it. Ask in plain chat, including multiple-choice
  decisions: number the options only when they are stuck and ask them to reply with
  the number.
- Open questions first: their own words carry intent that your options cannot. Offer a
  short menu only when they are stuck. When they say "just guess", propose something
  concrete.
- Match their vocabulary. No process jargon. Lead with what matters.
- A guess they can correct ("I am guessing this is because X keeps biting you?") often
  beats a question. Mark guesses as guesses.

Cover this ground as territory, not a script (never read it out as questions):

- what kind of thing this is and what makes it special
- why now, and what success looks like to them
- goals, non-goals, and anti-goals (what would make it a failure even if it works)
- prior art: what they have seen elsewhere, loved or hated
- current state: what exists, what they have tried
- constraints and the details they care about
- how it gets made: which choices (platform, language, libraries, medium) they want to
  make, which they hand to you, and what they already have. Build on what the existing
  project uses. Any choice you make goes in the design as your call, never as something
  they agreed to.

Good anchors: "Walk me through the last time...", "If it could do only one of these well,
which?", "What would make you wince if I got it wrong?".

When looking would help (their code, files, the web), offer to go look and say what you
would look for. They decide.

A quick throwaway spike is sometimes the cheapest way to learn what they want. Offer one
when it would help. It stays labeled throwaway: no plan, minimal tests, and keeping what
it produced is a new request that comes back through the gate below.

## Step 4: propose approaches

Before proposing, think wide privately: come up with several ideas and drop the weak ones,
including any that fight what they told you about why. Then present 2 to 3 approaches with
the trade-offs of each, lead with the one you recommend, and say why. Show the comparison
only when it helps them decide; a single obvious path needs no menu.

## Step 5: present the design in sections

As soon as you understand one part well enough to describe it (what it is for and who it
serves, how one piece behaves), play it back in about 200 to 300 words, then return to
questions about the next part. Playback and questions alternate; the last chunk covers
whatever is left. Mark what you guessed; only what they said goes in as theirs. End each
chunk by asking what is wrong or missing, and get approval section by section.

## Step 6: size the work

Say the size in plain words; they can override it.

| Size | Full description | Then |
| --- | --- | --- |
| Quick, clear task | the request itself | do it |
| Small change | in chat | build it through the normal workflow |
| Project with a written design | a design document | `writing-plans` |

If it grows mid-task, stop, say so, and step up a size. If it is really several
independent projects, agree on an order and brainstorm them one at a time.

## Step 7: write the design document

For a project, write a plain document a talented builder in the domain could plan from
without going back to the user. Cover: intent and the why; goals, non-goals, anti-goals;
constraints; the parts of the how they decided, as they decided them; what is left to the
builder.

Location: the one AGENTS.md / CLAUDE.md names, else
`docs/specs/YYYY-MM-DD-<topic>-design.md`, committed. The user's preference overrides both.

## Step 8: self-review, then the builder check

First scan the document yourself: placeholders ("TBD"), contradictions, goals no
section serves, a decision attributed to the user that was really yours.

Then run the builder check. Spawn a fresh subagent with
[references/builder-check-prompt.md](references/builder-check-prompt.md), filling in the
domain and the document path, using `spawn_agent` with `fork_turns: "none"` (a clean
context, so it sees only the document) and an explicit `model` and `reasoning_effort`
chosen with `agent-router`. Use the `scout` role (`agent_type`) for a short document, or
the default role when the project has not installed the `agent-router` templates; this is
a read, not a design task, so it never needs `architect`. Subagents need
`multi_agent = true` under `[features]` in `~/.codex/config.toml`. Use `wait_agent` with a
5 to 10 minute timeout instead of short polls. Tell the user you are writing it up,
that a reviewer will read it first and that you may come back once with a few questions.
Do not hand over the document until the check is back.

Sort what the builder asks into three piles:

- **Answered already** by the conversation or the project: put the answer in the document.
- **Minor**: a sensible builder could settle it without changing what gets built. Settle it
  yourself and mark it in the document as your call.
- **Theirs**: only the user can answer it, and the answer changes what gets built.

Bring the "theirs" pile in one message, most important first. Update the document with
the answers, then hand it over with a short list of the calls you made so they can check
those while reading. That is the only round of questions the check produces. Without
subagents, read the document as that builder yourself.

If a design decision should outlive the session (a choice made, an option rejected and
why), `remember` it when Cortex is connected.

## The gate

Nothing gets built until the user approves the full description: in chat for a small
change, the document for a project. Building includes product code, scaffolding,
installing dependencies, creating projects, and invoking an implementation skill. Reading
and exploring are fine.

Two exceptions: if they opted out of the questions, the skill is done and the gate goes
with it; a spike they said yes to may be built, labeled throwaway.

After a project's document is approved, the next step is `writing-plans` and no other
skill.

## Traps

| Thought | Reality |
| --- | --- |
| "I will offer options to save them effort" | Options steer. Ask them to describe it first. |
| "I will fill in sensible defaults" | Fine, but say them out loud; an unheard default cannot be rejected. |
| "I should explain the process first" | Ask your question. The process shows itself. |
| "They said 'sounds good' to the idea" | Approval covers what you showed. A description you have not written is not approved. |
| "The spike works, I will keep building on it" | Keeping it is a new request. Back through the gate. |
