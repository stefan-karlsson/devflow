---
name: orchestrated-build
description: Parent-side rules for building many tickets at once, each worker isolated in its own git worktree, merging into one integration branch as they finish. Use when a spec's tickets are ready to build and the session you are in is the user's own unisolated session in the main checkout.
---

# Orchestrated build

A multi-ticket spec built one ticket at a time costs a day of someone's attention. Built in
parallel it costs a merge loop, and this is that loop.

**The orchestrator is the user's own session**, in the main checkout, sitting on the
integration branch. It is not an agent and it is never isolated, and that is load-bearing
rather than incidental: an unisolated session can reach into a worker's worktree to run a
check there, and an isolated one cannot.

This is a procedure. It is loaded into the orchestrator session before the human types
upstream's installed build command, and the rules below govern the loop that command runs.
Everything here is **parent-side**. The worker's rules are a separate file, for a reason
given below.

**devflow version: 0.3.2**. This skill's own stamp, shipped in its body because a version
read from a recorded plugin root would compare a stale install against itself and agree.

## The one thing that varies between repositories

The concurrency cap, and nothing else. The merge discipline, the reset contract, the resume
rule and the cleanup policy are the same in every repository, so they live here rather than
in a per-repo prose file that would be copied six ways and drift six ways.

```
jq -r '.build.concurrency // ""' docs/agents/workflow.json
```

**There is no default.** An empty answer, an absent file or one that does not parse is a
refusal, not a number you supply: *"orchestrated-build needs `build.concurrency` in
`docs/agents/workflow.json`, and it is not there. Run `setup-devflow` to write it."* Setup
writes 3 so that the value is in the commit rather than in a reader's head, and a run that
substituted its own number would run at a concurrency the repository never agreed to.

The binding constraint behind whatever number is written is the team's shared rate limits and
your own merge throughput, not the host's subagent limit.

Run no more than that many workers at once. As one finishes and merges, start the next.

## Spawning a worker

Two rules, both absolute.

**Pass `isolation: "worktree"` on the Agent call itself**, on every call, not only in some
definition's frontmatter. A call that omits it puts the worker in the main checkout beside
you, and nothing announces that it happened.

**Give the worker no agent name.** There is no agent definition for this anywhere, and you
must not create one. A *named* worker whose call omits `isolation` becomes a teammate in
your own checkout silently; an unnamed call cannot fail that way. Dropping the name removes
the footgun instead of documenting it. So: no `subagent_type` naming a custom agent, and no
second copy of the worker rules living in an agent file.

### The prompt

The worker's rules reach it **in the prompt, verbatim**. Ambient context is a weak contract
here: a worker that fails to read a file resets onto the wrong base, builds on the wrong
commit, and the failure is silent until a merge reverts work that was already done. Pasting
costs tokens per spawn and buys a rule that cannot be missed.

1. Read [references/worker-preamble.md](references/worker-preamble.md).
2. Write a header naming the three values that differ per worker:

   ```
   Ticket: <path to the ticket file>
   Integration branch: <branch name>
   Repository root: <absolute path to the main checkout>
   ```

3. Paste everything below the preamble's rule line **unchanged**, under that header.

Do not paraphrase it, do not trim it to the parts you judge relevant, and do not substitute
values into it. It is written to need no substitution so that "pasted verbatim" stays a thing
anyone can check by comparing two strings.

Reading a file is safe on this side. You are one session and you can carry your own
discipline; the distrust of ambient context is aimed at the worker, not at you.

## The report contract

**The worker's self-reported branch and final SHA is the contract.** Merge what the worker
said, from the branch the worker named.

The host's own result field is a **cross-check where it is present**, never a source. It is
undocumented, so a loop that depended on it would depend on something that can disappear
without notice.

**A disagreement aborts the merge, loudly.** If the result field names a branch or a SHA and
it differs from what the worker reported, do not merge, do not pick the one that looks right,
and do not reconcile them yourself. One of the two is describing a different worker. Say
which values disagreed, keep the worktree, and ask the human.

## Finding this plugin's own files

Where a section below runs a script this plugin ships, it names it as
`<plugin root>/scripts/<name>`. The plugin root is an absolute path this machine's record
holds. Read it yourself, with `jq`, at that literal path, and build the real path at the point
of use. This sits beside the section that needs it, but the record is read at the **start of
the run**, before the first worker is spawned: a record that is missing or stale is a fault of
this machine rather than of any worker, and finding that out after four workers have reported
wastes all four.

```
jq -r '.pluginRoot' "$HOME/.devflow/machine.json"
jq -r '.devflowVersion' "$HOME/.devflow/machine.json"
```

No shipped script can read the record for you, because locating a shipped script is the thing
the record is for.

| What you find | What you do |
| --- | --- |
| No file at that path | **Abort the run.** Setup has not run on this machine. Name `setup-devflow`. |
| `devflowVersion` differs from this skill's body stamp above | **Abort the run.** The record was written by a different version of devflow. Name `setup-devflow` and say both stamps out loud, the recorded one and this skill's own. |
| They agree | Take `pluginRoot` and build each path from it. |

