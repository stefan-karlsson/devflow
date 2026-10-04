# The team tier

State scoped to the team, written once into the artifact repository clone and shared by
everyone who works from it. The artifact repository holds effort artifacts and draft issues:
maps, specs and tickets that have not yet reached Jira. One per team, not one per code
repository, so a cross-repo effort has one home and a draft ticket has somewhere to sit while
a human reads it.

Read this only when the tier's detection says it is absent. The tier is present when the
clone already holds every file listed under **Detection** below. Each step detects its own
state, so a partial seed completes rather than starts over.

Every step shows its diff before writing, and a rejected diff is not written.

## This tier needs the clone, and does not create it

The machine tier derives the clone's path and creates it. When there is no clone, this tier is
skipped and says so, naming the machine tier as the thing that makes one. Do not derive the
path a second time here and do not clone anything: a second derivation is a second place for
the rule to drift.

**Run every command below from the clone's root.** Every path in this file is relative to it,
including the ones a configuration file will later name, because the gauntlet contract puts the
working directory there for the `issue` run point.

## Setup does not create the artifact repository

Creating the project is the human's act, and setup refuses it rather than attempting it. A
`glab repo create` that half succeeds leaves a project whose group, visibility and
authentication nobody can state, and that is harder to recover from than never having started.
All three are decisions rather than commands.

When the clone fails because the remote does not exist, stop and hand over this checklist,
spelled out rather than summarised as "create the repo":

- **The group it belongs under.** One artifact repository per team, in the team's own group.
- **The project name**, which is the last segment of the `artifacts.remote` already in the code
  repository's configuration. If that key is absent too, the repository tier writes it, and the
  name is agreed before either is written.
- **The visibility decision.** The repository carries unpublished ticket drafts and effort
  specs. Whether that is internal or private is the team's call and nobody else's.
- **Working authentication for the host it lives on**, proved by a command that reads something
  only an authenticated user sees, not by a token being present in a file.
- **An initial commit on the default branch.** An empty repository with no branch has nothing to
  pull or rebase onto, and every write rule below assumes a default branch exists.

Then say that re-running this skill is how seeding happens, so the human does not go looking for
a second command. Re-running is the recovery for every half-finished state here.

## Detection

The tier is present when all five of these are in the clone:

- `docs/agents/workflow.json`
- `AGENTS.md`
- `docs/agents/jira-issue-standard.md`
- `docs/agents/gauntlets/markdown-to-adf.mjs`
- `docs/agents/gauntlets/issue-standards.sh`

That is five paths for four seeding steps: the converter arrives with the `issue` check, and
the two are installed and detected together because neither is usable without the other.

Detection is **presence, never content**. The standard and the agent instructions are the
team's to edit the moment they are seeded, so a check that compared them against the plugin's
template would report every team's own writing as drift and re-seed over it.

## The layout this tier establishes

Flat, and fixed rather than configured:

```
efforts/<effort-slug>/
  map.md
  spec.md
  issues/NN-<slug>.md
```

Inside an effort upstream's local-tracker shape is unchanged, which is why the tracker
document this plugin seeds into a code repository changes its root path and not one convention.
Grouping by code repository first would reinstate the exact problem the repository exists to
solve. Create no effort directory here: `efforts/` fills when the first effort is charted, and
an empty example directory is a thing somebody later has to delete.

## The four files

Seed what is absent and leave what is present. Order does not matter.

### The configuration

`docs/agents/workflow.json`, at that one fixed path, the same path the data surface carries in
a code repository. One section and nothing else:

```json
{
  "tracker": {
    "site": "example.atlassian.net",
    "projectKey": "ABC",
    "issueType": "Task"
  }
}
```

Take the three values from the code repository's own `docs/agents/workflow.json`, which the
repository tier has already written. Asking again invites two answers to one question.

**No `artifacts` section and no `pullRequests` section.** This repository is not a code
repository: it has no artifact repository of its own and nothing opens a merge request against
it. There is no `devflow.version` stamp either, because the router compares that stamp against
the code repository it is running in and a second copy here would be compared by nothing.

The `issue` check reads this file relative to the working directory, so it is the reason the
tier exists at all rather than a convenience.

### The agent instructions

