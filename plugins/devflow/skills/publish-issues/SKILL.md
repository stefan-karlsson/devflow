---
name: publish-issues
description: Turn the draft issues of one effort into Jira issues, one at a time, through a fixed gate order. Use when a spec's tickets have been written and nothing has reached the board yet, when a publish was interrupted and has to be resumed, or when a single hand-written ticket has to be published on its own.
---

# Publish issues

A **draft issue** is a ticket in the artifact repo that Jira has not seen. Publishing turns
drafts into Jira issues: the **spec epic** first, then each draft through a machine gate, a
non-blocking **issue review**, a human gate and `acli`, then the native `Blocks` links once
every key exists.

This is a procedure. It runs the gates in the order below and reports what happened. The
order is the point: the cheapest place to correct scope is before any code is written, and
each gate exists because the one before it cannot see what it sees.

It works on one effort's drafts or on a single draft file, so a ticket written by hand is
publishable without the rest of the flow.

## What this procedure does not decide

- **Whether a draft is good.** The gauntlet says the shape is there. The review hands back
  findings. The human decides. None of those three jobs is yours to take over.
- **What to do about a failed check.** Report it and move to the next draft. The human fixes
  the draft and runs this again.
- **When to publish.** The orchestrator owns the transition between phases.
- **What the team's standard says.** The standard is a file in the artifact repo. Read it,
  never restate it from memory, and never substitute a rule you prefer.

## Inputs

- **An effort**, named by its slug, or **a single draft file** by path. Ask which when a
  human types this skill without naming either. Do not scan the artifact repo for work.

## Where things are

Everything below is in the **artifact repo clone**: the sibling clone `setup-devflow` creates
from the `artifacts.remote` in the code repository's configuration, at a path derived rather
than stored. Run every git command and every relative path from the clone's root.

| What | Where |
| --- | --- |
| The effort | `efforts/<slug>/` |
| The spec | `efforts/<slug>/spec.md` |
| The drafts | `efforts/<slug>/issues/NN-<slug>.md` |
| The team standard | `docs/agents/jira-issue-standard.md` |
| The ADF converter | `docs/agents/gauntlets/markdown-to-adf.mjs` |
| The artifact repo's own tracker identity | `docs/agents/workflow.json` |

The converter and the `issue` check live in one directory because the check finds the
converter as its own sibling. One installer invocation carries both, which is why neither
path is configured.

**No file in a home directory is ever read.** Not the standard, not a personal writing guide,
not a credential. What your machine publishes has to be what your teammate's machine
publishes, and a personal file breaks that silently.

## The configuration it requires

Two files, both at a fixed path. Do not search and do not walk up the tree.

From the **code repository's** `docs/agents/workflow.json`:

- `artifacts.remote`, which is how the clone is found at all.
- `tracker.projectKey` and `tracker.issueType`, the project and the type every issue is
  created with.
- `gauntlets.issue`, the declaration the gauntlet reads. It is declared in the code
  repository and its commands resolve in the artifact clone.

Refuse, naming the skill and the key, when one is missing. Only the keys this operation needs
are required, so a repository with no Jira identity still has a working build loop and fails
here and nowhere else:

- *"publish-issues needs `artifacts.remote` in `docs/agents/workflow.json`, and it is not
  there. Run `setup-devflow` to write it."*
- *"publish-issues needs `tracker.projectKey` in `docs/agents/workflow.json`, and it is not
  there. Run `setup-devflow` to write it."*
- *"publish-issues needs `tracker.issueType` in `docs/agents/workflow.json`, and it is not
  there. Run `setup-devflow` to write it."*

The same shape covers a missing file, an unparseable one, a missing clone and a missing
standard: name this skill, name the one thing that was needed, name `setup-devflow`. A
refusal that says only that something went wrong sends the human reading.

## The tools it requires

- **`node`**, because the converter is a Node script and `acli` accepts no markdown. Refuse
  naming `setup-devflow`: the machine tier warns about a missing Node rather than stopping,
  precisely so the failure lands here.
