# devflow

This repository distributes one plugin, `devflow`, which runs Matt Pocock's skill flow from
the engineer's own installation of those skills, configured per repo.

## Language

**Configuration surface**:
A place configuration lives, identified by who reads it. The effort has three: prose under
`docs/agents/`, read by an agent; data in `docs/agents/workflow.json`, read by an agent and
by a shell script; and host keys in the target repo's `.claude/settings.json`, read by
Claude Code itself. A value belongs to exactly one surface, chosen by its reader rather
than by its subject.
_Avoid_: config file, config location, settings

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
`workflow.json`; a run point with no gauntlet declared is reported as not run, never as
passed.
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