Neither case resolves the recorded root anyway and carries on. A root left pointing at the
previous version's directory still exists and its scripts still run, which is the whole reason
the stamp is compared rather than the directory tested.

## Whether this loop runs on this host

C6, spawning a subagent isolated in its own git worktree, is what this loop needs, and it is
the one thing in devflow gated on a declaration rather than on an attempt. Read it at the
**start of the run**, under the `## Capabilities` heading of this host's adapter. Read the
slug from the record you already have open, then read the answer from
`<plugin root>/adapters/<slug>.md` where the plugin ships one for that slug and
`$HOME/.devflow/adapters/<slug>.md` where it does not:

```
jq -r '.hostSlug // empty' "$HOME/.devflow/machine.json"
```

No slug recorded, or no adapter for the one recorded, reads as `unknown`: nobody has declared
this host. Where the adapter answers `unknown` and the record's `capabilities` carries a C6
answer a human gave at setup, that answer stands: it is the same declaration, written down
later.

| C6 | What you do |
| --- | --- |
| `present` | Run this loop. |
| `unknown` | **Degrade.** Build the tickets inline, one at a time in this session with nothing spawned, and say C6 reads `unknown` on this host and that is why. |
| `absent` | **Degrade.** The same, naming `absent`. |

`unknown` degrades alongside `absent` rather than being settled by the attempt, which is how
the issue review treats its own capability a phase earlier. What differs is the price of being
wrong. A spawn that was not isolated is discovered only after the worker has reset and
committed in the engineer's own checkout, so there is no cheap attempt to learn from here, only
an expensive one.

**An absent C6 is about C6 and nothing else.** It degrades this loop, and it does not skip the
issue review inside `publish-issues`, which is gated on its own capability and reads its own
answer. Inferring one capability's absence from another's would let a single unanswered adapter
line degrade a phase the host runs perfectly well.

## The isolation check

**Run this the moment a worker's report arrives, before anything else you do with it.** The
position is the rule: it runs first so that a bad path never costs a full check run and never
points a gauntlet at the main checkout. The disagreement rule above costs one merge; this one
costs the run.

In your own checkout:

```
<plugin root>/scripts/worktree-isolation.sh <branch> <reported SHA>
```

Two arguments, the branch and the SHA the worker reported, and no others. Pass the SHA exactly
as the worker printed it: an abbreviated one reads as exit 3 rather than a match. The script
inspects `DEVFLOW_REPOSITORY` and falls back to the working directory, which is your own
checkout, so the ordinary call sets no variable.

It looks the worktree up **by branch in git's own record**, which is the difference between
reasoning about what git knows and reasoning about what the worker claimed.

| Exit | What it found | What you do |
| --- | --- | --- |
| 0 | A worktree holds the branch, it is not the main checkout, and its HEAD is the reported SHA. The path is on stdout | Use **that path** as the gauntlet subject, and go on to the gate |
| 1 | The branch is checked out in the main checkout | **Abort the run** |
| 2 | No worktree in this repository holds the branch | **Abort the run** |
| 3 | Isolated, but HEAD is not the reported SHA | Abort **that merge**, keep the worktree, ask the human |
| 4 | The check could not run, its reason on stderr | **Abort the run**, because an unverified spawn is not a verified one |

**The gauntlet subject is the path the lookup returned**, never the path the worker reported.
The worker's `Worktree:` line is a cross-check only: say so where it differs, and run the
gauntlet in the returned path regardless. A worker reporting a path it never looked at must not
be able to steer where a check runs, and a report with no `Worktree:` line is no longer a case
this skill rules on.

Exit 2 aborts the run rather than the one ticket because a branch no worktree holds is not an
isolated worker whose worktree went missing. It is a worker that was somewhere this repository
cannot see, and a worker in a separate clone must not be mistaken for an isolated one.

Exit 3 costs one merge rather than the run. It is the one-worker severity this skill already
applies to a branch or a SHA disagreement, and a run must not abort for a fault whose blast
radius is one branch.

### Aborting the run

**Report the state of the main checkout first**, before the tidy worktrees, because the human
should read about the damaged thing before the intact ones. Name the branch the unisolated
worker reset and committed on, what your own checkout's HEAD and working tree are now, and what
was uncommitted there before the run as far as you can still say.

Then:

- **Spawn nothing further and merge nothing further.** Keep every branch and every worktree.
- **Stop the in-flight workers where the host allows it, and name the ones you could not**, each
  with its branch. Say their writes are landing in the main checkout, and say plainly that
  stopping limits further writes and undoes none. A best-effort stop is not containment and must
  not be reported as one.
- **No automatic fallback to the inline build.** It would build in the checkout the unisolated
  worker just reset. Name it as the human's next step after they have cleaned up, and leave the
  typing to them.
- **No retry budget.** Not a second attempt and not a third: the tree a retry would run in is
  the compromised one.

**Never write a capability declaration back.** One run's observation does not overrule the file
the verification discipline is built on, and the observation is ambiguous in any case. An
unisolated spawn is either a host that accepted the isolation argument and ignored it, or a call
of yours that dropped it. Name both causes, name the adapter file read above as the file a human
would edit to change the declaration, and change nothing yourself.

