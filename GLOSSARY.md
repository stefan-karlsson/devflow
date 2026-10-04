# devflow

This repository distributes one plugin, `devflow`, which runs Matt Pocock's skill flow from
the engineer's own installation of those skills, configured per repo.

## Language

**Configuration surface**:
A place configuration lives, identified by its reader and its scope together. The effort has
four: prose under `docs/agents/`, read by an agent, scoped to the repository; data in
`docs/agents/workflow.json`, read by an agent and by a shell script, scoped to the repository;
host keys in the target repo's `.claude/settings.json`, read by the host itself; and devflow's
own machine state, read by an agent, scoped to this install rather than to any repository. A
value belongs to exactly one surface, chosen by its reader and its scope rather than by its
subject. The reader alone stopped discriminating once two surfaces shared one.
_Avoid_: config file, config location, settings

**Host**:
The program a skill runs inside: it resolves skills by name, runs the commands in their
bodies and spawns their subagents. Described by what it provides rather than by what it is
called, because the set of them is open and a name is not a capability.
_Avoid_: platform, client, runtime, agent harness, Claude Code

**Host capability**:
One thing a host provides, admitted to the contract only because its absence has a named,
observable symptom. Either required, so devflow does not run without it, or gating, so its
absence disables exactly one phase and nothing else.
_Avoid_: feature, requirement, dependency, support

**Capability contract**:
The six host capabilities devflow requires, stated in full in the README beside the verified
hosts, each with the symptom of its absence. It describes devflow rather than the world, so
it stays true without maintenance, and it is what lets a reader on an unnamed host judge
their own. Distinct from the delivery contract, which governs only how files reach a place
the host reads.
_Avoid_: host requirements, support matrix, compatibility list

**Verified host**:
A host the owner has run the manual pass against, named in the README with the release the
pass was run on, so a skipped pass goes visibly stale rather than silently false. The only
tier there is: an unverified host is not a lesser tier, it is unnamed. Membership is a
staffing fact, since a host joins by acquiring a standing verifier and leaves the release
that person stops, and the shipped adapter for it exists over exactly that span.
_Avoid_: first-class host, supported host, best-effort, tested platform

**Host adapter**:
The translation from an intent devflow states to the spelling one host uses for it, written as
prose under one heading per slot, alongside a separate list of the host's answers for the gating
capabilities. It answers a fixed list of slots the core owns, and it answers every slot
explicitly, including answering that this host has no equivalent, because silence would conflate
a capability a host lacks with one nobody recorded. It carries values, schema, and, where the
answer differs per install rather than per host, the method of obtaining a value in place of the
value: the intent, and the outcome a human is asked to reach, stay in the core. One ships per
verified host and one may be written on a machine for a host nothing promises anything about;
where both exist the shipped one wins and says so, since a silent override would let a stale
copy beat a fix.
_Avoid_: host config, shim, host module, per-host override, host branch

**Install record**:
The note of where this machine's host put the plugin's files and of the method that obtained it,
stamped with the devflow version that wrote it. Every skill that runs a shipped file reads it,
and a stamp differing from the reading skill's own means a record an earlier version wrote, which
refuses rather than resolving to a stale directory that still exists. Scoped to the install, so
it is the part of the machine record an upgrade invalidates and the only part.
_Avoid_: plugin path, root cache, machine config, install state

**Machine record**:
The one file devflow owns outside any repository, holding what nothing in the tree can answer:
the install record, the host slug, and the capability declarations when a human rather than an
adapter supplied them. Everything else a host decides is read from the adapter where it is used,
because a second copy drifts with nothing to catch it. Scoped to the machine, which is why it
outlives the install record it contains.
_Avoid_: machine config, devflow state, settings, home config

**Artifact repo**:
One GitLab repo per team, holding the artifacts an effort produces (maps, specs, ticket
drafts) and nothing else. It is where a draft issue waits while a human reviews it, and
the only home a cross-repo effort has. Not a tracker: finished tickets live in Jira.
_Avoid_: scratch repo, notes repo, planning repo

**Effort**:
One unit of wayfinding work, with its own map, occupying one directory under `efforts/`
in the artifact repo. An effort names the code repos it touches and may touch several, or
none. Distinct from a spec, which is one artifact an effort produces.
_Avoid_: project, feature, initiative

