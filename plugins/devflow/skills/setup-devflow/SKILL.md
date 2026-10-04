---
name: setup-devflow
description: Configure a repository and this machine for the devflow workflow. Run it in any repository the team builds in, after the upstream setup skill has run there, and run it again after a plugin upgrade. It writes team, repository and machine-local state, skipping whatever is already present.
disable-model-invocation: true
---

This is the one command an engineer runs. It refuses on three conditions that would otherwise
produce a half-working flow discovered much later, and then writes three tiers of state,
skipping each tier that is already there.

**Re-running is the recovery.** There is no transaction, no progress file and no rollback,
because every step is idempotent and every tier is detected rather than remembered. If a run
stops halfway, run it again. If a plugin upgrade changes what setup writes, run it again.

## Finding this plugin's own files

Commands below name scripts as `<plugin root>/scripts/<name>`. The plugin root is an absolute
path this machine's record holds, acquired in refusal step 1 and read back from the literal path
`$HOME/.devflow/machine.json`. Build the real path before running a command: nothing expands a
placeholder in this body, and a command run with the placeholder still in it runs against a path
with a hole in it, which the shell reports as a missing file.

No shipped script can read that record for you, because locating a shipped script is the thing
the record is for. Read it yourself with `jq`, at that literal path, at the point of use. Refusal
step 1 is where the root is acquired and where a stale one is caught.

**devflow version: 0.3.0**. This skill's own stamp, shipped in its body because a version
read from a recorded plugin root would compare a stale install against itself and agree.

That stamp is one side of **every** version comparison this skill makes, and the record is never
compared against itself. Two comparisons use it: against the version in the plugin manifest under
a candidate root, which says whether that directory holds this version's install, and against the
stamp inside the machine record, which says whether the record does. The pairing never made is
the recorded stamp against the manifest under the recorded root. The same install wrote both, so
they agree however stale they are, and the comparison passes while the flow runs the previous
version's scripts against this version's skill bodies.

## Refuse first

Onboarding this machine is three commands in this order, and the first two are the human's:

1. Install the upstream skills, so that **they resolve by bare name on this machine**. This
   plugin's phases name those skills and this plugin does not ship them. That requirement is
   the same on every host. The command that satisfies it is not, which is why none is written
   here.
2. Run `setup-matt-pocock-skills` in the repository. It carries a key that stops any skill from
   loading it, so the human runs it the same way this skill is run, not you.
3. Run `/setup-devflow`, which is this skill.

**Step 1's command is printed beside it, and only where this run can read it.** It is slot 6
of the host's adapter, so reading it needs both a plugin root and a host declared on this
machine, and a refusal at step 1 or step 2 may have neither. Take the three cases as they come:

- **This run has a plugin root and `$HOME/.devflow/machine.json` records a `hostSlug`.** Read
  slot 6 from that host's adapter, `<plugin root>/adapters/<slug>.md` where the plugin ships
  one and `$HOME/.devflow/adapters/<slug>.md` where it does not, and print the command it gives
  under step 1.
- **Slot 6 answers that this host has no equivalent.** Say that in one line: devflow has no
  install command for this host, and the requirement stands as step 1 words it. Silence here
  reads as a command somebody forgot to print.
- **No root yet, no recorded host, or no adapter for the one recorded.** Print step 1 as it
  stands and say no host is declared on this machine yet, so there is no command to give. The
  requirement is the part that is true everywhere, which is why it is the part always printed.

Three checks run below, in the order given, all of them before anything is written.

**Run every one you can and refuse once, carrying all of them.** A failed check does not end
the run, it decides it: the remaining checks still run and the refusal reports what all of them
found. Only one dependency constrains this, and it is check 3's on check 1: the probe is reached
at a path built from the plugin root, so a check 1 that could not acquire one leaves check 3
unrun, and you say it did not run rather than dropping it. Check 2 depends on nothing and always
runs.

Stopping at the first failure costs the human a round trip per fault on a machine that has
several, which is the ordinary state of a machine nobody has set up yet. The same reasoning puts
host selection after both upstream checks rather than before them.

