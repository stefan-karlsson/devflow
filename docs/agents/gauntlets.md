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

**Every check is standalone, and the repeated preamble is the price of that.** All ten resolve
their subject and define `report()` the same way, in their own text. That is not factored out,
because two of the ten are copied into a consumer repository one file at a time: an installer
that copies files rather than dependency trees would deliver a check whose shared source is not
there. Writing eight one way and two another would cost more than the lines it saves. What does
get factored out is anything a single check says twice.

This repository is deliberately half-configured: `ticket` is populated, `integration` and
`issue` are declared and empty. A run point with nothing declared is vacuous and reported as
*not run*, which is the first live test of the rule.

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

### The `ticket` set carries seven entries beyond the specification's table

The specification's "Entries at that seam" is a closed table of ten rows. `workflow.json`
declares seventeen. The seven beyond it are `issue-standards-tests`,
`adapter-slot-completeness`, `adapter-readme-agreement`, `adapter-checks-tests`,
`worktree-isolation-tests`, `on-ramp-coverage` and `on-ramp-coverage-tests`, and each is
there by the design rather than around it: the rule is that a ticket which creates a testable
subject declares the entry for that subject, and every one of those subjects was built after
the table was written down. The table was reopened by that rule working, not by checks arriving
unannounced.

This is recorded so the next reader meets a decision instead of a discrepancy. The count in the
specification is the count at the time it was written, and `workflow.json` is the list. An
eighteenth entry arrives the same way, through a ticket that creates something testable, or it
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

## What the two adapter checks assert

Host knowledge is written in two kinds of place, and two entries keep them one set.
`adapter-slot-completeness` compares each adapter's slot headings with the headings `slots.md`
defines, **byte for byte**, and reports in both directions: a slot an adapter does not answer,
and a heading `slots.md` does not define. `adapter-readme-agreement` compares the slugs under
`adapters/` with the slugs in the README's host table, again in both directions, so a host
joins or leaves in one act rather than two. Both walk `find -type f` over `adapters/` and take
a slug from the file's path with a trailing `.md` removed, so the two agree on what "the
adapters" are, and a file dropped in there that is not an adapter answers to a slug the table
will not name and is reported rather than skipped.

Neither check carries the list it asserts against. The completeness check derives the expected
set from `slots.md` as it runs, which is why `adapter-checks-tests` builds fixtures naming
slots **Alpha, Beta and Gamma** rather than the real seven: a check that passes against those
fixtures cannot be carrying the seven around inside it. The agreement check finds the README
table by its three-column delimiter row rather than by slicing from `## Hosts` to the next
heading, because that section continues past the table into prose and an install subsection.
Which part of that shape is load-bearing, and what a mutation pass found when the other part
was relaxed, is written in the check's own header, beside the parse it is about.

**Their two failing exit codes carry a distinction the suite relies on, and "it failed" loses
it.** Exit `1` means the check asserted and found something. Exit `2` means it could not assert
at all: the subject is not a directory, `slots.md` is missing or defines no slots, no file sits
under `adapters/`, or the README is missing or carries no `## Hosts` heading. A check that
would otherwise pass every adapter against an empty expectation says so instead, and because
the two codes differ, those empty-set guards are themselves testable.

Neither check reads an adapter's **answers**. It reads its headings. An adapter answering every
slot with the wrong prose passes both.

## The isolation script is covered and the thing it guards is not

`worktree-isolation-tests` drives `worktree-isolation.sh` against real repositories with real
worktrees in a temporary directory, asserting the exit code and the one path the exit-0 case
prints, never the wording: thirty-one cases, among them the main checkout, a branch no worktree
holds, a separate clone of the same repository, a stale SHA, a detached HEAD and a branch whose
name is a prefix of another's. The suite was proved by mutation before it was declared to pass:
deliberately broken copies of the script, one defect each, every one of them caught. No count
is given, because the mutants were transient and nothing in this repository holds them, so a
figure here would be one no reader could check. That is coverage of a script. It is not
coverage of an orchestrated build, which nothing here runs.

The parse has three limits, over a detached HEAD, a worktree path containing a newline, and an
abbreviated SHA. They are stated in `worktree-isolation.sh`'s own header, beside the code that
has them, and are not restated here: a limit written in two files is a limit that gets fixed in
one.

**The check fires only on receiving a report**, so a worker that never reports is never checked
by it. The orchestrator cannot close that from its side, because verifying isolation after the
fact only ever reports damage. What covers that case is the guard in the worker preamble, which
has the worker compare its own toplevel before it writes anything and stop rather than work.
Two guards, one on each side of the spawn, and neither of them is a test.

## The checks are CI-agnostic

Nothing in a check knows what runs it. Each one is bash and `jq`, takes its subject from
`GAUNTLET_SUBJECT`, and is judged by its exit code. The gauntlet already runs at all three run
points in session, which is the gate that matters, and this repository happens to also run the
`ticket` set in GitHub Actions.

A team on different infrastructure wires the same entries up themselves, and nothing needs
changing for them to do it: read `workflow.json`, run each `command` with `GAUNTLET_SUBJECT`
set to the checkout, fail on a non-zero exit. A team that wires up nothing loses no in-session
coverage at all.

