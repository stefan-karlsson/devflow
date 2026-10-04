# Claude Code

An adapter exists only for a host that meets the four required capabilities, so this file
answers none of them. Claude Code resolves a skill by its frontmatter name wherever it is
installed, honours `disable-model-invocation`, exposes the plugin's shipped files as a
filesystem path, and runs a shell command in the repository and reports its exit code. A host
missing any of those four gets no adapter, because devflow does not run on it at all.

The slots and their intent are the core's, in
[slots.md](../skills/setup-devflow/references/slots.md). This file is the answers.

**Written against Claude Code 2.1.289.** An answer here is a claim about that release and
nothing later. Where a newer release has moved a key, the fix is this file.

## Capabilities

The two gating capabilities, each `present`, `absent` or `unknown`.

- **C5, spawns a subagent carrying none of the caller's context:** `present`. A subagent is
  spawned with the prompt it is given and no transcript behind it, which is what lets
  `publish-issues` have a draft reviewed by something that did not write it. Publish attempts
  the spawn regardless and reports how the review actually ran, so this answer is read by a
  human and by the verifier rather than used as a gate.
- **C6, spawns a subagent isolated in its own git worktree:** `present`. A worker runs in its
  own worktree under the main checkout's `.claude/worktrees/`, with its own branch and its own
  working files. `orchestrated-build` runs only on `present`, and the isolation check still
  verifies the worktree per spawn, because a declaration is a claim about the host and not about
  the spawn that just happened.

## Slots

### Slot 1: Plugin self-location

A command that prints the path:

```
claude plugin list --json
```

Read the installed devflow plugin's `installPath` from the output. That is the plugin root, and
every shipped script is reached at a path built from it.

The plugin and the marketplace share the name, so the entry reads `devflow@devflow`. Where no
entry matches, the plugin is not installed on this machine and setup refuses at that step rather
than guessing a path.

### Slot 2: Host settings files

- **Committed:** `.claude/settings.json`, at the repository root.
- **Machine-local:** `.claude/settings.local.json`, beside it.

The machine-local file wins where both set the same key. It carries this machine's absolute
paths and this machine's choices, neither of which reproduces for a teammate, so it is excluded
through the repository's machine-local exclude file rather than through a committed ignore file.

Claude Code also reads a user-level `~/.claude/settings.json`. devflow writes nothing there: all
three slots below are scoped to one repository, and a value written into the user file would
follow the engineer into repositories that never asked for it.

### Slot 3: Deny spelling

In the committed file, a `Bash(git stash:*)` entry in the `permissions.deny` list:

```json
{
  "permissions": {
    "deny": ["Bash(git stash:*)"]
  }
}
```

The pattern covers the subcommands too, so `git stash push` and `git stash pop` are both denied
by the one entry. The deny list is merged into, never replaced: a repository that already denies
other commands keeps them.

### Slot 4: Worktree symlink spelling

In the committed file, `worktree.symlinkDirectories` present and set to the empty list:

```json
{
  "worktree": {
    "symlinkDirectories": []
  }
}
```

Written explicitly rather than left absent. An absent key is whatever the running release
defaults to, and what the repository means here is a decision it should be able to show in a
diff. Where the engineer asked for entries in it, theirs stand and setup says it left them.

### Slot 5: Additional-directory spelling

In the machine-local file, the artifact clone's absolute path appended to the
`permissions.additionalDirectories` list:

```json
{
  "permissions": {
    "additionalDirectories": ["/absolute/path/to/the/artifact/clone"]
  }
}
```

A list, merged into rather than replaced. The path shown is a placeholder: the real one is
derived as a sibling of this repository's checkout, by the machine tier, and is never written
into a committed file.

### Slot 6: Upstream install command

```
npx skills@latest add mattpocock/skills -a claude-code
```

The `-a claude-code` names this host to upstream's installer, which is the whole reason the
command is a slot and the requirement is not.

### Slot 7: Restart mechanism

Quit the session and start Claude Code again in the same repository.

Claude Code does not re-read plugin or repository configuration mid-session. Nothing shorter is
offered here on purpose: one setup run writes plugin-scoped and repository-scoped state
together, and telling someone a partial reload will do leaves them unable to say which half of
what they just wrote is live.