Then report what the checks found, print the three steps above so the human can see which one
they are on, and stop. **Do not offer to continue, and do not offer to do something else
instead.** Naming the step that unblocks them is the whole of the help here; picking up adjacent
work because setup refused is this skill deciding what the session does next, which is not its
call. Write not a single file either: a refused run leaves this machine and this repository
exactly as it found them, and running the skill again once the named step is done is the whole
recovery.

### 1. The plugin root cannot be acquired

Every script devflow ships is reached at a path built from the plugin root, so a run without it
cannot perform the checks the other two refusals depend on. That is why this one is first.

**With no record on this machine, ask the human.** One question, asked once:

> Where are the devflow plugin's own files on this machine? Give the absolute path of the
> directory that holds `.claude-plugin/plugin.json`.

Asking is the design here rather than a fallback. The method for finding the plugin root is one
of the things a host adapter answers, and every adapter sits under the plugin root, so reading
one to find the root would need the root already. The human breaks that loop once per machine.
The answer is cached, and nothing asks again while it holds.

**Ask it even when another check has already failed.** A refused run writes nothing, so the
answer is not kept and the question comes back on the next run: that is true, and it is not a
reason to skip it. The answer is what lets check 3 run, and a refusal carrying the probe's
verdict is worth one question that gets asked twice. Skipping it buys a shorter refusal and
costs the human the finding they came back for.

**Where the answer does not come from the human it comes from the record, and from nowhere
else.** Not a host's plugin cache, not a search of the filesystem for a directory named devflow,
not a path that happened to appear earlier in this session. Each of those finds *an* install,
and the two assertions below are not a substitute for being told which one this machine runs:
they pass against any current install, including one this machine will never load. A root
nobody has given you is a question you have not asked yet.

**Assert the answer before anything uses it**, both of these, in order:

1. `<answer>/.claude-plugin/plugin.json` exists. A directory with no plugin manifest under it is
   not a devflow plugin root, whatever else is in it.
2. That manifest's `version` equals this skill's own body stamp above. A path left pointing at
   the previous version's directory still resolves, still holds a manifest and still runs
   scripts. That is the failure this assertion exists for, and it is why the path is checked when
   it is given rather than by whatever command first uses it.

**Either failure refuses, in one message rather than two.** "Nobody has told devflow how to find
the plugin on this host" and "the path given is not a current devflow install" are one problem to
the person standing there, which is that this machine cannot reach the plugin's files, and
splitting them asks them to tell apart two states they would act on identically. Print the path
that was tried, what was found at it, and both versions where the comparison is the half that
failed.

**With a record on this machine, no human.** Read `$HOME/.devflow/machine.json` and compare its
`devflowVersion` against this skill's body stamp.

- **They agree.** The install record is current. Take `pluginRoot` from it and run assertion 1
  against that path, because a directory recorded weeks ago can have been removed since. Ask
  nothing.
- **They differ, or there is no record at all.** The install record is stale or absent, and a
  plugin upgrade is the usual cause. Re-acquire: where `acquisitionMethod` holds a method, follow
  it and assert the result exactly as above; where it holds `ask-the-human`, ask the question
  above. The record is rewritten later in the run, once the host is known.

The method is cached so that an upgrade costs nobody a question. Where the chosen adapter answers
slot 1 by saying the host has no equivalent, there is no method to re-run and the human is asked
again on every upgrade. That is a real answer with a stated price, and the adapter says so rather
than leaving it to be discovered on the second install.

**Setup has no degraded mode, and that is deliberate.** devflow's promise is that a missing
capability disables one phase and leaves the rest working, so a flat refusal here reads as that
promise being broken. It is not. The promise governs the **gating** capabilities, each of which
costs exactly one phase. Reaching the plugin's own files is a **required** capability, C3: with
no plugin root there is no script to run and no check to report, so there is no reduced devflow
left to offer and a run that continued would only move the failure somewhere less legible. Say
this in the refusal. A reader who is not told reconciles the two by assuming the tool is broken.

### 2. The upstream setup has not run here