- **`acli`, authenticated.** Check with `acli jira auth status` before the first write. An
  expired session is not a configuration problem, so that refusal names
  `acli jira auth login`, not `setup-devflow`.
- **`jq`**, to read the configuration and the ADF.

## Writing to the artifact repo

Every write is `git pull --rebase`, then the edit, then commit and push, immediately. An
unpushed key is a local note: a concurrent session will not see it and will publish the
draft again. Nothing here batches commits to the end of a run, because the thing being
protected is the gap between `acli` returning a key and that key being durable.

## Step 1: the spec epic

One Epic per spec, created before the first issue of that spec, so everything published from
one spec has one parent.

1. **Read the spec's header for an existing key.** The line matches
   `^[[:space:]]*[*_]*Epic:`; strip `*`, `_`, backticks and whitespace from the value. A key
   matching `<tracker.projectKey>-<digits>` is the spec epic. **Reuse it and create nothing.**
   This is what makes a re-run safe.
2. A key that does not match the configured project is a stop, not a reason to create a
   second Epic. Report it and end the run: the spec points somewhere this configuration
   cannot reach, and only a human knows which of the two is wrong.
3. **When there is no line**, create the Epic:
   - Summary is the spec's h1 title, with any leading ordinal stripped (below).
   - Description is the spec's URL as a link and one sentence of purpose. **Not a copy of the
     spec.** The standard's own rule is to link authoritative material rather than duplicate
     it, and a copied spec goes stale the first time the spec changes.
   - The URL is the one a teammate can open: the artifact repo's web URL for
     `efforts/<slug>/spec.md`, derived from its remote. Never a path on your filesystem.
   - The type is `Epic`, literally, and not `tracker.issueType`. That key is the type the
     effort's tickets get. If the team ever adopts a fixed Epic taxonomy, this step becomes
     reading a configured parent key instead of creating one.

   ```
   node docs/agents/gauntlets/markdown-to-adf.mjs "$epicbody" > "$adf" &&
     acli jira workitem create \
       --project "$project_key" --type Epic \
       --summary "$summary" \
       --description-file /dev/stdin --json < "$adf"
   ```

4. **Write the key back into the spec header as `Epic: <KEY>`, commit and push, before any
   issue is created.** An Epic whose key was never recorded is the one duplicate this
   procedure can still avoid for free.

## Step 2: each draft, in a fixed order

Process the effort's drafts in ascending number order. For each one:

**Skip it when it already carries a key.** A line matching `^[[:space:]]*[*_]*Jira:` means
this draft was published. Say so and move on. Do not re-check it, do not re-create it, and do
not edit the issue it names.

Then, in this order and no other. Each gate runs on the draft that passed the one before it.

### 1. The `issue` gauntlet

Load the `gauntlet` skill. Run point `issue`, subject the draft's path. The gauntlet runs
from the artifact clone, which is where the declared command resolves.

- **failed**: this draft stops here. Report the captured output verbatim and move to the next
  draft. Nothing is shown to the human for approval and nothing reaches Jira, because a
  reader's attention is the scarce thing and a machine already found the problem.
- **not run**: carry the words `not run` to the human gate unchanged. Nothing checked the
  shape of this draft. Never write, summarise or imply that as a pass.
- **passed**: continue.

### 2. The review, in a fresh subagent

Load `review-draft-issue` in a **fresh subagent** carrying none of this session's context.
That is the whole point: the human about to approve this text watched it being written, and
the review exists to put a reader in front of it who did not.

**The attempt is the test.** The one thing this step looks up is the `absent` declaration below,
and it reads the machine record only to find it. Everything else it learns, it learns by
spawning and then reporting how the review actually ran. The attempt is a valid test here
because the thing attempted is provided by the host and its absence errors, so a host that
cannot spawn says so instead of silently running the review in this session.