**Draft issue**:
A ticket written to the artifact repo, becoming a Jira issue only after the gauntlet
passes it and a human approves it. The distinction is the point of having two
destinations: before publication a draft is revisable and invisible to the board. The file
outlives publication and records the key it was given, which is what stops a second run
creating the issue twice.
_Avoid_: pending ticket, unpublished issue

**Jira issue standard**:
The team-owned document defining what a Jira issue body must contain, held at a fixed path
in the artifact repo. One copy per team, reviewed like any other change. The plugin reads
only this configured copy, never a personal file on the author's machine.
_Avoid_: ticket template, writing guide, conventions, house style

**Spec epic**:
The one Jira Epic that parents every issue published from a single spec, carrying the
spec's URL. Created before the first issue of that spec and recorded in the spec's header,
so a later run adds to it rather than creating a second.
_Avoid_: parent, theme, feature epic

**Gauntlet**:
The named set of checks bound to one run point. A repo declares its gauntlets in
`workflow.json`; a run point with no gauntlet declared is vacuous, reported as not run.
_Avoid_: gate, suite, quality bar, CI

**Check**:
One member of a gauntlet: a shell command, judged solely by its exit code, that receives a
subject. Always deterministic, never an agent exercising judgement, so that a pass means
the same thing on every machine.
_Avoid_: validator, rule, test, lint

**Run point**:
One of three transitions a gauntlet can gate: `ticket` before a ticket merges,
`integration` before a spec's work is handed over, `issue` before a draft issue reaches
Jira. A closed set, because the orchestrator must know where to call each one.
_Avoid_: stage, phase, hook, trigger

**Subject**:
The path a check is given, in `GAUNTLET_SUBJECT`. What it points at is decided by the run
point: a worktree for `ticket` and `integration`, a draft issue file for `issue`. The
subject is the only difference between checking code and checking a ticket.
_Avoid_: target, input, artifact under test

**Vacuous**:
Green for want of anything asserted: a scan that did not run, a run point declaring no checks,
a check that cannot be executed, a comparison made over an empty set. Never reported as a pass.
Which non-pass it becomes belongs to the site, and the two differ: a run point declaring nothing
is `not run`, while a check that is declared and cannot run is a failure. The empty-set guard
every check carries exists to make a vacuous result say so rather than come back green.
_Avoid_: silent pass, empty pass, skip, trivially true, no-op

**Upstream floor**:
The commit at or after which an upstream installation is supported. Declared once, in the
plugin's dependency probe, and in no repo's configuration, because a repo able to set the
floor is a repo able to lower it. Asserted by content rather than by a version string: the
probe looks for the skills and the file names that commit introduced, since upstream's
manifests lag its content and the supported install route records no version on disk.
_Avoid_: clean environment, pin, sync, minimum version, pinned release

**ADF converter**:
The plugin's dependency-free Node ESM script turning a draft issue's markdown into
Atlassian Document Format, because acli accepts no other structured input. Copied into the
artifact repo by the setup skill, so publishing works without the plugin installed.
_Avoid_: renderer, formatter, markdown parser, adf builder

**Issue review**:
The non-blocking read of a draft issue against the Jira issue standard, run in a fresh
subagent after the gauntlet and before the human. Not a check, because it exercises
judgement and never gates; not the human gate, because it only produces findings. It
exists so the draft meets a reader who was not in the room when it was written.
_Avoid_: review check, approval, second pass, QA

**Orchestrated build**:
The build phase run across many tickets at once, each worker in its own worktree, merged
back as it finishes. Naming it separates the capability from the skill that offers it.
_Avoid_: parallel build, build loop, implement-spec

**Inline build**:
The build phase run in the session that is driving it: one ticket, no subagent, no
worktree, the user present. Nothing is spawned, so nothing can fan out into a shared tree.
_Avoid_: sequential build, serial build, in-session build

**Integration branch**:
The one branch an orchestrated build converges on, created before the first worker and
handed over when the last ticket merges. Every worker starts from its tip and every
finished ticket fast-forwards into it. Matt's term, kept unchanged.
_Avoid_: spec branch, feature branch, main, trunk

**Worker**:
A subagent that owns exactly one ticket, in its own worktree, on its own branch. It is the
only thing that writes code, and it reports its branch and final SHA because nothing else
reliably states them. One ticket is its whole scope, so a worker is never reassigned.
_Avoid_: implementer, agent, coder, task runner

**Worker preamble**:
The rules the orchestrator restates in full in every worker's prompt, rather than leaving
in a file the worker may not read. It exists because a worker that misses a rule fails
silently, and the per-spawn cost of repetition is the price of that. Parent-side rules are
not part of it.
_Avoid_: worker instructions, system prompt, agent config