This skill configures a repository that the upstream skills already understand. They learn the
repository's issue tracker from the tracker document that **`setup-matt-pocock-skills`** writes,
and nothing here writes it.

Refuse when the repository has no `docs/agents/issue-tracker.md`, and name
`setup-matt-pocock-skills` as the thing to run. Print the order above with it, because a machine
with no upstream install fails this check too: that skill cannot have run where it is not
installed, and naming it on its own sends the human after a command they do not yet have.

### 3. The upstream dependency is not satisfied

Run, before anything is written, at a path built from the plugin root step 1 acquired:

```
<plugin root>/scripts/scan-skill-environment.sh <repository root>
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

On either refusal, print two things: the requirement, then **the probe's own output,
verbatim**. Write nothing in their place.

The requirement is the one step 1 of the onboarding list states, in the same words: **the
upstream skills this plugin loads resolve by bare name on this machine.** It holds on every
host, so it is printed on every refusal here.

The command that satisfies it on this host is printed in addition, under the same three cases
the onboarding list sets out: slot 6's command where this run has a plugin root and a recorded
`hostSlug` whose adapter answers with one; the absence said out loud where that adapter answers
that this host has no equivalent; and the requirement alone, with the undeclared host named as
the reason, where there is nothing to read. Host selection happens later in this run, so a
first run on a machine reaches this refusal with no declaration and prints the requirement
alone. That is the honest output, not a gap.

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

## Choose the host

Host selection sits here, after both upstream checks and still before anything is written, for
one reason: nothing before this point reads an adapter, and a human whose host has no adapter
should learn in the same run that their upstream install is wrong too. Moving selection earlier
buys nothing and costs them a second round trip through a refusal they could have had at once.

**List what is on disk, and name no host.** Enumerate the files in two directories:

- `<plugin root>/adapters/`, the adapters this plugin ships.
- `$HOME/.devflow/adapters/`, the adapters written on this machine.

Each filename without its `.md` suffix is that host's **slug**. That is the whole of the
detection. This skill counts files and reads none of their contents until one is chosen, and it
names no host anywhere, because a brand marker here would close the one set the design keeps
open.

**Ask the human to pick**, listing the slugs with where each was found, and offer **none of
these** as the last option.

**Where a slug has both a shipped and a local adapter the shipped one wins, and setup says so**,
naming the local path it ignored. A local copy is usually an earlier edit of a file that has
since shipped, and a stale local file quietly beating a shipped fix is the one outcome worth a
line of output. Report which file was used and which was ignored. Do not delete, move or rename
the ignored one: it is the human's file, and it may be the draft of the next shipped adapter.

**"None of these" is a real answer. It refuses, and the refusal is an on-ramp.** A host nobody
has written an adapter for is a normal state rather than a fault. Say three things:

1. **The file to write:** `$HOME/.devflow/adapters/<slug>.md`, where the slug is whatever they
   want their host called. Nothing registers it, because setup lists the directory.
2. **What it has to answer:** the slots, enumerated in
   [references/slots.md](references/slots.md), one `### Slot N: <name>` heading each, every slot
   answered explicitly, including answering that this host has no equivalent. Silence is not an
   answer there, and that file says why.
3. **What it does not have to do:** nothing is rewritten at install time and no code is involved.
   A working adapter is a prose file, and one that works is worth sending back so the next person
   on that host is not writing it again.

## The machine record

With the host chosen, read its adapter and write one file. This is the last thing before the
tiers, and the only place a host decision is recorded on this machine.

**Read the adapter once, here, and take two things from it.**

- **Slot 1's method**, which goes into the record so the next run re-acquires the root with no
  human in it. The slots and what each one means belong to the core, in
  [references/slots.md](references/slots.md); the adapter holds this host's answers and nothing
  else.

  **Run it now and compare what it returns with the root step 1 acquired.** This is the first
  moment the host's own answer is reachable, and step 1 could not wait for it because the
  adapter sits under the root it is trying to find. Step 1's two assertions do not stand in
  for this comparison: they pass against any current install, including one on this machine
  that this host never loads. Where the two paths differ, print both, say which one the host's
  own method returned, and record that one. Where slot 1 answers that this host has no
  equivalent, there is nothing to compare and the acquired root stands.
