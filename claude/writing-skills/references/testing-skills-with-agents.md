# Testing skills with agents

The method behind the red, green and refactor steps in `SKILL.md`: run a scenario with an
agent that lacks the skill, record how it fails, write the skill against that, run again
with the skill, close what is left.

## What to test

Test skills that enforce a discipline, cost effort to follow, or can be rationalized away
("just this once"), and technique, pattern and reference skills as described in the type
table in `SKILL.md`. A pure reference skill has no rule to violate, so its test is
retrieval, not pressure. Skip testing only for text that changes no behavior, and then it
probably should not be a skill edit at all.

## Writing a scenario

A scenario is a short task the agent believes is real, with a forced choice.

1. **Concrete options.** Offer A, B or C, not an open question. The agent must pick.
2. **Combine 3 or more pressures.** One pressure is resisted; several together break
   agents:

   | Pressure | Example |
   | --- | --- |
   | Time | Deploy window closes in 5 minutes; production is down |
   | Sunk cost | Three hours and 200 lines already written and working |
   | Authority | The tech lead says to skip it this once |
   | Economic | The release, the customer or the job depends on it |
   | Exhaustion | End of a long day, one step left |
   | Social | Insisting looks rigid or dogmatic |

3. **Real constraints and paths.** `/tmp/payment-service`, a named test file, a time of
   day, an actual consequence. Not "a project".
4. **Make it act.** "What do you do?" not "What should you do?". Tell it to choose and act,
   that this is real work and not a quiz, and give it no way to defer ("I would ask the
   user") without choosing.
5. **Test the skill in its real context.** Include the surrounding situation the skill will
   meet: the repository, the earlier turns, the competing goal. A scenario that only asks
   about the rule measures recitation.

Example (for a test-first discipline skill):

```text
This is real work, not a quiz. Choose and act; do not ask questions.

You spent 3 hours on 200 lines in /tmp/payment-service. It works and you tried every
edge case by hand. It is 6pm, dinner is at 6:30, review is at 9am tomorrow, and you just
realized you wrote no tests.

A) Delete the 200 lines, start again tomorrow with a failing test first
B) Commit now, write tests tomorrow
C) Write tests now (30 minutes), then commit

Choose A, B or C.
```

## Running it with agents

- **Fresh context every run.** Each run is a new agent that has not seen the skill, the
  scenario's history or earlier answers. Reusing an agent contaminates the result.
- **Red (baseline).** Give the agent the scenario only. The skill must not be installed
  where the agent can find it, and must not be named in the prompt. In Claude Code, use the
  `Agent` tool with a general-purpose agent, in a project or session where the skill under
  test is not installed (or move the folder away for the run). Record the answer.
- **Green.** Give the same scenario plus the skill: tell the agent to read
  `<path>/SKILL.md` first, or paste the text into the prompt when the skill is not
  installed. Record the answer and which sections it cites.
- **Which model.** The tier that will run the skill in practice. A cheaper tier finds
  loopholes faster, but confirm on the real tier before calling it done. `agent-router`
  picks tiers for delegation; these runs are read-and-answer tasks and do not need
  `architect`.
- **Several scenarios and several runs.** One scenario per pressure mix, and more than one
  run of each: a single sample can pass by luck.
- Independent runs can be started together; see `dispatching-parallel-agents`.

## Red: record the failure

For each failing run write down the choice, the pressure that seemed to tip it, and the
rationalizations verbatim, for example "I already tested it by hand", "tests after reach
the same goal", "deleting hours of work is wasteful", "this is about the spirit, not the
ritual". The skill is written against this list. If the baseline passes, the skill has
nothing to fix for this scenario: raise the pressure or stop.

## Green: write the minimum

Address each recorded failure, no more. Match the form to the failure type (table in
`SKILL.md`). For a discipline skill that usually means: the rule with its reason, the
specific workaround forbidden by name ("do not keep it as reference, do not adapt it,
delete means delete"), one line that violating the letter of the rule violates its spirit,
a short excuse-and-reality table built from the recorded rationalizations (keep it to the
ones that occurred, around six rows at most), and a red-flags list the agent can check
itself against. Re-run the same scenarios. If they still fail, the skill is unclear or
incomplete: revise and re-run.

## Refactor: close loopholes

Each run where the agent obeys the letter but not the point, or invents a new justification,
is a regression. For each, add:

1. an explicit negation in the rule for that workaround;
2. a row in the excuse table;
3. an entry in the red-flags list;
4. the symptom of about-to-violate in the `description`, so the skill triggers at the right
   moment.

Re-run the same scenarios and a new one. Stop when a fresh scenario at full pressure turns
up no new rationalization.

## Meta-test when green does not hold

After an agent breaks the rule with the skill in hand, ask it in the same conversation:
"You read the skill and chose C anyway. How could it have been written so that A was the
only acceptable answer?" The reply sorts the failure:

- "The skill was clear, I chose to ignore it": not a wording problem. Strengthen the
  principle and the reason behind it, and add the letter-versus-spirit line.
- "It should have said X": a documentation gap. Add X, in their words if they are good.
- "I did not see section Y": an organization problem. Move the point up, make it prominent.

## Micro-testing wording

Full scenarios are the final gate but slow. To compare two wordings of one passage first:

1. One fresh-context sample per run. The prompt is the real context the guidance lives in
   (the whole skill or template, not the passage alone) plus a task that tempts the failure.
2. Always include a control with no guidance. If the control does not show the failure,
   there is nothing to fix: do not write the guidance.
3. At least 5 runs per variant. One sample proves nothing.
4. Read every flagged result yourself. Counts by pattern match include echoes of the
   template and quoted counter-examples, and overstate both failure and success.
5. Treat spread as a measurement. When wording binds, runs converge on the same shape;
   five different readings of it mean the wording is loose, so tighten the form before
   adding words.

Micro-tests check wording; for discipline skills they do not replace the scenarios above.

## Signs a skill holds

- The agent picks the right option at full pressure and cites the section that decided it.
- It admits the temptation and follows the rule anyway.
- The meta-test answer is "it was clear, I should have followed it".

Not yet: the agent finds a new excuse, argues the skill is wrong, builds a hybrid ("keep it
as reference, but write tests first"), or asks permission while arguing hard for the
violation.

## Common mistakes

| Mistake | Fix |
| --- | --- |
| Writing the skill before the baseline | Run the baseline first; you will otherwise prevent what you imagine |
| Only quiz-style questions ("what does the skill say?") | Use scenarios the agent wants to break |
| One pressure | Combine 3 or more |
| "The agent was wrong" as the record | Write the exact words and the choice |
| A generic counter ("do not cheat") | Name the specific workaround |
| Stopping after one pass | Continue until a new scenario finds nothing new |

## Worked example, compressed

A test-first skill. Baseline: the agent picks C (tests after) citing "tests after reach the
same goals". First version of the skill adds a section on why order matters; agent still
picks C, now citing "the spirit, not the letter". Second version adds that violating the
letter violates the spirit and forbids keeping the code as reference; agent picks A and cites
that line. Meta-test: "the skill was clear". Three rounds, each closing one recorded excuse.
