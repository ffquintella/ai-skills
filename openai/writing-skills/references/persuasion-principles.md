# Persuasion principles for skill wording

Agents trained on human text respond to the same framing devices people do. A study of
about 28,000 conversations (Meincke et al., 2025, building on Cialdini's principles)
reported that persuasion framing roughly doubled compliance with requests a model would
otherwise refuse. Use this only to make sure a necessary practice survives pressure, and
only in ways that serve the user's interest if they read the skill.

This repository's style is plain wording with the reason stated, no capital-letter
shouting. Authority here means a clear bright-line rule, not volume.

| Principle | In a skill | Use for |
| --- | --- | --- |
| Authority | A bright-line rule, "no exceptions" scoped to the cases tested, the reason given | Discipline skills |
| Commitment | Make the agent state a choice or announce what it will do; track checklist items with the todo tool | Multi-step processes, steps that get skipped |
| Social proof | State the failure norm: "tests written after the fix prove little, every time" | Warning about common failures |
| Scarcity | Sequence it: "before the next task", "before reporting done" | Checks that get deferred to "later" |
| Unity | "We" and shared goals: both want working code | Collaborative skills (review, brainstorming) |

Reciprocity and liking are left out on purpose. Reciprocity feels manipulative and is
rarely needed. Liking produces agreement over honesty, which is the opposite of what a
review or discipline skill needs.

By skill type: discipline skills combine authority, commitment and social proof; technique
and pattern skills use light authority and some unity; reference skills use clarity only.
Do not stack all of them. A rule with a reason and the named workarounds usually does more
than extra emphasis.

Sources: Cialdini, *Influence: The Psychology of Persuasion* (2021); Meincke, Shapiro,
Duckworth, Mollick, Mollick and Cialdini, "Call Me A Jerk: Persuading AI to Comply with
Objectionable Requests" (2025).
