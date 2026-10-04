---
name: develop
description: Start or resume an effort and say which phase it is in. Use when work on a spec begins, when a session picks up an effort somebody left half-built, or when an engineer does not know what to do next. Reads the configuration and the version stamp and runs the upstream dependency probe, refusing on any of the three, then resolves the effort in the artifact repository and inspects the tracker and the integration branch in a fixed order until the first miss names the phase. Carries the whole flow, from grilling an idea through spec, tickets, publishing to the tracker, the build, the merge request and the retro, naming the build mode rather than discovering it. Loads the procedures the flow needs and names the phase for the engineer to type, so nothing expensive starts without them.
disable-model-invocation: true
---

# Develop

One command to remember. It says which phase an effort is in and names the one thing to type
next.

**It never starts a phase.** Expensive work begins when the engineer types the phase, not when
you decide they are ready. You load the procedures that cost nothing to load, you name the
phase, and you stop.

**It restates nothing another skill already says.** Every phase below names its owner and says
no more. One description of each thing is what keeps the two from drifting apart. There is one
deliberate exception and it is labelled as one.

**Review is not a phase.** The build skills close with their own code review. A review phase
here would either duplicate that or run a second one that never comes back clean.

## Before anything, four times over

All four run at this skill's own start, which is the moment `/develop` is typed, before the
effort is resolved and before any phase is named. Nothing here runs earlier than that: a skill
is inert text until a model loads it, and this plugin registers no `SessionStart` hook.

**Run every one you can and refuse once, carrying all of them.** They are independent, with a
single exception: the probe is reached through the plugin root the machine record holds, so a
missing record leaves the probe unrun, and you say it did not run rather than dropping it. Do
not stop at the first failure. A machine with neither a configuration nor a record has two
things to fix, and learning about the second one after fixing the first is two round trips for
one answer.

### The configuration parses, and declares nothing you do not know

```
jq -e . docs/agents/workflow.json >/dev/null
```

One fixed path. Do not search for it and do not walk up the tree. A non-zero exit means the
file is absent or is not JSON: refuse and name `setup-devflow` as the thing that writes it.

Then list the top-level sections it declares that are not in the known set:

```
jq -r 'keys[] | select(IN("devflow","tracker","artifacts","pullRequests","build","gauntlets") | not)' docs/agents/workflow.json
```

**Flag what comes back; do not refuse on it.** An unknown section is either a key from a newer
plugin than the one running or a typo that will be read by nothing, and both are worth one line
to a human. A *missing* section is not a finding here: a section is required only by the phase
that needs it, and each skill states its own requirement.

### The recorded version and the running version

**devflow version: 0.3.1**. This skill's own stamp, shipped in its body because a version
read from a recorded plugin root would compare a stale install against itself and agree.

That stamp **is** the running version. This skill reads no manifest to find it, and it does not
work out where its own file sits: nothing gives a model the path of the text it is reading.

The recorded stamp is `.devflow.version` in that same file:

```
jq -r '.devflow.version // empty' docs/agents/workflow.json
```

| What you find | What you do |
| --- | --- |
| No stamp, or no configuration section holding one | Refuse. Setup has not run here. Name `setup-devflow`. |
| The major versions differ | **Refuse.** Name `setup-devflow` and say both versions out loud. |
| Same major, different minor | **Warn**, say both versions, and continue. |
| Difference only in the patch | Continue silently. |

An upgrade that moved the configuration under you is the one failure that otherwise shows up
three phases later as a key that is mysteriously absent. This is what makes it loud instead.

### This machine's record, and where the plugin is

The probe below runs a script this plugin ships, and the path to it is built from the plugin
root this machine's record holds. Read the record yourself, with `jq`, at that literal path:

```
jq -r '.pluginRoot' "$HOME/.devflow/machine.json"
jq -r '.devflowVersion' "$HOME/.devflow/machine.json"
```

No shipped script can read it for you, because locating a shipped script is the thing the record
is for.

| What you find | What you do |
| --- | --- |
| No file at that path | **Refuse.** Setup has not run on this machine. Name `setup-devflow`. |
| `devflowVersion` differs from this skill's body stamp above | **Refuse.** The record was written by a different version of devflow. Name `setup-devflow` and say both stamps out loud, the recorded one and this skill's own. |
| They agree | Take `pluginRoot` and build each path below from it, at the point of use. |

The two refusals are separate findings because they send the human to different places: in one
case setup has never run on this machine, in the other it ran before an upgrade. Neither falls
back to a recorded root that still resolves, because a root left pointing at the previous
version's directory still exists and its scripts still run.

**There is no second way to find the plugin root, so do not go looking for one.** Not a host's
plugin cache, not a search of the filesystem for a directory named devflow, not a path that
happened to appear earlier in this session. Each of those finds *an* install, and the record
exists because that is not the same fact as the install this machine is configured to run. A
missing record is a refusal, not a cue to start hunting.

### The upstream skills the flow depends on

