---
name: setup-devflow
description: Configure a repository and this machine for the devflow workflow. Run it in any repository the team builds in, after the upstream setup skill has run there, and run it again after a plugin upgrade. It writes team, repository and machine-local state, skipping whatever is already present.
disable-model-invocation: true
---

This is the one command an engineer runs. It refuses on two conditions that would otherwise
produce a half-working flow discovered much later, and then writes three tiers of state,
skipping each tier that is already there.

**Re-running is the recovery.** There is no transaction, no progress file and no rollback,
because every step is idempotent and every tier is detected rather than remembered. If a run
stops halfway, run it again. If a plugin upgrade changes what setup writes, run it again.

## Finding this plugin's own files

Commands below name scripts as `${CLAUDE_PLUGIN_ROOT}/scripts/<name>`. Claude Code substitutes
that variable into this body before you read it, so look at the path in a command before running
it: an absolute path means the variable was substituted, and a path still spelled as a variable
means it was not.

If you run the command with the variable unsubstituted, the shell expands it to nothing, the
command becomes `/scripts/<name>`, and the shell reports a missing file. That is the symptom of
an unset variable, named here in advance so it is not mistaken for a broken install. It is a
known gap in this design, not a fault to work around by guessing at a path.

## Refuse first

Onboarding this machine is three commands in this order, and the first two are the human's:

1. Install the upstream skills: `npx skills@latest add mattpocock/skills -a claude-code`. This
   plugin's phases name those skills and this plugin does not ship them.
2. Run `setup-matt-pocock-skills` in the repository. It carries a key that stops any skill from
   loading it, so the human runs it the same way this skill is run, not you.
3. Run `/setup-devflow`, which is this skill.

Each check below asserts one of the first two. Both run before anything is written, in the order
given, and either one ends the run. Report what the check found, print the three steps above so
the human can see which one they are on, and stop. Do not offer to continue, and do not write a
single file: a refused run leaves this machine and this repository exactly as it found them, and
running the skill again once the named step is done is the whole recovery.

### 1. The upstream setup has not run here

This skill configures a repository that the upstream skills already understand. They learn the
repository's issue tracker from the tracker document that **`setup-matt-pocock-skills`** writes,
and nothing here writes it.

Refuse when the repository has no `docs/agents/issue-tracker.md`, and name
`setup-matt-pocock-skills` as the thing to run. Print the order above with it, because a machine
with no upstream install fails this check too: that skill cannot have run where it is not
installed, and naming it on its own sends the human after a command they do not yet have.

### 2. The upstream dependency is not satisfied

Run, before anything is written:

```
${CLAUDE_PLUGIN_ROOT}/scripts/scan-skill-environment.sh <repository root>
```

It walks the real skill directories on disk and asserts the four ways the dependency can be
broken without anything saying so: a required skill is not reachable, the content is below the
supported floor, a `disable-model-invocation` key has moved between the skills the router names
and the ones it loads, or one bare name resolves to two different directories. A model told to
load a skill it cannot find does not report an error, it proceeds without it, which is why this
is a precondition rather than a warning.

Act on the exit code:

- **0.** The dependency is satisfied. Continue.
- **1.** The dependency is not satisfied. Refuse.
- **2.** The scan could not be performed, and it says why on stderr: a root that exists and
  cannot be read, an unset `HOME`, a repository root that is not a directory. Refuse. A scan
  that did not run is not a scan that passed, and treating it as one restores exactly the silent
  failure the probe exists to remove.

On either refusal, print two things: the install command below, then **the probe's own output,
verbatim**. Write nothing in their place.

```
npx skills@latest add mattpocock/skills -a claude-code
```

Each finding line already names its kind, its subject and what failed it; a summary written here
would be a second description of the same facts, free to drift from the script that is the
authority on them.

#### A duplicate is the one finding the human has to decide about

Skills invoke each other by bare name. A second copy resolves silently rather than failing, so a
skill can load somebody else's version of the one it meant to call and behave as a slightly
different skill. A `duplicate` line names the bare name and every real directory serving it.
**List those paths and say to keep one.** A refusal that says "remove the duplicate skills" sends
someone hunting; a refusal that names directories is a task. Say what the three usual sources
are so the human knows which removal command applies: a real second directory under one home
skills root where the supported install leaves only a symlink, copies written into a personal
skills directory by an installer script, and a project-scoped copy inside the repository itself.

Removing is the human's act. Do not remove, move or rename anything outside the repository being
configured.

## How every tier writes

- **Show the diff before writing.** Every file this skill creates or changes is shown as a diff
  against what is there now, before anything is written. The user may reject it, and a rejected
  diff is not written. This holds for a file that does not exist yet: show the whole proposed
  content.
- **Merge, never overwrite.** A file the repository already owns keeps everything it has that
  this skill is not responsible for.
- **A tier already present is skipped**, and the run says which tiers it skipped. The second
  engineer in an already-configured repository therefore runs the same command and writes the
  machine-local tier alone, with no second command and no flag to pass.

## The tiers

A **tier** is scoped by what the state belongs to, which is not the same as who reads it.

| Tier | Writes | Detected by |
| --- | --- | --- |
| Repository, committed | the workflow configuration, the gauntlet declarations, the merged committed host settings, the copied checks | their presence in the code repository |
| Machine-local | the dependency probe, the additional-directory entry, the Node assertion, the sibling artifact clone | their presence on this machine |
| Team | the artifact repository's own configuration and agent instructions, the issue standard, the converter | their presence in the artifact repository clone |

The table is ordered the way the tiers must run when more than one is absent, and the order is a
data dependency rather than a preference: the repository tier writes the artifact remote that the
machine tier clones, and the machine tier creates the clone that the team tier writes into. A
tier whose input is missing says so and is skipped, rather than guessing the input.

Each tier's procedure is its own file. Read only the file for a tier the detection above says is
absent.

1. The repository, committed tier: [references/repo-tier.md](references/repo-tier.md).
2. The machine-local tier: [references/machine-tier.md](references/machine-tier.md).
3. The team tier: [references/team-tier.md](references/team-tier.md).

## Closing

Print what was written and what was skipped, then verify. These verifications run **every time
this skill runs**, including a run that skipped every tier, because what they guard against
regresses on a plugin upgrade rather than on anything happening in the repository. Re-running
this skill after an upgrade is therefore the moment they are meant to fire. The dependency probe
at the head of the run belongs to the same set and has already run by the time this prints: an
upstream upgrade can move a skill or a key under a repository that has not changed, so it is
asserted on every run rather than once at onboarding.

- **Check the committed host settings are as specified.** Read the repository's
  `.claude/settings.json` and assert two things: `Bash(git stash:*)` is present in
  `permissions.deny`, and `worktree.symlinkDirectories` is present and empty unless the user
  asked for values in it. Report each as a line, naming the file. A merge that silently dropped
  one of these leaves worktrees sharing a stash with no warning anywhere else.
- **Check the executable bit survived.** Assert it on the scripts in this plugin's own scripts
  directory and on every file the installer copied, in **both** destinations: the code
  repository and the artifact repository clone. A check without the bit
  is unrunnable, and the contract makes an unrunnable check a **failure** rather than a skip, so
  a lost bit turns every gate red at the worst moment. Report the paths that lack it.
- **Tell the user to restart Claude Code.** It does not re-read plugin or project configuration
  mid-session, so the session that ran this skill is the one session in which none of what was
  just written is in effect. An engineer who keeps working in it sees a repository that shows no
  sign of the setup and reads the install as having failed.