**Orchestrator**:
The user's own session while it is following the router, in the main checkout and on the
integration branch. Not an agent and never isolated, which is what lets it reach into a
worker's worktree to run a gauntlet. It is the only thing that runs a gauntlet.
_Avoid_: coordinator, driver, primary agent, orchestrator agent

**Isolation check**:
The orchestrator's assertion, on receiving a worker's report and before anything else, that the
worker really ran in its own worktree: it looks the branch up in the repository's own worktree
record and uses the path it finds there. It is a lookup rather than a verification of what the
worker said, so the worker's reported path is only ever a cross-check. A failed lookup aborts the
whole run, because an unisolated worker has already written into the main checkout.
_Avoid_: worktree-root comparison, isolation detection, worktree verification

**Router**:
The one skill a user invokes to start or resume work. It reads the configuration, says
which phase you are in, loads the procedures that phase needs, and names the next phase
skill for the user to type. It proposes a phase and never loads one.
_Avoid_: orchestrator skill, develop skill, entry point, dispatcher

**Phase skill**:
A skill the human types, because invoking it starts expensive work. Model-invisible, so the
router names it rather than calling it.
_Avoid_: command, entry point, top-level skill

**Procedure skill**:
A skill another skill loads mid-task. Model-invocable, carrying no phase of its own, so
that one copy of a procedure serves every caller. The split between this and a phase skill
is upstream's, kept unchanged.
_Avoid_: helper skill, sub-skill, library skill, reference

**Conformance**:
A skill's agreement with the Agent Skills specification text at the commit this repo
cites. Not agreement with the standard's reference validator, which enforces a stricter
rule on frontmatter keys that the specification does not state. The two readings disagree
about most of the skills here, so the word is only ever used in the first sense.
_Avoid_: validity, compliance, passing the validator

**Plugin-supplied executable**:
A file the plugin ships to be run from inside a repo rather than from inside the plugin:
the gauntlet checks and the ADF converter. It reaches the repo by being copied, so the
config can name a repo-relative path and the repo keeps working without the plugin.
_Avoid_: bundled script, builtin check, helper, asset

**Payload installer**:
The script that copies plugin-supplied executables into one destination directory,
refusing rather than overwriting a file that differs. Never user-facing and never a git
caller: the setup skill invokes it and owns everything around it.
_Avoid_: agent installer, sync, deploy, bootstrap

**Triage role**:
One of five states describing how ready an issue someone else filed is to be worked:
`needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`. A readiness
axis, not a progress one, so a role is a property of an issue that is still open rather
than a point between open and done. Upstream's vocabulary, belonging to an inbound tracker;
this flow publishes issues that are past triage by construction and never carries a role.
_Avoid_: triage label, triage status, state label

**Publish phase**:
The step between tickets and build where a draft issue becomes a Jira issue: the spec epic
first, then per draft a machine gate, a non-blocking review, a human gate and the `acli`
call, then the blocking links in a second pass. The only phase that writes to Jira, and the
last point where a scope correction costs nothing.
_Avoid_: ticket creation, sync, export, push to Jira

**Ship phase**:
The step after the build where the integration branch leaves the machine: the `integration`
gauntlet, then the push, then one merge request for the spec. Distinct from the build, which
ends at a merged branch nobody else can see.
_Avoid_: PR phase, handover, release, delivery

**On-ramp**:
A starting situation that generates work and then joins the main flow, rather than a step
along it: an incoming bug report, a hard bug, a foggy effort, a health pass. The router names
the skill that owns each and says nothing more, because routing is naming.
_Avoid_: entry point, trigger, side flow

**Acceptance run**:
A real multi-ticket run on a real repo, watched by a human, which is the only thing that
exercises a build end to end. Not a check and never automated: it asserts on judgement a
human makes while watching. It is named because no gauntlet covers it, and the file that
says so is `docs/agents/gauntlets.md` rather than the README.
_Avoid_: smoke test, test matrix, manual test, integration test

**Setup tier**:
A scope that setup writes once and then detects rather than rewrites: team-level, shared by
every repo a team works in; repo-level, committed so the team reproduces it; machine-local,
different for every engineer. Crosses the configuration surfaces rather than lining up with
them, because a surface is defined by who reads it and a tier by what it is scoped to.
_Avoid_: setup phase, setup step, scope, install level