The phases below name and load skills this plugin does not ship. Every way that dependency can
fail, it fails silently, so it is read as an exit code rather than judged:

```
<plugin root>/scripts/scan-skill-environment.sh <repository root>
```

`<plugin root>` is the path you just read out of the record. Build the real path before running
the command; nothing in this body expands it for you.

**Run it on its own and read its own exit code.** Bundled into a compound command with anything
else, the status that comes back is the last command's, so a probe that passed arrives here as
a scan that could not be performed and refuses a machine that is fine. Everything below turns
on that code, which means it has to be the probe's.

**Exit 0 continues the run, and you state what the probe found.** Say the counts it printed,
`skills-before`, `skills-after`, `devflow-adds` and `findings`, in this session. A bug report
that is really a version skew then carries the state it skewed from.

**Any other exit refuses.** Hand back the probe's own lines unedited, name each one as what
failed, and state the requirement behind them: **the upstream skills this flow loads resolve
by bare name on this machine.** devflow ships no copy of them. That requirement holds on every
host, so it is stated on every refusal here, with no command inside it.

**The command that satisfies it here is printed in addition, where it can be read.** It is
slot 6 of this host's adapter. Read the slug from the record you already have open, then read
slot 6 from `<plugin root>/adapters/<slug>.md` where the plugin ships one for that slug and
`$HOME/.devflow/adapters/<slug>.md` where it does not:

```
jq -r '.hostSlug // empty' "$HOME/.devflow/machine.json"
```

- **A command.** Print it under the requirement, as the way this host installs them.
- **The adapter answers that this host has no equivalent.** Say so in one line, rather than
  printing nothing: there is no install command for this host and the requirement stands.
- **No slug recorded, or no adapter for the one recorded.** Say no host is declared on this
  machine, so devflow has no command to give, and name `setup-devflow` as where that is
  decided.

Exit 2 is a scan that could not be performed, which is not a pass. Refuse on it too, and say the
scan did not run rather than letting it read as a dependency that is missing.

**A `below-floor` finding refuses like every other finding.** It belongs to this check and not
to the version table above, which is about this plugin's own stamp: a machine below the floor is
a machine whose skill names may have moved, whatever upstream's version number did. There is no
warning class here.

## The keys this skill needs

Two beyond the stamp, both read below: `artifacts.remote` resolves the clone the effort lives
in, and `pullRequests.branchPattern` is how a ticket branch is recognised. Read them from the
same fixed path:

```
jq -r '.artifacts.remote // ""' docs/agents/workflow.json
jq -r '.pullRequests.branchPattern // ""' docs/agents/workflow.json
```

An empty answer is a miss. Refuse, naming the skill and the key:

- *"develop needs `artifacts.remote` in `docs/agents/workflow.json` to find the artifact repo,
  and it is not there. Run `setup-devflow` to write it."*
- *"develop needs `pullRequests.branchPattern` in `docs/agents/workflow.json` to recognise this
  effort's ticket branches, and it is not there. Run `setup-devflow` to write it."*

Nothing else in the configuration is required here. Every other key is required by the phase
that reads it, and that phase declares it.

## Entry

`/develop [effort-slug]`.

An **effort** is one spec and its tickets. It lives in the artifact repository, reached as the
sibling clone `setup-devflow` creates, at a path derived rather than stored. Every path below
is relative to that clone's root.

**Check the clone is there, because a clean setup does not guarantee one.** `setup-devflow`
skips the clone where the artifact repository does not exist yet and reports that tier skipped
rather than failed, so a machine can finish setup with nothing wrong and arrive here with
nowhere to keep a spec. Derive the path the way setup does, a sibling of this repository's
checkout carrying the remote's own repository name, and check it holds a git repository whose
origin is `artifacts.remote`.

**Refuse when it does not, and print the path you looked at.** Naming the path is most of the
help: the remote's group path and the checkout's parent directory need not be the same shape,
so an engineer who cloned the artifact repository where their own tree puts it sees in one line
why devflow looked elsewhere. Name `setup-devflow` as the thing that makes the clone, and say
that it refuses to create the repository itself where that is the part that is missing.

Skipping this check does not produce an error. The first row of the inspection below misses,
names **Grill**, and sends the engineer off to build a spec that `/to-spec` will then try to
write into a directory that is not there.

**With no slug:** list the directories under `efforts/` and offer a new effort. Do not guess
from the branch you are on, and do not pick the most recently modified one.

**With a slug:** use it. A slug naming no directory under `efforts/` is a new effort, and you
say so rather than failing.

## The inspection that names the phase

Entry and resume are the same act: one inspection, in this order, with **no state file**. The
first miss names the phase. Stop at the first miss; do not run the rest of the table.

| Test, in order | First miss means |
| --- | --- |
| `efforts/<slug>/spec.md` exists | **Grill** |
| `efforts/<slug>/issues/` exists | **Tickets** |
| Every draft in `issues/` carries a key line matching `^[[:space:]]*[*_]*Jira:` | **Publish** |
| The integration branch exists | **Build** |
| Every ticket branch for this effort is merged into it | **Resume the build** |
| Nothing missed | **Ship** |

