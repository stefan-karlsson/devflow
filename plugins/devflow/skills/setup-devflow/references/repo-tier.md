# The repository tier, committed

State scoped to the code repository and committed to it, so that a teammate's run reproduces
this one and `git log` shows when a value changed. Every artifact here is written **whichever
host runs setup**, because the repository is shared by a team split across the two. Nothing
here is host-scoped and nothing here is machine-local.

Read this only when the tier's detection says it is absent. The tier is present when the
repository holds `docs/agents/workflow.json`. Each step below detects its own state, so a
partial tier completes rather than starts over, and the second engineer in an already
configured repository runs none of the steps below.

Every step shows its diff before writing, and a rejected diff is not written.

## Order

Discovery first, because it is read-only and everything after it is a proposal built from what
it found. Then the copied checks, because the configuration names them by path and a path
should name a file that is already there. Then the configuration, which has to precede the
tracker document because that document's already-present test reads the `tracker` keys out of
it. Then the host settings and the tracker document, in either order. Validation is last, over
what was written.

## What this tier never writes

- **The code remote's URL and the current branch.** Both are facts the environment already
  states: `git remote -v` and `git rev-parse --abbrev-ref HEAD`. Derive them at the moment they
  are needed. `pullRequests.remote` is the remote's *name*, which is a choice among the remotes
  configured rather than a fact read back, and that is written. Configuring a fact the environment states is how the two drift apart, and the drift
  surfaces only when they disagree.
- **An invisible default.** No key is left out on the understanding that a reader substitutes a
  value for it. What runs is what the commit says. `build.concurrency` defaults to 3 by setup
  **writing 3**, not by anything reading an absent key as 3. A value nobody can supply is left
  out of the file entirely, and the operation that needs it refuses by naming the key.
- **Anything in CI.** Consumer repositories live on GitLab, where a GitHub workflow is dead
  text, and writing a pipeline job means guessing at a pipeline nobody here has seen and
  merging into a file every team owns differently. The gauntlet already runs at its three run
  points in session. Say once that the checks are CI-agnostic and the team may wire them into
  their own pipeline if they want a second place to run them.
- **An absolute path.** Six engineers have six home directories. The artifact repository
  clone's path belongs to the machine tier, which derives it.

## Discovery

Discovery runs **at setup time and never at run time**, and it is read-only: it proposes, the
human approves, and **only what the human approves is written**. A command discovered at run
time varies by machine, which breaks the promise that a run reproduces for anyone on the team.

Nothing in the plugin names a build command. Everything proposed comes from something read in
this repository, and a proposal you cannot point at a file for is a guess.

Look for both stacks. A repository may hold both.

- **Node.** Read `package.json`'s `scripts`. Propose the scripts that are declared, under the
  names they actually carry, as the commands that run them. Do not propose a script that is
  not there.
- **dotnet.** Look for `*.sln`, `*.slnx` and `*.csproj`. Propose `dotnet build`, `dotnet test`
  and `dotnet format --verify-no-changes`. `.slnx` is named on its own because .NET 10's XML
  solution format is invisible to a `*.sln` glob, and a team on 10 would otherwise get a silent
  zero with nothing to tell them why. **Match each pattern on its own.** A shell that treats an
  unmatched glob as an error abandons the whole command, so one listing naming all three
  reports nothing on a repository that holds two of them, which is the same silent zero reached
  by a different route.
- Existing CI workflow files and a `Makefile` are further places a command is already written
  down. Propose what you read there. Do not invent a target.

**Several commands may be declared at one run point.** A repository holding a frontend and a
backend declares both under `ticket`, and one gauntlet covers them. Nothing in the contract
ever required one entry per run point; the single-command examples merely implied it.

Finding nothing is a valid outcome. Write the empty array and say that the run point will
report `not run`. Do not fill it with something plausible.

## The copied checks

The plugin owns the source of truth for the checks it ships and copies them in, so the
configuration can name a repository-relative path and the repository keeps working with the
plugin uninstalled. Copying is a script's job, not yours: the case it guards against is exactly
the case where a model has decided a difference does not matter. `<plugin root>` is the path
this skill's own body says to build from the machine record.

```
<plugin root>/scripts/install-payload.sh payload/gauntlets docs/agents/gauntlets
```

The installer prints facts and runs no git. It refuses on drift and has no flag that silences
the refusal; a deliberate re-copy is the human reverting or deleting the differing file. It
reports orphans and deletes nothing. Read its output to the user and commit what it wrote.

Declare each copied check at `ticket` and `integration`, which is what they gate: a ticket
before it merges, the integration branch before the work is handed over. The declaration is the
human's approval like any other, so a repository that authors no skills may decline them and
the copies sit inert.

## The configuration file

One file, `docs/agents/workflow.json`, at that one fixed path. No search and no walking up the
tree. The path carries no plugin name on purpose.

Plain JSON, no comments. `jq` rejects comments outright, and a hand-rolled stripper corrupts
exactly the URL values this file carries. Where a value needs explaining it gets a
`description` key **in the data**, beside the entry it explains and visible in `jq` output.