**The ordinal changes the diagnosis, not the action.** On a first spawn the two causes are
indistinguishable, and the report says so. On a fifth, after four spawns this check verified,
the host is exonerated and the call convicted: it honoured the argument four times. One
sentence of the report differs, and everything else about the abort is the same.

## The gate

**Run the `ticket` gauntlet in the worker's worktree. Always.** Every worker, every time,
whatever the worker already ran and whatever it reported.

Load the `gauntlet` skill by bare name, give it the run point `ticket` and the worktree path
the isolation check returned as the subject. You are the only thing in the flow that runs a
gauntlet. An implementer reporting its own check results is making a claim, and a claim is not
a gate: the whole point of running it yourself, in that worktree, is that the result is
observed rather than relayed.

A `not run` verdict is not a pass. If the repository declares nothing for `ticket`, say so in
the closing report rather than letting silence read as green.

### When a check fails

Hand the **captured output back to the worker, verbatim**, with `SendMessage` to that worker.
Not a summary, not the interesting lines, not your reading of what went wrong. The worker is
the one that has to act on it and it holds the context for its own change.

Then re-run the gauntlet on the SHA it reports back.

**At most two rounds.** On a third failure, stop working that ticket, keep the worktree, and
ask the human. A third failure is structural, not flaky, and a session that keeps retrying
burns a budget on a defect that is not going to resolve itself.

## Merging

```
git merge --ff-only <worker branch>
```

on the integration branch, in your own checkout, once the gauntlet passed.

The worker merges the integration tip into its own branch before reporting, so a
fast-forward is the ordinary case. What breaks it is another ticket merging in the window
between that merge and yours.

### When it is not a fast-forward

**Resume the worker that owns the change**, with `SendMessage`, telling it the merge was not
a fast-forward. It wrote the change and holds the context; resolving it here would spend your
context on a conflict you did not write, and your context is the scarce thing in a run of
fifteen tickets.

**Two attempts, and this budget is its own.** It is separate from the two attempts for failing
checks, deliberately: an unlucky merge race must not consume the budget that exists for fixing
a real defect. After the second, stop, hand the human the branch and its worktree path, and
move on to the other tickets.

## Worktrees

- **A merged worktree is removed as soon as its merge succeeds.** The branch holds the
  commits, so a merged worktree carries nothing the branch does not. Removing them as you go
  means a run that dies halfway leaves three stale checkouts rather than fifteen.
- The upstream build skill's end-of-run sweep stays as a **backstop**, and it removes only
  worktrees that merged. A failed worker's worktree survives it.
- **A failed worker's worktree is kept**, with its branch, so the work can be inspected.
- The host will never clean either kind up. Its own sweep takes only worktrees with nothing in
  them, and a worktree holding work is by definition not one of those.

**Removing a failed worker's worktree is the human's act, and you must say so when you
report.** Nothing else in this system will ever remove it, so a worktree nobody is told about
sits there forever waiting for something that is not coming.

## A failed worker does not stop the run

A worker that reports failure is never merged, keeps its worktree and its branch, and the run
continues with the remaining tickets. One bad ticket aborting twelve good ones is a worse
outcome than one branch a human has to look at.

## What this loop deliberately does not do

Each of these was priced. None is an oversight, and none should be reinstated without a
reason that is new.

- **No file-level serialisation.** The blocking edges in the ticket graph are the intended
  mechanism for ordering dependent work. Predicting which files a ticket will touch is
  guesswork, and a genuine collision already surfaces as the non-fast-forward path above.
- **No per-merge verification.** The `ticket` gauntlet in each worker's worktree and one
  `integration` run before handover are the whole story. The cost, stated plainly: a break
  introduced by the fourth ticket is found at handover rather than at the fourth merge, and
  attribution then takes a bisect. Accepted, because the expensive case is a semantic conflict
  between two tickets, which a per-merge run catches only sometimes and the `integration` run
  catches properly.
- **No work-state file.** The tracker says what the tickets are, the integration branch says
  which are done, and the branch pattern encodes the ticket key, so `git log` answers a
  resumed build's only real question.

## The boundary that is not enforced

**"Never push" survives only as an instruction in the worker's prompt.** It is not a boundary
the host enforces, and you should not describe it as one.

Claude Code has no per-agent command rules, and a `permissions.deny` entry for Bash is not
path-scoped: a rule denying `git push` would apply to every session in the repository,
including the one that has to push a claim to the artifact repository the moment a claim is
made. The host's isolation checks do stop a worker escaping its worktree, which is the larger
hazard. This one is a known gap, recorded as a gap rather than papered over.

## Closing the run

Report, in one place:

- Every ticket that merged, with its SHA on the integration branch.
- Every ticket that did not, with **the worktree path and the branch name**, what stopped it,
  and which budget it exhausted.
- The explicit sentence that removing a failed worker's worktree is the human's to do.
- Any gauntlet run point that was `not run`, named as not run.

Then the integration branch is ready for its own `integration` gauntlet, which is a different
step and not this one.
