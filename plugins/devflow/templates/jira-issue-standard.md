# The team's Jira issue standard

This is the team's own file. `setup-devflow` seeds it once from the devflow plugin's
template and never touches it again, so anything written below survives every upgrade.

There is one copy, in the artifact repo, and no per-repo override. A repo that wants
different ticket rules is a different team, and a different team gets a different
artifact repo.

The plugin ships the skeleton and nothing else. **What good writing looks like under each
heading is yours to author**, and this file is where it goes. Every sentence the plugin
wrote is about shape.

## What the machine checks, and what it leaves to you

The `issue` gauntlet runs the `issue-standards` check over a draft before anyone is asked
to read it. It converts the draft to Atlassian Document Format, the only structured input
the Jira CLI accepts, and asserts against the converted document: the five headings
present and exactly spelled, each one carrying content, a link in **Design**, nothing ADF
cannot carry, a summary within the Jira limit, a declared issue type, and a spec epic to
be parented under.

It asserts nothing about whether the acceptance criteria are testable, whether the scope
is right, whether the business outcome genuinely precedes the implementation, or whether
a reader from another team could follow it. That is the whole substance of a ticket, and
no exit code reaches it. A read-only review runs after the check and before you, and
neither of them blocks: **the check says the shape is there, never that the writing is
good.** You are the gate.

## The five sections

Every issue body carries these five h2 headings, in this order, spelled exactly as below.
The skeleton:

```markdown
## What to build

## Acceptance criteria

## Out of scope

## Affected surfaces

## Design
```

### What to build

The business outcome first, then what changes and why.

### Acceptance criteria

The required behaviour when the ticket is complete.

### Out of scope

What this ticket deliberately does not cover. Leaving it empty fails the check.

### Affected surfaces

The APIs, events and domain concepts the work touches. Nested lists are supported.

### Design

The spec URL. At least one link, or the check fails: a ticket that names no design sends
its reader looking.

## The summary

The issue title becomes the Jira summary. Two mechanical rules, both checked:

- Within 255 characters, which is Jira's own limit.
- Its first word is not `Implement`, `Refactor` or `Fix`. Those three are unambiguously
  implementation framings. `Add`, `Create` and `Update` are often legitimate outcomes and
  are left alone, deliberately: this is the rule closest to the judgement line and it is
  quiet rather than noisy.

## Parent and Blocked by leave the body

Upstream's `to-tickets` template writes a **Parent** section and a **Blocked by**
section into the issue body. Neither survives into Jira, and neither is one of the five.

- **Parent** becomes the issue's native parent: every issue in a spec is created under
  that spec's epic.
- **Blocked by** becomes native `Blocks` links, written in a second pass once every issue
  has a key.

A prose restatement of a relationship Jira holds natively goes stale and is invisible to
the board.

## What a ticket never carries

- No label of any kind. The team's Jira workflow does not read one, and a label this flow
  writes is a label somebody has to maintain.
- No status transition. Publishing creates issues and does nothing else to them.
- No markdown image. An ADF media node needs an id from a prior upload and cannot be made
  from a markdown image, so the converter refuses the draft rather than dropping the
  image silently. Link to the image instead.

## The team's guidance

Everything above is shape. Write what the team has learned about ticket writing here, and
the skills that read this file will carry it into every draft.