The key set, and nothing outside it:

```json
{
  "devflow": { "version": "<the running plugin's version>" },
  "tracker": {
    "site": "example.atlassian.net",
    "projectKey": "ABC",
    "issueType": "Task"
  },
  "artifacts": { "remote": "<git URL>" },
  "pullRequests": {
    "remote": "origin",
    "targetBranch": "<the remote's default branch>",
    "branchPattern": "<encodes the ticket key>",
    "draft": true
  },
  "build": { "concurrency": 3 },
  "gauntlets": { "ticket": [], "integration": [], "issue": [] }
}
```

- **`devflow.version`** is the stamp. Write the version the running plugin's manifest states.
  The router compares it at its own start, the moment `/develop` is typed, warning on a minor
  mismatch and refusing on a major one, which is what makes an upgrade loud rather than
  mysterious. Nothing compares it earlier: a skill is inert text until a model loads it, and this
  plugin registers no `SessionStart` hook. Write it under exactly this key, because something
  else already reads it and a second spelling would make the comparison silently never
  happen.
- **`tracker`** carries `site`, `projectKey` and `issueType`, and these three only. Ask for
  them. A repository with no Jira identity is a normal repository: leave the section out, and
  issue creation refuses by naming the key while the build loop keeps working.
  **There is no `doneStatus`.** Done-ness is per issue type on the team's project, so one
  configured name could never cover a spec epic and its children, and nothing in this flow
  writes or reads a status. Anything that ever needs to ask uses `statusCategory`, which needs
  no configured name.
- **`artifacts`** is a single `remote`. The layout inside the artifact repository is fixed, not
  configured. When the team has no artifact repository yet, leave the section out; the machine
  tier then skips its clone and says why, rather than guessing a remote that fails much later.
- **`pullRequests`** carries `remote`, `targetBranch`, `branchPattern` and `draft`.
  **`branchPattern` is a branch name with `<key>` standing for the ticket key and `<slug>` for
  the free text after it**, and those two placeholders are the only ones. Everything else is
  literal, so `chore/<key>-<slug>` recognises `chore/LEG-2115-service-catalog`. **Propose it
  from the branches the repository already has**, which `git branch -a` lists, rather than
  inventing a shape: `develop` answers "is every ticket branch merged" by expanding this
  pattern against each ticket key, so a pattern matching nothing an engineer actually creates
  makes that test answer about an empty set and report a build finished.
  **`targetBranch` is the remote's default branch, read and never assumed:**
  `git symbolic-ref refs/remotes/origin/HEAD`. Plenty of repositories say `master`, and the
  branch the engineer happens to be standing on when setup runs answers neither question. A
  wrong value here opens every merge request against a branch nobody merges.
  `branchPattern` must encode the ticket key, because the integration branch's `git log` is the
  only record of which tickets are done. **There is no `granularity`.** One merge request per
  spec is the only mode anything implements, and a key no code reads is machinery without a
  requirement. `remote` sits at `origin` for every repository seen so far; say so rather than
  presenting it as a decision.
- **`build.concurrency`** is 3 unless the human says otherwise, and it is written either way.
  The binding constraint is the team's shared rate limits and the orchestrator's merge
  throughput, not the host's own ceiling.
- **`gauntlets`** is an object keyed by run point, with the three keys `ticket`, `integration`
  and `issue` always present. Looking a run point up in an object *is* the not-run test, so an
  empty array is never ambiguous between "declared none" and "declared nothing". An entry is a
  `name`, a `command` and an optional `description`. `command` is a string executed through the
  shell, so `npm run lint && npm run typecheck` is one entry written as one string. The entry
  names itself in the failure report, so give it a name a reader can act on.

### The one command that does not resolve here

The `issue` run point is declared in **this** file, in the code repository, like the other two.
Its command runs somewhere else: the contract puts the working directory at the artifact
repository clone for `issue`, so a relative path in that command resolves there and not in this
repository. The check is artifact-repository payload, installed by the team tier beside the
converter it calls.

```json
"issue": [
  {
    "name": "issue-standards",
    "command": "docs/agents/gauntlets/issue-standards.sh",
    "description": "Converts the draft once and asserts the standard's shape against the resulting ADF. The path resolves in the artifact repository clone, which is this run point's working directory."
  }
]
```

That path and the team tier's install destination are one fact written in two files. Take it
from the team tier's own procedure rather than assuming it, and if the two ever disagree the
declaration is wrong and the install is right.

**Declare it only where the `artifacts` section is written.** A declared check with nothing to
run is vacuous, so declaring this one against a clone nobody has made yet turns the `issue` run
point red for the whole team until somebody makes it. Leave the
array empty, say that the artifact repository is what fills it, and the re-run that follows its
creation writes the entry.

## The committed host settings

Claude Code reads some keys itself, and a plugin's own settings file drops them, so they have to
land in the repository's `.claude/settings.json`.

