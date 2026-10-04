---
name: review-draft-issue
description: Read one draft issue against the team's Jira issue standard and hand back findings, without blocking and without editing. Use after the `issue` gauntlet and before a human approves a draft for publication, or on its own against a ticket written by hand. Reads exactly two files, the draft and the team standard in the artifact repo, and nothing else, so the draft meets a reader who was not in the room when it was written. Judges what no exit code reaches: whether the acceptance criteria are testable, whether the scope holds, whether the business outcome precedes the implementation, and whether a reader from another team could follow it. Never a gate. Another skill can load this one, and a human can type it.
---

# Review a draft issue

The `issue` gauntlet says a draft's shape is there. It says nothing about whether the writing
is good, and no exit code ever will. This is the read that covers the rest, by a reader with
no stake in the text.

It is a read, not a gate. It produces findings. It never blocks, never edits, never publishes
and never changes a status anywhere.

## The two files, and only these two

1. **The draft**, named by the caller.
2. **The team standard**, at `docs/agents/jira-issue-standard.md` in the artifact repo clone.

**Read nothing else.** Not the spec the draft links, not the other drafts in the effort, not
the code, not the conversation that produced the draft. The value here is a reader who was
not in the room, and every extra file spends some of it. A draft that cannot be understood
without the spec is itself a finding, and it is invisible to anyone who has read the spec.

**No file in a home directory is ever read**, including a personal writing guide. The team
standard is the only standard, so what this review says is what it says on a teammate's
machine too.

Refuse, naming the skill and the one thing missing, rather than reviewing against memory:

- *"review-draft-issue needs the team's Jira issue standard at
  `docs/agents/jira-issue-standard.md` in the artifact repo, and it is not there. Run
  `setup-devflow` to seed it."*
- *"review-draft-issue needs `artifacts.remote` in `docs/agents/workflow.json` to find the
  artifact repo, and it is not there. Run `setup-devflow` to write it."*

A missing draft is a caller error, not a configuration problem, so that one names neither.

## When this runs

After the machine gate and before the human, in a fresh subagent with none of the publishing
session's context. A human may also type it on a ticket they wrote by hand, with no effort,
no spec and no publish in sight. Both work the same way, because the inputs are the same two
files.

## What to review

The standard is the source. Read it each time rather than reciting it: the team owns that
file and edits it, and a review quoting a rule the team removed is worse than no review.

Four judgements the check deliberately concedes, and the places findings actually live:

- **Are the acceptance criteria testable?** Could someone who did not write this decide, by
  reading them, whether the ticket is done? Criteria that restate the title, criteria with no
  observable behaviour in them, and criteria that need the author present are findings.
- **Does the scope hold?** One outcome per ticket. Work the body implies but **Out of scope**
  does not exclude is where scope creeps in, and an **Out of scope** that excludes nothing
  anybody would have attempted excludes nothing.
- **Does the business outcome precede the implementation?** **What to build** opens with what
  changes for a user or for the team, not with the mechanism. A ticket that opens with the
  mechanism has usually decided the solution before stating the problem, which is the
  expensive mistake to catch here rather than in review of the code.
- **Could a reader from another team follow it?** Unexpanded acronyms, a system named with no
  hint of what it does, a decision referred to and never linked. **Affected surfaces** should
  name the APIs, events and domain concepts, not a list of files.

Add whatever the team's own guidance in the standard asks for. That section is theirs and it
is the reason the standard is a file and not a constant in a skill.

## What not to do

- **Do not re-run the mechanical check.** Missing headings, an empty section, a missing link
  in **Design**, a summary over the limit and an implementation-framed first word are the
  gauntlet's, and it already ran. Repeating them buries the findings only you can make.
- **Do not edit the draft**, and do not offer a rewritten version. Findings name the problem
  and leave the writing to its author, who knows things this review was deliberately denied.
- **Do not rank a finding as blocking.** Nothing here blocks, so a severity would be a
  promise this skill cannot keep.
- **Do not reach Jira.** No create, no comment, no label, no transition, no search.
- **Do not pad.** A draft with nothing wrong gets a short answer saying so. A review that
  always finds three things teaches its reader to skim it.

## The handover

```
Draft: <path>
Standard: <path>

Findings: <count>

  <section>: <what is wrong, and what it costs the reader>
  <section>: <...>

Not reviewed: whether the shape is there. The `issue` gauntlet owns that.
```

With nothing to report:

```
Draft: <path>
Standard: <path>

No findings. This is a judgement, not a pass: the human gate is next.
```

The findings go to the human, in the order the sections appear in the draft. The human
decides what to do with them, including nothing.