Nothing else is consulted. The tracker and the branch are the state, so there is no second
record that can disagree with the first.

**The integration branch for an effort is `integration/<effort-slug>`.** One name, derived from
the slug, stored nowhere. Ticket branches are named by the `pullRequests.branchPattern` in the
configuration, which encodes the ticket key, so `git branch --merged integration/<slug>` answers
the last two rows without anything having written down what was done.

Say which test missed and which phase it names. An engineer who disagrees with the verdict can
then see what you read.

## The flow

Eight phases follow entry. For each, you either **load** a procedure, which costs nothing and
needs no permission, or you **name** a phase for the engineer to type, which is where the
expense starts.

| Phase | You load | You name |
| --- | --- | --- |
| 1. Grill | `grilling`, `domain-modeling` | nothing |
| 2. Prototype | `prototype` | nothing |
| 3. Spec | nothing | `/to-spec` |
| 4. Tickets | nothing | `/to-tickets` |
| 5. Publish | `publish-issues` | nothing |
| 6. Build | see below | `/implement-spec` **or** `/implement` |
| 7. Ship | `gauntlet`, `pr` | nothing |
| 8. Retro | nothing | `/retro` |

### 1. Grill

Load `grilling` and `domain-modeling` and work in this session. Both are loadable, so there is
nothing for the engineer to type.

### 2. Prototype

**Only when a question needs running code to answer.** Load `prototype` in this same session
and come back to the grilling when it has answered. Nothing moves to another session, another
directory or another person in either direction, because the detour is not a change of venue.

Skip this phase when no such question is open. It is not a step on the way to a spec.

### 3. Spec

Name `/to-spec`. It produces `efforts/<slug>/spec.md`.

### 4. Tickets

Name `/to-tickets`. It produces `efforts/<slug>/issues/NN-<slug>.md`, one draft per ticket.

### 5. Publish

Load `publish-issues` and let it run. It owns the epic, the per-draft gates, the human
approval, the issue creation and the key write-back, and it is the only thing that talks to the
tracker.

This phase sits before the build on purpose: the cheapest place to correct scope is before any
code is written.

### 6. Build

**Name `/implement-spec` by default.** Load `orchestrated-build` first: it is your parent-side
rules for the run, and `/implement-spec` is typed **in this same session**, which is the session
those rules govern.

**Name `/implement` for a single-ticket effort.** One ticket builds inline, in the engineer's own
session, with nothing spawned and no worktree. A fan-out for one ticket costs a worktree, a branch
and a merge to deliver what `/implement` already delivers.

**Say which you named and why, and take the override.** The engineer may go either way: the right
number of workers depends on the spec in front of them, not on the ticket count alone.

Either way the `ticket` gauntlet gates each ticket, and the skill that just ran the build says
how.

### 7. Ship

Load `gauntlet` and run the `integration` run point against the integration branch. A failure
ends the phase here: hand back the captured output and name nothing further.

On a pass, push the integration branch and open **one merge request for the spec**, loading `pr`
for the body. One merge request, whatever the ticket count.

### 8. Retro

Name `/retro`.

## Context hygiene

**A deliberate exception to the rule against restating another skill.** It is stated here
because the skill that owns phase boundaries cannot be loaded by a model, and the cost of
saying nothing is a whole flow run in one exhausted window. It is one rule and it names no
mechanism:

- **Keep grill through tickets in one unbroken window.** The spec is built out of what the
  grilling established, and a cleared context rebuilds it worse than it remembers it.
- **At every other boundary, state what the next phase needs and leave the clearing to the
  engineer.** Say it in a sentence or two: the effort slug, the phase, and the one or two facts
  the next phase cannot re-derive. Then stop. Whether to clear, compact or carry on is theirs.

## On-ramps

Not everything that arrives is an effort. When one of these walks in, name the skill that owns
it and route there instead of starting the flow.

| What arrived | Whose it is |
| --- | --- |
| Something is broken and the cause is unknown | `diagnosing-bugs` |
| An effort too foggy to grill | `wayfinder` |
| A question that needs reading, not deciding | `research` |
| The codebase itself needs a health pass | `improve-codebase-architecture` |
| A step only a human can perform | `wizard` |
| Somebody needs a questionnaire | `to-questionnaire` |

Naming one is routing, which is this skill's whole job. Saying what one does is not, and it
would be a second description of something that already has one.

**Name it even when it is not installed, and still do not do its work.** All six are optional
by design: the dependency probe lists them as considered and not required, so their absence is
not a finding and nothing earlier in this run will have mentioned it. When the one you name is
not reachable, say so in the same breath, name it anyway so the engineer knows what is missing,
and stop there. Routing to a skill that is absent is still routing. Picking up the work it owns
because it is absent is this skill starting a phase, which is the one thing it never does.
