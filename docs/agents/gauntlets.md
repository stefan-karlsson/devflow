# Gauntlets

What this repository's checks assert, what they deliberately do not, and how a new one gets
added. If you are looking for the install command, this is the wrong file.

A **gauntlet** is the set of checks bound to one run point. A **check** is a shell command
judged solely by its exit code. The three run points are `ticket`, `integration` and `issue`,
and the set is closed.

## There is one list, and it is the configuration

Every check this repository runs is declared in [`workflow.json`](workflow.json) under
`gauntlets`. Nothing else enumerates them. The CI workflow reads that file and runs whatever
it finds, so adding, renaming or removing a check never touches CI, and this file does not
repeat the list either. A second copy of the list is a second definition, and the two drift.

The check sources live in [`gauntlets/`](gauntlets/). Two kinds share that directory and a
header tells them apart. A plugin-supplied check says so at the top: the plugin owns its
source of truth and the payload installer copies it in, so editing the copy makes the next
install refuse rather than overwrite. A check with no such header is this repository's own,
asserting on this plugin's packaging, which no consumer repository has. The installer reports
orphans rather than deleting them, which is what makes one directory safe for both.

This repository is deliberately half-configured: `ticket` is populated, `integration` and
`issue` are declared and empty. A run point with nothing declared is reported as *not run*,
never as a pass, and that is the first live test of the rule.

## How a finding becomes a check

Retrospectives are where missing coverage is noticed. The seam is three steps and each one is
owned by something different:

1. **`retro` proposes.** It names what went wrong and what would have caught it. It does not
   write configuration, and it never learns the word gauntlet. `retro` is upstream's skill,
   running from the engineer's own install, and this plugin neither ships nor modifies it: a
   retro that started editing `workflow.json` would be an upstream skill with opinions about
   our config, which is why the proposing step writes nothing.
2. **`setup-devflow` writes.** Discovery and approval happen at setup time, never at run time.
   A human approves the command before it is written.
3. **The configuration records it.** From then on the entry is data, and the runner is a
   runner.

So a check is never invented mid-run by an agent that wanted one. If this flow feels slow for
a check you want today, write the script, run it by hand, and let setup add it on the next
pass.

Write the check before you believe it. A check that has never failed is not known to work: it
may be asserting nothing, or asserting it against the wrong path. Every check here was proved
to fail against a deliberately broken fixture before it was declared to pass.

### The `ticket` set carries one entry beyond the specification's table

The specification's "Entries at that seam" is a closed table of ten rows. `workflow.json`
declares eleven. The eleventh is `issue-standards-tests`, and it is there by the design rather
than around it: the rule is that a ticket which creates a testable subject declares the entry
for that subject, and the issue standards check was built after the table was written down. The
table was reopened by that rule working, not by a check arriving unannounced.

This is recorded so the next reader meets a decision instead of a discrepancy. The count in the
specification is the count at the time it was written, and `workflow.json` is the list. A
twelfth entry arrives the same way, through a ticket that creates something testable, or it
does not arrive.

## The conformance claim

The claim is that every skill in this repository satisfies the **Must rules of the Agent
Skills specification text at commit `69ef37e`**, asserted by `skill-conformance` over every
skill directory in the subject.

In the same breath: that claim is measured against the specification text and **not** against
the standard's reference validator, and the two disagree. The validator hard-rejects unknown
frontmatter keys, which the specification text does not, and two of this plugin's six skills
carry one: `develop` and `setup-devflow`, each declaring `disable-model-invocation`. Measured
by the validator's definition, those two fail. Measured by the specification's, they do not.
We think the specification text is the better claim and we are not going to pretend the gap is
not there. No badge, and not "fully compliant". Two skills is also a thin base for an
argument, and that is worth saying out loud rather than leaving for the next reader to notice:
if the count grows, the argument gets made again instead of inherited.

The engineer's installed copy of the upstream skills is never audited for conformance. A
frontmatter defect we do not own and cannot fix is not a thing to refuse a run over, and such a
refusal helps nobody. What the installed copy gets instead is the dependency probe, which
asserts what the flow actually needs: the required skills present, at or above the floor,
structurally intact and not doubled.

### Why the reference validator is absent

It is not wired in and is not going to be. Running it would cost every engineer a Python
toolchain for a tool that checks seven things, and it would need a two-entry expected-failure
allowlist plus something watching for when those entries stop failing. It also rejects
frontmatter the real loaders accept, so a green run would be measuring a stricter thing than
the hosts enforce.

It stays useful as an **occasional manual cross-check**: run it by hand when the specification
text moves, or when a skill stops being discovered for a reason nothing here explains, and read
its unknown-key complaints as noise. Nothing automated depends on it.

