# devflow

A configuration contract and workflow router that runs one development workflow on Claude
Code. It is not a development methodology: it ships a router that tells you which phase an
effort is in, a setup skill, and its own procedures, six skills in all. Everything
repository-specific lives in that repository's own `docs/agents/workflow.json`, so the plugin
hard-codes no model, no target repository and no build command.

## Install

Install the upstream skills first. devflow loads them for judgement and will not run without
them:

```
npx skills@latest add mattpocock/skills -a claude-code
```

Then the plugin itself:

```
claude plugin marketplace add stefan-karlsson/devflow
claude plugin install devflow@devflow
```

The marketplace and the plugin share the name, which is why `devflow@devflow` reads twice.

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
