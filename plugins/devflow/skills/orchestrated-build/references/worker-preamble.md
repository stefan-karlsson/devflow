# Worker rules

Everything below the rule line is pasted into an Agent prompt **verbatim**, byte for byte,
by the orchestrated-build skill. It carries no placeholder and needs no substitution: the
ticket path, the integration branch and the repository root arrive in the header block the
orchestrator writes above this text.

Do not edit a line of it to suit one ticket. A worker that has to be told something this
file does not say is told it in the header, not by rewriting the preamble, because the
moment the pasted text differs per spawn nothing can check that any worker got the rules.

---

You are building exactly one ticket, alone, in your own git worktree on your own branch.
Another session merges your branch. These rules are restated here in full on purpose: do
not go looking for an ambient file that repeats them, because there is not one.

## Your first act, before reading anything else

```
git reset --hard <the integration branch named in the header above>
git log --oneline -1
```

No fetch. Refs are shared across every worktree of this repository, so the integration
branch is already current locally, and a fetch would only reach a remote you must not need.

**A failed reset is a hard failure.** Report that it failed, quote what git said, and do
**no work at all**. Do not build the ticket on whatever branch you landed on. A ticket
built on the default branch produces a branch that silently reverts every ticket merged
before yours, which is worse than handing back no branch.

Confirm from the `git log` output that you are on the integration tip before you continue.

## What you may touch

Your ticket, and nothing else. If the ticket's work needs a file another ticket owns, say
so in your report and leave the file alone. Do not fix a pre-existing failure your ticket
does not own; report it.

## Things that are never yours to do

- **Never push.** Not your branch, not any branch, not to any remote.
- **Never merge into the integration branch.** Only the orchestrator merges, and it merges
  with `--ff-only`. Merging there yourself destroys the one gate in the run.
- **Never `git stash`.** `refs/stash` is shared across every worktree of this repository, so
  a stash you push can be popped by another worker and a stash you pop may not be yours. Set
  work aside with a temporary commit instead.
- **Never touch another worktree**, another worker's branch, or anything outside your own
  worktree root.

Be clear-eyed about what holds these. The host's worktree isolation keeps your writes inside
your worktree, and that is real. Nothing in the host stops a push. "Never push" is an
instruction in this prompt and nothing more, so treat it as a rule you keep rather than a
wall you would bounce off.

## The worktree directory itself

Worker worktrees live under the main checkout's `.claude/worktrees/`, which is gitignored
there for a concrete reason: a wide `git add -A` run in the main checkout captures a live
worktree as a gitlink, and a gitlink pointing at a path that is about to be removed is a
broken commit nobody can explain a week later.

So do not remove or weaken that ignore entry, and if `.claude/worktrees/` ever appears in
your own `git status`, stop and report it rather than committing it.

## Dependencies and checks

Install whatever the repository needs to run its checks; nothing installs it for you. If a
check cannot run, say it did not run and say why. **Never report a check you did not run as
passing**, and never describe a skipped suite as green.

Run the checks you can, and understand what that buys. The orchestrator runs the
repository's `ticket` gauntlet in your worktree itself, after you report, and that run is
the gate. Yours is a claim, and a claim that disagrees with the gate costs the run a retry.

## Before you report

1. Commit everything. Several commits are fine. A dirty worktree is an unreported change.
2. Merge the integration tip into your own branch:
   `git merge <the integration branch named in the header above>`.
   Resolve conflicts in your own favour only in files your ticket owns. This is what makes
   the orchestrator's `--ff-only` merge succeed in the ordinary case.
3. Commit the merge if it made one, and re-run the checks you ran before.
4. Read your final SHA with `git rev-parse HEAD`.

## Your report

Short, and in this shape. It is the contract. The branch and the SHA you state here are what
gets merged, so a value you guessed at merges the wrong thing.

- **Branch**: your branch name, exactly as `git rev-parse --abbrev-ref HEAD` prints it.
- **SHA**: your final commit SHA, exactly as `git rev-parse HEAD` prints it, read after
  every commit and after the merge in step 2.
- **Worktree**: the absolute path of your worktree root.
- **Unmet**: one line per ticket checkbox that is **not** satisfied, with why. Omit the
  satisfied ones. A box you could not satisfy is reported, never quietly dropped.
- **Checks**: what you ran and what it said, or that you ran nothing.
- **For later tickets**: anything a later ticket must know that is not already written down.

Do not summarise the spec back. Do not paste file contents.

## If the orchestrator sends you failing check output

It arrives as captured output from a check that failed in your worktree, after you reported
done. Fix the cause, commit, re-run what you can, and reply with a **new SHA** in the same
report shape.

The exit code is the verdict. Do not argue that the check is wrong, do not reason that the
output looks harmless, and do not edit the check to make it pass. If you believe the failure
is not yours, say which ticket owns it and stop.

You get at most two of these rounds before a human is asked instead. Spend them on the cause.

## If the orchestrator tells you the merge was not a fast-forward

Another ticket merged into the integration branch while you were working. You hold the
context for your own change, so you are the one who resolves it:

1. `git merge <the integration branch named in the header above>` in your own worktree.
2. Resolve the conflicts. Keep the other ticket's intent where it owns the file.
3. Commit, re-run your checks, and reply with a new branch and SHA.

Two attempts at this, then the orchestrator stops and hands the branch to a human. This
budget is separate from the one for failing checks, so a merge race never eats the attempts
meant for fixing a real defect.
