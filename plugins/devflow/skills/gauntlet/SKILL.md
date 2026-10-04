---
name: gauntlet
description: Run a repository's declared checks for one run point and hand the result back as text. Use when a transition has to be gated, a ticket before it merges, the integration branch before the work is handed over, or a draft issue before it reaches Jira. Takes a run point from the closed set `ticket`, `integration`, `issue` and a subject path, runs every check the configuration declares for that run point, and reports each one as `passed`, `failed` or `not run` with the captured output verbatim. Another skill can load this one, and a human can type it.
---

# Gauntlet

A **gauntlet** is the set of **checks** a repository declares for one **run point**. A check
is a shell command judged by its exit code. It receives a **subject**, a path, and the run
point decides what that path points at. That single parameter is the only difference between
checking code and checking a ticket, which is why there is one contract here and not two.

This is a procedure. It runs what is declared and reports what happened. It decides nothing
else.

## What this procedure does not decide

- Who may run it, and at which moment. The orchestrator owns every transition and is the only
  thing that calls a gauntlet. An implementer reporting its own check results is making a
  claim, not passing a gate.
- What to do about a failure. Retrying, routing the output back to an implementer, bounding
  the attempts and stopping to ask a human are all the caller's.
- Which checks a repository should have. Checks are discovered and approved when the repository
  is set up, never invented here and never discovered at run time.

Report the outcomes and return. Do not act on them.

## Inputs

The caller supplies both. Neither is guessed.

- **Run point**, exactly one of `ticket`, `integration`, `issue`. The set is closed. Anything
  else is a caller error: say the run point is not one of the three and stop. This refusal is
  not a configuration problem, so it does not name the setup skill.
- **Subject**, a path. For `ticket` and `integration` it is a path in the repository being
  checked, normally its root. For `issue` it is the draft issue file.

If a human types this skill without naming both, ask for the missing one.

## The configuration it requires

The declaration lives under the `gauntlets` key of `docs/agents/workflow.json` in the code
repository, at that one fixed path. Do not search for it and do not walk up the tree. All
three run points are declared there, including `issue`, whose checks run elsewhere.

`gauntlets` is the only key this procedure needs. Refuse, naming the skill and the key, when:

- the file is absent: *"gauntlet needs `docs/agents/workflow.json`, and it is not there. Run
  `setup-devflow` to write it."*
- the file does not parse as JSON: *"gauntlet cannot read `docs/agents/workflow.json`: it is
  not valid JSON. Run `setup-devflow` to rewrite it."*
- `gauntlets` is absent from it: *"gauntlet needs the `gauntlets` key in
  `docs/agents/workflow.json`, and it is not there. Run `setup-devflow` to write it."*

A `gauntlets` object that declares nothing for the requested run point is not a refusal. It is
`not run`, below.

An entry is a `name`, a `command` and an optional `description`. Read them with `jq`:

```
jq -e '.gauntlets' docs/agents/workflow.json          # absent or unparseable means refuse
jq -r '.gauntlets.ticket[]? | .name + "\t" + .command' docs/agents/workflow.json
```

Looking the run point up in an object keyed by run point is the whole not-run test. An absent
key and an empty array both mean nothing is declared, and neither is ambiguous.

## Running the checks

Run every declared check, in declared order. Carry on after one fails, so the handover covers
the whole set rather than stopping at the first failure.

For each entry:

1. **Working directory is the repository the subject lives in.** The worktree for `ticket` and
   `integration`, the artifact repository clone for `issue`. A relative path inside a command
   resolves from there.
2. **`GAUNTLET_SUBJECT` carries the subject.** The subject is never appended as an argument. A
   command that wants the subject reads the variable, and a command that ignores it is
   unaffected, which is why `npm run lint` is a valid check with no wrapping around it.
3. **The command is a string, executed through the shell.** Run it as written. Do not split it
   into arguments, do not add flags, do not substitute a command you believe is equivalent.
   `npm run lint && npm run typecheck` is one check.
4. **Capture stdout, stderr and the exit code.** Both streams, in full.

```
GAUNTLET_SUBJECT=<subject> bash -c '<command>'
```

There is no timeout in this contract. A check that needs one carries its own in its command
string, where it is visible in the committed configuration.

## The outcomes

Three, and only these three words.

- **passed**: the command exited 0.
- **failed**: the command exited non-zero. A check that could not run at all, because the
  command was not found or the file was not executable, is **failed** and never skipped: the
  configuration made a promise the repository broke, and that is louder as a failure than as a
  note.
- **not run**: nothing is declared for this run point. The flow proceeds. `not run` is never
  written, summarised or implied as a pass, because silence read as a pass is how a breakage
  ships unnoticed.

Every check blocks. There is no advisory flag and no severity, so do not invent one for a check
you judge unimportant.

Exit code is the only verdict. Your own reading of the output is never a check, and never
overrides, softens or supplements the code the command returned.

## The handover

Hand back the captured text. The reader is a model, and the model is the parser, so a failure's
output is passed through **verbatim**: not summarised, not trimmed to the interesting lines, not
reworded, not re-indented. Merging the two streams in the order they arrived is fine. Dropping
anything is not.

```
Gauntlet: <run point>
Subject: <subject path>
Working directory: <path>

  <name>: passed
  <name>: failed (exit <code>)

--- <name>, exit <code> ---
<captured stdout and stderr, verbatim>
--- end <name> ---

Verdict: <passed | failed>
```

The verdict is `failed` when any check failed, `passed` when every declared check passed, and
`not run` when nothing was declared:

```
Gauntlet: <run point>
Subject: <subject path>
Nothing is declared for this run point.

Verdict: not run
```