## The manual host pass

This is a procedure to follow, not a record of one that was followed. Nothing below is
evidence, and nothing below should be quoted as if it were.

The six capabilities are stated in the README, each with the symptom of its absence, and they
are not restated here: the list is not in the repository twice. What this section carries is
what the README cannot, which is how to exercise each one and what counts as evidence that you
did. Run the pass against one named release of the host, on a machine where the plugin and the
upstream skills are installed the way the README says to install them.

- **C1.** Type a skill's frontmatter `name` as a human and watch that skill's own output
  arrive. Then put the session in a state where one skill loads another mid-task, and watch the
  second one's output arrive too. Both halves, because a host can do the first and not the
  second. Evidence is the loaded skill's output. A host reporting that it registered something
  is not evidence.
- **C2.** Type the name of a model-invisible skill as a human: it runs. Then give the model a
  prompt that plainly invites it, without naming it: it does not run. Evidence is both halves,
  because either alone is also consistent with the host ignoring the key.
- **C3.** Ask the host for the plugin root, then read a file the plugin ships back from a shell
  by that path. Evidence is the file's contents, not a path that looks plausible.
- **C4.** Run one `ticket` entry from the session and read the exit code that comes back, then
  run one made to fail and read that. Evidence is the non-zero reaching the session: a host
  that runs the command and loses the code fails the gauntlet contract while looking fine.
- **C5.** Run `publish-issues` over a draft and let it attempt the review spawn. Evidence is
  what the attempt did, written down either way: the review running and carrying none of the
  drafting context, or the host's own refusal. The skill decides from the attempt rather than
  from a declaration, so the pass does the same.
- **C6.** Spawn one worker with worktree isolation, take the branch and SHA it reports, and run
  `scripts/worktree-isolation.sh` with those two arguments from your own checkout. Evidence is
  exit 0 and a worktree path that is not the main checkout. A path the worker reported is not
  evidence, and neither is a spawn that returned without complaining.

**Record the release the pass was run against in the README's host table**, which is the one
place a reader looks for it. Nothing is recorded there yet. This procedure was written in the
effort that wrote these words and has not been run against any release, so that table's middle
column records the weaker fact it can honestly carry, the release each adapter was written
against. The README is where that scoping is stated and this file does not restate it. The
first person to run this pass is the first person with anything to put in that column.

A host joins that table by acquiring someone who runs this pass against each release, and it
leaves the release that person stops. **No automated host testing is added, deliberately.** The
host set is a staffing decision rather than a coverage one, so growing it is a question about
who will maintain the answer, not about what a check could be made to assert.

## What nothing here tests

Read this before you read a green gauntlet as a working plugin. Every check in this repository
is structural: manifests agreeing, paths resolving, a converter producing a known document, an
installer refusing a differing target. None of the following is covered, and none of it is
covered somewhere else either.

- **No check exercises a real orchestrated build, a real worker spawn or a real host.** Nothing
  starts a worker, merges a ticket branch, or watches the router pick a phase.
- **The isolation script is covered and a real orchestrated build still is not.**
  `worktree-isolation-tests` asserts the script's verdict against real worktrees, as the
  section above sets out. The script is therefore known to answer correctly about a situation
  nothing in this tree creates.
- **No check proves a host registers anything.** The checks assert that the manifests and the
  tree agree about what *should* be discoverable. Whether Claude Code actually loads a skill is
  unobserved here.
- **No check proves the machine record is written correctly**, because setup is prose. A model
  follows it at run time and nothing executes it, so the record's shape is asserted by the
  readers that depend on it and by nothing before them.
- **No check proves an adapter's answers are right**, only that it answers. A wrong slot 1 is
  caught by setup's assertion at acquisition, by a human, once.
- **C1, C2 and C4 are asserted by the dependency probe and the manual host pass, and never by
  a check in this tree.** A green `ticket` run says nothing about any of the three.
- **The C5 attempt path is uncovered.** `publish-issues` is prose a model follows at run time,
  so neither the attempt nor the short-circuit on an `absent` declaration is exercised here.
- **Nothing tests the best-effort stop of an in-flight worker**, which follows from its not
  being a seventh capability: the symptom of its absence is an untidier abort rather than a
  named failure, so there is no answer to assert and no verdict to check.
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
  always 0, so a bump to `0.3.0` that changes the configuration key set produces a warning and
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

Five things are not checked, and each was decided on its merits rather than dropped:

- **Any check that watches upstream.** The probe judges the installation in front of it. Asking
  upstream what it has become is a different job and this repository does not take it on.
- **A conformance audit of the engineer's installed copy.** It is read for what the flow needs,
  not judged on frontmatter nobody here can fix.
- **Any check on what the plugin costs a context window.** That is a property of the reader's
  machine and the set installed on it, not of this tree, so no check over a checkout can assert
  it. The manual measurement above is where that number comes from.
- **Automated host testing of any kind.** Ruled out on budget. A host is verified by a human
  running the manual pass above against a named release, and by nothing else, which is why the
  verified set is one and why growing it is a staffing question.
- **The Agent Skills reference validator**, for the reasons above.