Deciding from a declaration instead would be worse in the ordinary case. A host whose C5 answer
is `unknown` is a host nobody has written down, not a host that cannot spawn, so treating
`unknown` as a reason to degrade would skip a review that works on most hosts. The attempt costs
one failed call where it is wrong and nothing anywhere else. This is deliberately unlike C6,
which does get the full declaration treatment.

**The one exception is an `absent` declaration.** Read the slug from the machine record, then
read C5 from under the `## Capabilities` heading of `<plugin root>/adapters/<slug>.md` where the
plugin ships one for that slug and `$HOME/.devflow/adapters/<slug>.md` where it does not:

```
jq -r '.hostSlug // empty' "$HOME/.devflow/machine.json"
```

Where that adapter declares C5 `absent`, skip the attempt and report `review not run, C5 absent`.
That is the only declaration this skill reads, and it reads it only to avoid a call already known
to fail. No slug recorded, no adapter for the one recorded, no C5 answer, or any answer other
than `absent`: attempt the spawn.

The review **never blocks**, however it ran. It produces findings, it changes nothing, and a
finding is not a veto. Carry its output to the human whether it found something or not. A spawn
that fails is reported as `review not run` with what the host said, and the draft goes on to the
human gate. A review that did not run leaves the draft one reader short; it does not fail the
publish.

**One state, one phrase.** `review not run` is the phrase, in the words the handover already
uses, wherever that state appears: at the human gate, in the line for a draft that was not
published, and in the line for one that was. Nothing may be left to silence here, because
silence reads as a review that ran and found nothing.

### 3. The human gate

Ask the human about **this draft, on its own**. Do not offer to approve a batch, and do not
carry an earlier approval forward: approving each issue individually is why the board only
receives work somebody stands behind.

Show, for the one draft:

- the summary exactly as it will be sent, after the ordinal is stripped;
- the gauntlet verdict, including `not run` when that is what it was;
- the review's findings verbatim, or `review not run` and why, when it did not;
- the parent epic key, the project and the issue type;
- that no label and no status transition will be written.

Anything but approval means skip. Move to the next draft and report it as not published.

### 4. `acli jira workitem create`

Build the call from the draft. The field mapping is fixed:

| Part of the draft | Where it goes |
| --- | --- |
| The h1 title, ordinal stripped | `--summary` |
| The five standard sections | `--description-file /dev/stdin`, as converted ADF |
| The spec epic | `--parent` |
| `tracker.projectKey`, `tracker.issueType` | `--project`, `--type` |
| `## Parent`, `## Blocked by` | not the body: parent is `--parent`, blocking edges are step 3 |
| A label of any kind | nowhere. There is no `--label` on this call |

**Strip a leading ordinal from the title before it becomes the summary**, with exactly
`^[0-9]+[.:)][ \t]*`. The `issue` check strips the same prefix before asserting on the
summary, so `# 01: Implement the frontier query` fails the check on `Implement`. Sending the
ordinal to Jira would make the gate and the board disagree about what was asserted.

**The description is the five sections and nothing else.** Copy each required h2 heading and
everything under it up to the next h1 or h2, in the standard's order. A level 3 subheading
divides a section rather than ending it. Everything else in the draft, the title, the header
lines, `## Parent` and `## Blocked by`, stays in the file.

**Convert to a file first, then feed that file on standard input.**

```
node docs/agents/gauntlets/markdown-to-adf.mjs "$sections" > "$adf" || exit
acli jira workitem create \
  --project "$project_key" --type "$issue_type" \
  --summary "$summary" --parent "$epic_key" \
  --description-file /dev/stdin --json < "$adf"
```

A pipeline hides this trap: when the converter exits non-zero the pipe still reaches `acli`,
which creates the issue with an empty description. Check the conversion, then publish. A
refused conversion, a markdown image being the designed case, is reported against the draft
and nothing is created.

Write the temporary files outside the artifact repo so an interrupted run leaves nothing to
commit.

