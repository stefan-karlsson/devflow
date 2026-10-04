# The machine-local tier

State scoped to this machine. Most of it is scoped to this repository as well, and the machine
record is not: `$HOME/.devflow/machine.json` holds where this machine's host put the plugin's
files and which host this is, which are facts about the install and about the machine rather than
about any repository. Setup writes it before the tiers run, and this tier does not touch it.

Everything below is the per-repository half, which is what the second engineer in an
already-configured repository writes, and all they write. None of it is committed: six engineers
have six home directories, so an absolute path in a committed file would not reproduce for
anyone else.

Read this only when the tier's detection says it is absent. The tier is present when every step
below is already satisfied; each step detects its own state, so a partial tier completes rather
than starts over.

Every step shows its diff before writing, and a rejected diff is not written.

## Order

The steps are independent except that the additional-directory entry names the clone, so the
clone is created first. Run the clone step before the entry step; the rest may run in any order.

## Node

Assert that `node` is on the path.

When it is absent, **warn and continue**. Do not stop, and do not skip anything else. Nothing in
the configuration this skill writes needs Node to be written, and the one tool that needs Node to
run is the markdown-to-ADF converter, which `publish-issues` refuses to run without it. An
engineer who will never publish an issue from this machine still gets a working build loop. Say
exactly that in the warning, naming `publish-issues`, so the warning is not mistaken for a broken
setup.

## The sibling artifact repository clone

The team's artifact repository holds effort artifacts and draft issues. A session working in the
code repository reaches it as a clone on this machine.

- **The remote comes from the repository's configuration**, under the artifacts section. It is
  the one thing committed about the artifact repository.
- **The path is derived and never written into a committed file.** Derive it as a sibling of this
  repository's checkout: the clone sits beside the code repository's root directory, under the
  name the remote's own repository carries. Nothing stores it; it is re-derived the same way by
  anything that needs it.
- **Already present** when that path holds a git repository whose origin is that remote. Say so
  and move on. A clone that exists with a different origin is reported and not touched.

When the configuration carries no artifacts remote, this step is skipped and says why: the
repository tier writes that key, and a remote guessed here would be wrong in a way nobody
notices until a publish fails.

**Do not create the artifact repository.** If the clone fails because the remote does not exist,
stop this step and hand the human a checklist: the group it belongs under, the visibility
decision, and working authentication for the host it lives on. A half-created project with
unclear auth is the harder failure to recover from, and all three are decisions rather than
commands.

## The additional-directory entry

A session reaches a directory outside its own repository only where the host has been told to.
Slot 5 of the chosen adapter gives the key and whether its value is one path or a list, and slot
2 gives the machine-local settings file it belongs in. Add the clone's absolute path there,
creating the file when it is absent and merging into it when it is not. The committed settings
file is the repository tier's and is not touched here.

**Already present** when that key already carries the path.

Where slot 5 answers that this host reaches any path without being told, there is nothing to
write and the step is skipped, saying so. Where it answers that this host reaches nothing outside
the repository, write nothing, warn, and name the exposure rather than the key: an issue is
published out of the artifact clone, so nothing on this machine can publish one.

## The machine-local settings file is not committed

The machine-local settings file slot 2 names carries this machine's absolute paths and this
machine's choices, neither of which reproduces for anyone else. Check that the repository's
ignore rules already cover it. Where they do not, add it to the repository's machine-local
exclude file rather than to a committed ignore file, which keeps a machine-local decision
machine-local.

## What installing this costs on every turn

The dependency probe already ran, and it printed three counts: the skills reachable on this
machine before this plugin, the number after it, and the difference.

State those numbers, and state the direction: every installed skill's description sits in the
model's context window on every turn, so each skill added is a fixed overhead paid on every turn
of every session on this machine, whether or not the session has anything to do with that skill.
What is paid is the machine's whole skill count, not this plugin's share of it. Suggest pruning
what they do not use.

Do not quote a figure measured on another machine. What is installed is a property of this
machine, the counts above were measured on it, and a number carried over from elsewhere
describes a machine the engineer is not sitting at.