### The frontmatter check is a structural subset, and that is a limit

`skill-conformance` asserts that frontmatter is well formed by checking structure, not by
parsing YAML. No YAML parser is reachable without a dependency, so what it actually asserts is
a delimited block whose lines are `key: value`, a block scalar with its indented body, a
comment or a blank line.

State that as a limit, because it is one. It catches the three defect classes that make a skill
vanish from discovery and it misses exotic YAML. A green `skill-conformance` does **not** mean
a parser read the file and agreed. Do not read it as one, and do not let a future reader read
it as one either.

`skill-hygiene` is a separate entry on purpose. It asserts what the specification only
recommends: that every relative reference in a skill resolves and that the skill file stays
under 500 lines. One check called conformance that asserted both would overstate the claim.

## The checks are CI-agnostic

Nothing in a check knows what runs it. Each one is bash and `jq`, takes its subject from
`GAUNTLET_SUBJECT`, and is judged by its exit code. The gauntlet already runs at all three run
points in session, which is the gate that matters, and this repository happens to also run the
`ticket` set in GitHub Actions.

A team on different infrastructure wires the same entries up themselves, and nothing needs
changing for them to do it: read `workflow.json`, run each `command` with `GAUNTLET_SUBJECT`
set to the checkout, fail on a non-zero exit. A team that wires up nothing loses no in-session
coverage at all.

## What nothing here tests

Read this before you read a green gauntlet as a working plugin. Every check in this repository
is structural: manifests agreeing, paths resolving, a converter producing a known document, an
installer refusing a differing target. None of the following is covered, and none of it is
covered somewhere else either.

- **No check exercises a real orchestrated build.** Nothing starts a worker, merges a ticket
  branch, or watches the router pick a phase.
- **No check proves a host registers anything.** The checks assert that the manifests and the
  tree agree about what *should* be discoverable. Whether Claude Code actually loads a skill is
  unobserved here.
- **Nothing watches upstream.** The flow runs on the engineer's own install of the upstream
  skills, and no check asks whether upstream has moved. `scan-skill-environment.sh` asks one
  narrower question: whether the installation in front of it satisfies the floor, exiting
  non-zero when a required skill is absent, below the floor, structurally wrong or doubled. The
  probe's own behaviour is covered, by `dependency-probe-tests`, which asserts its verdict
  against fixture skill roots for the satisfied case, a missing required skill, a version below
  the floor, the invocation key moved and a doubled install. Upstream itself is what is
  uncovered: it can break the flow between one engineer's install and the next, and the probe
  catches that at the router's door rather than preventing it.
- **A minor version bump only warns, which is weaker than the `0.x` policy implies.** The
  router refuses on a major bump and warns on a minor one. On the `0.x` line the major is
  always 0, so a bump to `0.2.0` that changes the configuration key set produces a warning and
  the session carries on into a configuration it may not understand. The rule was implemented
  as the specification states it rather than special-cased, which was the right call, and this
  is the cost of that call.

The thing that does cover the gap is the **acceptance run**: the first real multi-ticket run on
a real repository, watched by a human. It is not a check and it is never automated, because what
it asserts is judgement a human makes while watching. It is named here, in the file whose reader
is looking for coverage, rather than in the README, whose reader is looking for the install.

There is no test matrix, and the absence is deliberate. The one this replaced put a fact a human
verifies once and an assertion that must hold forever in neighbouring rows, so the recurring half
inherited the manual half's cadence and became prose nobody ran. It passed while the plugin was
broken four ways. Do not write a successor to it: a matrix that manufactures confidence is worse
than no matrix.

### The measurement that is run by hand

`claude plugin details` reports a component inventory and the always-on token cost of the
installed plugin. That is the best measurement available of what the alignment and
context-cost concerns can otherwise only reason about, so it is run by hand before a release:
a human moment rather than a gate.

It is not a gauntlet entry, for two reasons. It reads an **installed plugin** rather than a
repository tree, which is a different subject from every other `ticket` entry. And the `ticket`
gauntlet also runs in CI, where nothing is installed and the CLI is absent.

## Deliberately excluded

Four things are not checked, and each was decided on its merits rather than dropped:

- **Any check that watches upstream.** The probe judges the installation in front of it. Asking
  upstream what it has become is a different job and this repository does not take it on.
- **A conformance audit of the engineer's installed copy.** It is read for what the flow needs,
  not judged on frontmatter nobody here can fix.
- **Any check on what the plugin costs a context window.** That is a property of the reader's
  machine and the set installed on it, not of this tree, so no check over a checkout can assert
  it. The manual measurement above is where that number comes from.
- **The Agent Skills reference validator**, for the reasons above.