### 5. The key write-back, committed and pushed

**The moment `acli` returns.** Read the key from the `--json` output. Do not assume a `jq`
path that was never verified against a live site: the key is the one
`<tracker.projectKey>-<digits>` token the output carries, and reading it that way survives a
shape you have not seen.

Add `Jira: <KEY>` to the draft's header, beside its `Status:` line, then `git pull --rebase`,
commit and push. Only then move to the next draft.

**If the key cannot be read, stop the whole run.** The issue probably exists and you cannot
name it. Say so, and say that the next run will not know about it.

## Step 3: the blocking links, once every key exists

A second pass, after the last draft is published, because a link needs both ends and the
first draft's blocker may be the last draft published.

For each draft that has a key, read its `## Blocked by` section. Each entry names another
draft in the same effort; that draft's `Jira:` line gives the blocker's key. An entry naming
no draft in the effort, or naming a draft with no key, is **reported and skipped**. Never
guess a key and never search Jira for a summary that looks similar.

**The inward flag is the blocker.**

```
acli jira workitem link create --in "$blocker_key" --out "$blocked_key" --type Blocks --yes
```

**Do not trust the confirmation line.** `acli` 1.3.36 prints the two keys the wrong way
round: a link created with `--in A --out B` is confirmed as `B Blocks A` and is in fact
`A blocks B`. This is verified against the rendered issue, not inferred.

**Read the direction back from the issue's own link fields.**

```
acli jira workitem view "$blocked_key" --fields issuelinks --json
```

The counterpart under `inwardIssue` is what the viewed issue is **blocked by**; the
counterpart under `outwardIssue` is what it **blocks**. `link list` cannot answer this: it
emits no inward key at all, so the far end comes back null exactly when you need it.

The same read makes the pass repeatable. Check before creating: a blocker already under the
blocked issue's `inwardIssue` for the `Blocks` type is done, and creating it again is a
duplicate link somebody has to delete. A link that reads back the wrong way round was created
backwards, so delete it with `acli jira workitem link delete --id <id> --yes` and report it
rather than leaving the board asserting the reverse of the truth.

Only the type **name** `Blocks` is accepted. The phrasings `blocks` and `is blocked by` are
rejected, whatever the flag's help text says.

## What is never written

- **No label of any kind.** Not a triage role, not a readiness marker, not a tag naming this
  flow. This flow's issues are past triage by construction, and a readiness label on them
  reads as progress that nobody made. A label this flow writes is also a label somebody has
  to maintain.
- **No status transition, ever.** Publishing creates issues and does nothing else to them.
  The board should reflect what the team and the release pipeline actually did.

Neither is an oversight, so do not add either because an issue looks like it wants one.

## The duplicate window, accepted

A session that dies between `acli` returning a key and the write-back landing leaves one
Jira issue no draft records. The next run publishes that draft again and the human deletes
one visible duplicate.

**Do not add a JQL pre-check to guard this.** A search for a matching summary before every
create is a second mechanism guarding a window one ticket wide, it is wrong whenever two
tickets share a summary, and it costs a network call per draft forever. The window is one
ticket because the write-back is immediate, which is the mitigation.

## The handover

```
Effort: <slug>
Spec epic: <KEY> (created | reused)

  <NN-slug>: <KEY>
  <NN-slug>: <KEY>, review not run, <spawn failed, <what the host said> | C5 absent>
  <NN-slug>: not published, <gauntlet failed | declined | review not run and declined | ...>
  <NN-slug>: already published as <KEY>

Blocks links:
  <KEY> is blocked by <KEY>: created | already present | skipped, <why>

Not published: <count>. <What the human has to do next.>
```

Report gauntlet output verbatim. A draft that was skipped says why in the words of the gate
that skipped it, so the human fixes the draft rather than the report.

A published draft whose review did not run carries that on its own line, in the same words. The
review is non-blocking and nothing else in this run records that a reader was missing, so the
handover is the only place it can be said.
