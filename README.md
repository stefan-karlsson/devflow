# devflow

A configuration contract and workflow router that runs one development workflow on any host
that meets the contract below. It is not a development methodology: it ships a router that
tells you which phase an effort is in, a setup skill, and its own procedures, six skills in
all. Everything repository-specific lives in that repository's own
`docs/agents/workflow.json`, so the plugin hard-codes no model, no target repository and no
build command.

No skill devflow ships carries a host's spelling, and no command it prints assumes one. What
it names instead is six capabilities, and this README says what breaks on a host without each
one. The one place a host is named in shipped code is the dependency probe, which defaults to
the skill directories one host reads and takes `DEVFLOW_SKILL_ROOTS` to be pointed anywhere
else.

## What devflow requires of a host

Each capability below is a requirement devflow places on a host, not a feature of any product.
That is deliberate: a contract written about devflow stays true with nobody maintaining it,
and a list of products does not. Each one is here only because its absence has a symptom
somebody can recognise, which is also how you judge your own host from this page without
installing anything.

### The four required capabilities

devflow does not run without any one of these. There is no degraded mode to fall back to, so a
host missing one of the four gets no adapter either.

| # | What devflow requires of the host | Symptom of its absence |
| --- | --- | --- |
| C1 | Resolves a skill by its frontmatter `name` while it is installed outside the plugin, both when a human types the name and when a skill loads another mid-task | A phase loads a skill, the host finds nothing, the model carries on without it, and the work looks finished having skipped a discipline |
| C2 | Honours a skill's model-invisibility: hidden from the model, still typeable by the human | A phase skill the router should only name is invoked by the model, so an expensive phase starts without the human who was supposed to start it |
| C3 | The plugin's shipped files are reachable from the shell as a filesystem path | The plugin's location cannot be obtained or named, so no shipped script can run |
| C4 | Runs a shell command in the repository and reports its exit code | No gauntlet can run, so every run point reports not run |

C3 asks that the files can be reached and named from a shell, and asks nothing about how the
host spells that path inside a skill. The skill bodies carry no host spellings and nothing
rewrites them on the way in, so the path is acquired once at setup and recorded rather than
written into the text.

### The two capabilities that gate one phase each

These two are different in kind. Each one's absence costs exactly one phase and leaves the
rest of the flow working, so a host without them is still worth running. They are the two an
adapter declares, because unlike the four above they have states to carry.

| # | What devflow requires of the host | The one phase it gates | Symptom of its absence |
| --- | --- | --- | --- |
| C5 | Spawns a subagent carrying none of the caller's context | The issue review inside publish | The review does not run, or runs carrying the context of whoever wrote the draft |
| C6 | Spawns a subagent isolated in its own git worktree | The orchestrated build | Workers share a tree |

## Hosts

| Host | Adapter written against | Orchestrated build |
| --- | --- | --- |
| `claude-code` | Claude Code 2.1.289 | not exercised |

The middle column records the release that host's adapter was written against, which is what
[claude-code.md](plugins/devflow/adapters/claude-code.md) says of itself. The release is in the
table because an answer written against one release is a claim about nothing later, and an
answer that has gone stale should be visible to you rather than silently false.

**It is not a record of testing, and the manual host pass is pending.** That procedure is
written down, in [gauntlets.md](docs/agents/gauntlets.md), and nobody has yet run it against
any release, this row included. Read the column as whose answers exist and how old they are,
not as evidence that anything was exercised.

The last column has exactly two states, exercised and not exercised, and it records evidence
rather than capability. The adapter declares C6 `present` for `claude-code`, and the isolation
check verifies the worktree on every spawn, but nobody has yet run an orchestrated build end
to end against 2.1.289 and written down what they saw. So the cell reads not exercised. It
changes when somebody does that, not when the mechanism is believed to work: a declaration is
not a run.

This is the only tier there is. A host absent from the table is not a lesser tier, it is
unnamed: devflow may well run on it, and nobody has checked. Each row's first column is the
slug its adapter file is named by under
[plugins/devflow/adapters/](plugins/devflow/adapters/), and the table and that directory are
asserted to be the same set, so a host leaves in one act rather than two.

### Getting the files at all

Installing devflow is its own contract, and it is deliberately the weakest one here: the files
have to end up on disk somewhere the host reaches, and nothing more. That is the whole of it,
and it is why no capability covers it and no slot asks about it.

This repository is the delivery. The six skills sit one level under
[plugins/devflow/skills/](plugins/devflow/skills/), in the layout the Agent Skills
specification describes, with one copy of every file and nothing rewritten at install time. So
cloning this repository anywhere and pointing your host's skill resolution at that directory is
a complete install. There is no build step, nothing to generate and no packaging to unwrap.

