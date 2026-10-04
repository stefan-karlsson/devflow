# The slots

A **slot** is one thing devflow needs that each host spells differently. The core states the
intent and the outcome a human is asked to reach; a host adapter states one host's spelling for
it. This file is the enumeration, and it is the only one. An adapter answers it rather than
restating it, so a slot added here is a slot every adapter is immediately missing.

Read this to write an adapter, and read it to add a slot.

## How an adapter answers

- **One `### Slot N: <name>` heading per slot, spelled exactly as below.** A check derives the
  expected set from this file's headings and asserts that every file under
  `plugins/devflow/adapters/` answers exactly that set: no slot missing, and no heading that is
  not a slot here. That is what keeps this list and the adapters one list.
- **Answer every slot explicitly, including answering that this host has no equivalent.**
  Silence is not an answer. It conflates a thing the host lacks with a thing nobody got round to
  recording, and those two have different consequences: the first is degradation the core can
  describe, the second is a blank somebody meets at setup time.
- **Prose, not data.** No script reads an adapter for its values; the model does, at the point
  of use. The checks read only the headings. Several answers are sentences, because several of
  the things being answered are sentences.
- **Answers only.** The intent under each heading below is the core's and stays here. An adapter
  that repeats it has made a second copy of the one thing this file exists to hold once.

## Adding a slot

Add the heading and its intent below, then answer it in every shipped adapter in the same
commit. The check fails until they agree, which is the point: a slot added to the core alone
leaves a blank that nothing announces until a human hits it.

## The enumeration

### Slot 1: Plugin self-location

**The method by which the plugin root is obtained on this host.** Every shipped script runs at a
path built from that root, so a host that cannot yield it cannot run any check devflow ships.

The answer is a **method and never a path**. The path is per install and an adapter is per host,
and this repository rewrites nothing at install time.

Three shapes are admissible:

- a command that prints the path,
- a documented layout the human reads the path off,
- asking the human for an absolute path.

One shape is inadmissible: **a variable the host substitutes into a skill body.** devflow's
bodies carry no host spellings, and nothing rewrites them on the way in, so a variable only some
hosts expand is a body that silently expands to nothing on the rest. The symptom is a missing
file at a path with a hole in it, found by whoever ran the phase rather than by whoever chose
the spelling.

Answering that this host has no equivalent is a real answer with a stated price: **setup asks
the human for the path on every upgrade.** The root is cached with a version stamp that an
upgrade invalidates, and where there is no method to re-run, the human is the only thing left
that can supply the next one. The host still works. Say so in the adapter rather than leaving
the author to meet it on their second install.

### Slot 2: Host settings files

**The files this host reads its own configuration from, committed and machine-local, by path.**
Slots 3, 4 and 5 are keys, and this slot is where those keys live.

Two paths relative to the repository root, and which is which. One is committed, so that a
teammate's checkout reproduces this one and `git log` shows when a value changed. One is
machine-local, because it carries absolute paths and choices that do not reproduce for anyone
else, and it has to be covered by the repository's ignore rules. Say what the host does when
both files set the same key.

A host that keeps its configuration somewhere other than the repository says where, and a host
with no settings file at all says that, which answers slots 3, 4 and 5 with it.

### Slot 3: Deny spelling

**How "no `git stash` in this repository" is expressed.** `refs/stash` is shared across every
worktree of a repository, so a stash one worker pushes is a stash another can pop. The worker
rules say this in prose; this slot is the half the host enforces rather than the half a model
has to remember.

The answer is the key, the file from slot 2 it goes in, and the value as this host spells it.

Where the host has no equivalent, the rule stands as prose alone. Setup skips the key, warns,
and names the exposure rather than the missing key, because the engineer cares that worktrees
share a stash and not that a setting was unwritable.

### Slot 4: Worktree symlink spelling

**How "worktrees do not share dependency directories" is expressed.** A host that links one
dependency directory into every worktree has workers installing over each other, and that
surfaces as a build failure in a worktree whose files nobody touched.

The answer is the key, the file from slot 2, and the value that leaves each worktree its own
directories. Say what the host does when the key is absent: where the default is already safe,
writing the key is a confirmation rather than a change, and the adapter should say which it is.

Where the host does not create worktrees at all, say so. The orchestrated build is gated on C6
and reads its answer there; this slot is only the hardening.

### Slot 5: Additional-directory spelling

**How a session is given reach into the artifact clone.** The team's artifact repository lives
beside the code repository as a clone on this machine, and a session that cannot read outside
its own repository cannot publish an issue.

The answer is the key, the file from slot 2 it goes in, and whether the value is one path or a
list. It belongs in the machine-local file: the clone's path is derived per machine and never
committed.

Where the host has no equivalent, say which kind of no it is. A host that reaches any path needs
no key, and a host that reaches nothing outside the repository cannot publish, which is a thing
the human is told at setup rather than at the first publish.

### Slot 6: Upstream install command

**The command that installs the upstream skills on this host.** devflow ships no copy of them
and loads them by bare name, so they are installed before setup runs.

The core always states the requirement, because the requirement is the same everywhere. This
slot is the command, which is not, and the usual reason it is not is that the installer is told
which host it is installing for.

The answer is the exact command. Where the host has no equivalent, the core prints the
requirement alone and the human finds their own route to it. That is a working answer, not a
failure: what the core needs is that the skills resolve by bare name, not that any particular
installer put them there.

### Slot 7: Restart mechanism

**What the human does so the host reads the configuration setup just wrote.** Most hosts do not
re-read plugin or repository configuration mid-session, which makes the session that ran setup
the one session where none of what was written is in effect. An engineer who keeps working in it
sees a repository showing no sign of the setup and reads the install as having failed.

The answer is what the human does, in the words their own host uses for it, and whether anything
short of a full restart is enough.

Where the host re-reads its configuration as it changes, say so. Setup then tells nobody to
restart, which is worth having explicitly: a restart instruction on a host that needs none reads
as a tool that does not know its own environment.