- **The capability declarations.** Where the adapter answers `present` or `absent`, take that
  answer and do not ask. Where it leaves one `unknown`, ask the human and record what they say.
  An adapter that answered is never re-asked, because having the host's own answers written down
  once is the whole point of the file. A declaration left `unknown` and never asked about becomes
  a permanent degrade on a host that would have run the phase.

**Write `$HOME/.devflow/machine.json`**, JSON, at that literal path. Every reader finds it with
nothing but `$HOME` and `jq`, and no shipped script can read it for them, because finding a
shipped script is what the record answers.

```json
{
  "pluginRoot": "/absolute/path/to/the/plugin/root",
  "acquisitionMethod": "claude plugin list --json, read installPath for the devflow entry",
  "devflowVersion": "0.3.0",
  "hostSlug": "claude-code",
  "capabilities": {}
}
```

| Field | Holds |
| --- | --- |
| `pluginRoot` | the absolute path step 1 acquired and asserted |
| `acquisitionMethod` | slot 1's method as the adapter states it, or the literal `ask-the-human` where the host has no equivalent |
| `devflowVersion` | this skill's body stamp, which is the invalidation for the two fields above |
| `hostSlug` | the slug chosen above, which is the adapter's filename without its suffix |
| `capabilities` | only the declarations a human answered, keyed by capability, and `{}` when the adapter answered them all |

The values shown are one host's and are not a default. Write what this run acquired.

**Nothing else goes in the file**, and **no slot value is cached** in it: a second copy of an
adapter's answer goes stale with nothing to catch it, because the stamp invalidates on a plugin
upgrade only and a local adapter is edited with no upgrade in sight. The price is that a later
phase reads the adapter as well as the record, which is one more file read per run.

The first three fields are the **install record**, and the stamp governs exactly those three. The
slug and the declarations describe this machine and survive an upgrade, which is why the record
outlives the install record inside it.

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
- **Every tier detects its own state**, which is what keeps re-running the whole recovery. No
  tier reads the record to decide whether it has already run. The record says where the plugin is
  and which host this is, and nothing more.
- **A hardening step this host cannot take skips, warns and continues.** The keys setup writes
  into the host's settings are not capabilities. They are one host's spelling of a rule devflow
  states in prose anyway, attached to a capability the host already has. Where the adapter
  answers that this host has no surface for one, write nothing, warn, and **name the exposure
  rather than the missing key**: `refs/stash` is shared across every worktree of this repository,
  so a stash one worker pushes is a stash another can pop. An engineer can act on that sentence.
  "The deny key could not be written" tells them nothing they can do anything with.

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

- **Check the committed host settings are as specified.** Read the committed settings file slot 2
  names and assert two things: the deny entry slot 3 gives is present, and the worktree key slot
  4 gives is present with the value that leaves each worktree its own directories, unless the
  user asked for other values in it. Report each as a line, naming the file. A merge that
  silently dropped one of these leaves worktrees sharing a stash with no warning anywhere else.
  Where the adapter answered that this host has no equivalent, say the check does not apply here
  and repeat the exposure rather than reporting a pass.
- **Check the executable bit survived.** Assert it on the scripts in the scripts directory under
  the plugin root and on every file the installer copied, in **both** destinations: the code
  repository and the artifact repository clone. A check without the bit
  is unrunnable, and the contract makes an unrunnable check a **failure** rather than a skip, so
  a lost bit turns every gate red at the worst moment. Report the paths that lack it.
- **Tell the user how to make what was written take effect.** Most hosts do not re-read plugin or
  repository configuration mid-session, so the session that ran this skill is the one session in
  which none of what was just written is in effect. An engineer who keeps working in it sees a
  repository that shows no sign of the setup and reads the install as having failed. Slot 7 says
  what this host asks for and whether anything short of a full restart is enough: print that
  answer in the host's own words. Where the adapter answers that this host re-reads its
  configuration as it changes, tell nobody to restart, and say that it is already live.