**Merge, never replace.** Read what is there, merge, show the diff, let the user reject it. A
repository almost certainly already has keys in that file, which makes "it differs" the normal
case rather than the error case, and a whole-file copy that refuses on difference would refuse
every time.

Two additions, and only these two:

- **`permissions.deny` gains `Bash(git stash:*)`**, appended to whatever is already denied.
  `refs/stash` is shared across worktrees, the host's isolation checks do not cover it, and
  nothing in this flow uses stash.
- **`worktree.symlinkDirectories` is written empty.** Propose what you find, a dependency
  directory the repository's own ignore rules already name, and write the values only if the
  human asks for them. Naming `node_modules` or `.venv` outright would hard-code a stack into a
  plugin that is not allowed to know one.

**`git push` stays allowed, and that is deliberate.** A Bash deny rule is not path-scoped and
applies to every session in the repository, so denying push here would also break the artifact
repository's claim push, which has to happen the moment a claim is made. "Never push the ticket
branch" therefore survives only as an instruction in the worker's prompt. State this to the
user as a known gap rather than leaving them to infer the rule is missing by oversight.

`permissions.additionalDirectories` is **not** written here. It names an absolute path, which
does not reproduce across six home directories, so it belongs to the machine tier's
`.claude/settings.local.json`. Leave that file alone from here.

## The tracker document

`to-tickets` loads `docs/agents/issue-tracker.md` as its first act, whether a human typed it on
its own or the flow reached it. That is why the team's issue standard is reached **through**
that document and needs no new mechanism: the document points at the standard exactly as it
already points at the triage-label vocabulary.

Seed `<plugin root>/templates/jira-issue-tracker.md` into `docs/agents/issue-tracker.md`.
The plugin-root mechanic and its failure symptom are in this skill's own body; the same rule
applies here.

**Already present** when the file there is *a* Jira tracker document that reaches the team
standard, which it is when it names the `tracker` keys this run wrote into
`docs/agents/workflow.json` and points at `docs/agents/jira-issue-standard.md`. It does not have
to be this plugin's template, and a document that satisfies both is not reseeded over. Seeded
once and never touched again: a team's edits to their own copy are theirs, and so is a document
they wrote instead of taking the template.

Where the human asks for the template anyway over a document that already passes, reseed it and
**carry their content across rather than appending the template's**: what they are keeping is
the half the template does not have.

The precondition refusal has already established that *some* tracker document exists, because
the upstream setup skill wrote one for whichever tracker the human picked when they ran it.
Replacing it is a whole-file diff shown before anything is written, and the human may reject it.
A rejection costs publishing, not the build loop, so say which half stops working and move on.

The document **carries no wayfinding section.** Maps and wayfinding tickets stay in the artifact
repository and off the board; wayfinding on Jira is out of scope by decision, not by omission.

## The repository's own agent instructions

The code repository has an agent-instructions file of its own, `CLAUDE.md` or `AGENTS.md` at its
root, written by the upstream setup skill and indexing the documents under `docs/agents/`. This
tier **does not seed it and does not restructure it.** One thing only: where its tracker section
spells out the site, the project key or the issue type, replace those values with a pointer to
`tracker.*` in `docs/agents/workflow.json`, which is now the one home for all three.

That edit is not tidying. The tracker document this tier just seeded stops carrying those
values, so an index still reciting them leaves two answers in one repository, and the stale one
is the one a reader meets first. Show the diff like any other write and let the human reject it.

**Nothing else in that file is this tier's business.** It belongs to the repository, and most of
what it indexes has nothing to do with devflow.

## The triage-label file

`docs/agents/triage-labels.md` is the upstream setup skill's output. **Leave it exactly as it
is.** Do not edit it, do not delete it and do not seed anything into it. Deleting another
skill's output is an edit to upstream behaviour taking a second route, and the file is inert
while nothing in this flow reads it.

**Seed no triage mapping anywhere.** The five roles are a readiness axis and a Jira project's
statuses are a progress axis, and an issue this flow publishes is past triage by construction.
With no mapping configured the `triage` skill hits its own missing-config path and stops, which
is exactly how it is written. That is the design, not a gap, and it is the one cheaply
reversible decision here: were the team ever to triage inbound work, the roles become Jira
**labels** and never statuses.

## Validation

Over what was just written, before reporting the tier done:

```
jq -e . docs/agents/workflow.json
```

A parse failure is the whole structural check for well-formedness. Then compare the top-level
keys against the key set above and **flag any section that is not in it**, so a key cannot
appear silently. Flag, do not delete: an unknown section is more likely a newer plugin's key
than a mistake, and deleting a teammate's key is worse than naming it.

There is no schema and no validator. Completeness is not checked here at all; it is checked at
the point of use, where each skill declares the keys its own operation needs and refuses by
naming the one that is missing. One mechanism doing both jobs cannot disagree with itself.

## Committing

Commit what this tier wrote. The configuration, the copied checks, the merged
`.claude/settings.json` and the tracker document are all committed, because the whole point of
the tier is that a teammate's run reproduces this one. Do not commit anything the machine tier
writes.