What each host section below gives is that host's shortcut to the same outcome. A shortcut is
not a second requirement, and a host without one is not a host devflow cannot reach.

### Claude Code

Install the upstream skills first. devflow loads them for judgement and will not run without
them:

```
npx skills@latest add mattpocock/skills -a claude-code
```

The requirement is the same on every host; this command is not, because its last flag names
the host to upstream's installer.

Then the plugin itself:

```
claude plugin marketplace add stefan-karlsson/devflow
claude plugin install devflow@devflow
```

The marketplace and the plugin share the name, which is why `devflow@devflow` reads twice.

This host's remaining answers, one per slot, are in
[claude-code.md](plugins/devflow/adapters/claude-code.md).

## Bringing a host

Get the files the generic way above, since the shortcut for your host is the thing that does
not exist yet: clone this repository and point your host's skill resolution at
[plugins/devflow/skills/](plugins/devflow/skills/). Nothing about that route is provisional,
and it is the same six files a verified host runs.

Then write `$HOME/.devflow/adapters/<slug>.md` and run devflow. That file is read for any host,
with nothing promised about yours first, so you can get your host working before anyone has
agreed to anything. What you answer is the slot enumeration in
[slots.md](plugins/devflow/skills/setup-devflow/references/slots.md): one heading per slot,
prose rather than data, and every slot answered, including answering that your host has no
equivalent. Silence is not an answer, because it conflates a thing the host lacks with a thing
nobody got round to recording. [claude-code.md](plugins/devflow/adapters/claude-code.md) is
the worked example, and it is the same file a verified host ships.

Getting into the table above is a different question, and it is a staffing one: will I
maintain this, rather than will you support my host. A host joins by acquiring someone who
keeps its adapter current and runs the manual pass against each release, and it leaves the
release that person stops. The one row there is has the first half and not yet the second.
Nothing in this repository tests a host automatically, on purpose, so the list grows at the
speed of the people behind it and not faster.

## Set up a repository

Run `/setup-devflow` inside every repository the team builds in, and again after a plugin
upgrade. It writes team, repository and machine-local state, skipping whatever is already
there. Nothing else needs configuring by hand.

Both entry points check the upstream install before doing anything.
`plugins/devflow/scripts/scan-skill-environment.sh` is the probe, and it exits non-zero when
the upstream skills are absent, below the supported floor, structurally wrong or installed
twice. `/setup-devflow` refuses on that result, and `/develop` refuses on it again at its own
start.

## Use it

`/develop` is the entry point and the one command worth remembering. It reads the
configuration, works out which phase the effort is in, and names the single thing to type
next. It never starts a phase itself.

A build can fan out across git worktrees, one worker per ticket, through the orchestrated
build. It is a capability of the plugin, not a setting, so there is no switch to look for.
C6 is what gates it, and where C6 is not met the rest of the flow is unaffected. No row in
the host table above records an orchestrated build as exercised, so of everything here it is
the part with the least evidence behind it.

To ask which upstream skill fits a situation, invoke `ask-matt` yourself. It is upstream's own
router over its skill set, and nothing in devflow mentions it, so a model will not reach for
it on your behalf.

## Credit

The workflow this plugin automates is Matt Pocock's design, from
[mattpocock/skills](https://github.com/mattpocock/skills). The configuration contract around
it is not. The attribution is courtesy rather than obligation, since devflow ships no copy of
his work and redistributes nothing, but a thin adapter around someone else's discipline should
say whose discipline it is.

The supported floor sits beside that credit: upstream `main` at or after commit
[`d81f3a1`](https://github.com/mattpocock/skills/tree/d81f3a1). The floor is declared once, as
`floor_commit` in `plugins/devflow/scripts/scan-skill-environment.sh`, and asserted by content
markers rather than a version number, because upstream's releases carry no usable version
string.

Nothing watches upstream. It can change between one engineer's install and the next and break
the flow, and the probe catches that at the router's door rather than preventing it.

## Conformance

The six skills devflow ships satisfy the Must rules of the Agent Skills specification text at
commit `69ef37e`, measured against that text rather than against the standard's reference
validator. The claim covers those six and nothing else: the upstream copy on your machine is
never audited.

Two of the six diverge from that validator. `develop` and `setup-devflow` carry
`disable-model-invocation`, a frontmatter key the specification text does not define. The
validator hard-rejects an unknown key; the specification text does not. That divergence and
what the checks do not cover are written up in [gauntlets.md](docs/agents/gauntlets.md).
