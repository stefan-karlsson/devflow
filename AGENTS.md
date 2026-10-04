# Repository Instructions

This repository distributes one plugin, `devflow`, for Claude Code. `CLAUDE.md` includes this
file and holds no rules of its own.

## Invariants

- The plugin ships no copy of an upstream skill, and declares the upstream floor it supports in
  one place it owns: `floor_commit` in `plugins/devflow/scripts/scan-skill-environment.sh`. An
  adapter whose discipline comes from code it does not ship has to say so, or the first person
  to fix a missing skill will fix it by copying one in.
- One copy of every file, nothing rewritten at install time. Every skill sits exactly one level
  under `skills/`, where the default scan reaches it.
- Our skills load upstream's installed skills for judgement and never restate them.
- One README, at the repository root. The plugin has none of its own.
- One adapter per verified host, shipped under the plugin at `plugins/devflow/adapters/`, and
  that directory and the README's host table are the same set, checked in both directions. A
  host named in one place and not the other is either a row promising answers nobody can find
  or answers no reader is told to look for, and both read from outside as support for a host
  nobody verifies.

## Rules

- The two manifests, `.claude-plugin/marketplace.json` and
  `plugins/devflow/.claude-plugin/plugin.json`, agree on name, version, description and author,
  and the router's version stamp agrees with them.
- Marketplace paths stay relative, and the plugin owns the source of truth for every file it
  ships, including the ones it copies out.
- Every repo-specific value lives in `workflow.json`.
- Scripts assume bash and `jq` and add nothing else; Node is the only runtime they may add.

## Verification

Validate manifests, frontmatter and resource paths. Run this repository's `ticket` gauntlet
after workflow changes. Report checks that were not run.

## Agent skills

Every file holding this repository's agent configuration is indexed below, added in the commit
that creates it. An unindexed file is the failure this rule exists to catch.

- **Issue tracker.** Issues and specs live as markdown files under `.scratch/`, untracked and
  local to each machine.
  [issue-tracker.md](docs/agents/issue-tracker.md)
- **Triage labels.** The five canonical roles, used verbatim as `Status:` values.
  [triage-labels.md](docs/agents/triage-labels.md)
- **Domain docs.** This repository is single-context, so one glossary and one ADR directory,
  both created lazily. [domain.md](docs/agents/domain.md)
- **Gauntlets.** The checks, their run points, and what nothing covers. Declared in
  [workflow.json](docs/agents/workflow.json), sourced in
  [gauntlets/](docs/agents/gauntlets/). [gauntlets.md](docs/agents/gauntlets.md)