`AGENTS.md` at the clone's root. It says two things and needs to say no more: this repository
holds effort artifacts and draft issues, and code belongs elsewhere. State the flat layout under
it so a session charting a cross-repo effort from inside this repository knows where to write
without a special rule.

Merge, never overwrite. A repository that already has an `AGENTS.md` keeps everything in it.

### The Jira issue standard

Seed `<plugin root>/templates/jira-issue-standard.md` into
`docs/agents/jira-issue-standard.md`. The plugin-root mechanic and its failure symptom are in
this skill's own body; the same rule applies here.

**Seeded once and never touched again.** The template ships the five section headings and the
mechanical rules about them. The team's actual writing guidance is content they author into
their copy, and a later run that re-seeded it would delete exactly the part worth having. This
is why the standard is copied plainly and **not** through the payload installer: the installer
refuses a file that differs from the plugin's source, so putting the standard through it would
turn the team's own edits into a hard refusal on every later setup run.

One copy, at that path, with no per-repository override. A repository wanting different ticket
rules is a different team, and a different team gets a different artifact repository.

### The converter and the check

One installer invocation carries both, into one directory:

```
<plugin root>/scripts/install-payload.sh payload/artifact-repo docs/agents/gauntlets
```

`issue-standards.sh` finds the converter as **its own sibling**, resolved from its own location
rather than from a configured path. That is what makes the pair config-free, and it is also why
they may never be separated. One invocation rather than two is not tidiness: two invocations are
two chances to put them in different places.

`docs/agents/gauntlets/` is the same directory name the same two checks land in inside a code
repository, so one name means one thing on both sides of the flow.

The spec says the converter lands "beside the standard", and in this layout that means the same
`docs/agents/` subtree rather than the same directory. The sibling relationship that is load
bearing is the one between the check and the converter, and that one is literal.

The installer prints facts and runs no git. It refuses on drift and has no flag that silences
the refusal; a deliberate re-copy is the human reverting or deleting the differing file. It
reports orphans and deletes nothing. Read its output to the user.

## Writing to the artifact repository

These rules govern this tier's own seeding and every later write any skill makes here. They are
written once, in this file, because the repository is the thing they are about.

- **Writes go straight to the default branch.** No branch, no merge request. Efforts are
  directory scoped, so the only real collision is two sessions inside one effort, and the
  claim line in a ticket already handles that.
- **`git pull --rebase` immediately before every write.** Not once at the start of a run and not
  once per skill: immediately before each write, because the window that matters is between
  reading and writing.
- **Commit and push what this tier seeds**, in one commit, before reporting the tier done.
  The consequence that matters, and the reason the push is not deferred: **a claim must be
  pushed the moment it is made, because an unpushed claim is a local note.** A teammate's
  session cannot see a commit that never left the machine, so it takes the ticket somebody here
  believes they already hold. A resolution and its map append likewise go in one commit, so the
  decisions a map records never point at a ticket the remote still shows open.
- **Nothing is archived and nothing is deleted.** An effort carries `Status: active | done` in
  its map, set by whoever resolves its last ticket.

**A worktree-isolated worker cannot write here at all.** The host refuses a git command whose
shape it cannot verify stays inside the worktree, so only non-isolated sessions, the
orchestrator and planning sessions reach this repository. This is a host behaviour rather than a
policy, which means no design may place a worker write here and expect to discover the problem
in review.

**No file in a home directory is read or written by any of this.** The standard, the
configuration and the drafts all live in the repository, because what one engineer's machine
publishes has to be what their teammate's machine publishes.

## What this tier never writes

- **The clone's path, anywhere.** It is derived by the machine tier and committed by nobody.
- **A `devflow.version` stamp**, for the reason under the configuration above.
- **A triage mapping**, here or anywhere else.
- **An effort.** Charting one is a session's work, not setup's.

## Verification, before reporting the tier done

Over what was just written, from the clone's root:

```
jq -e . docs/agents/workflow.json
```

Then assert the pair landed together and the executable bit came with them: both files are in
`docs/agents/gauntlets/` and both are executable. A declared check without the bit is vacuous,
so a lost bit on the converter would turn the `issue` run point red for the whole team with
nothing naming the cause.

The committed mode carries the bit to everyone else, so this is worth asserting once here rather
than per teammate.

The closing section of this skill's own body runs the rest, every time setup runs. Do not repeat
it here.
