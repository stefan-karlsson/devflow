# Issue tracker: Jira

Issues for this repo live in Jira, reached through `acli`. Which site, which project and which
issue type are not written here: they are `tracker.site`, `tracker.projectKey` and
`tracker.issueType` in `docs/agents/workflow.json`. One value, one home. A skill that needs one
reads it from there and refuses by naming the key when it is absent.

Drafts are not Jira issues. A draft issue is a markdown file in the effort's directory in the
team's artifact repo, under `issues/NN-<slug>.md`, and it stays there until a human has read it.
Only reviewed drafts reach the board.

## The issue standard

What a published issue contains is the team's standard, one file at a fixed path in the artifact
repo: `docs/agents/jira-issue-standard.md`. **It supersedes any issue template a skill carries of
its own.** Read it before writing a draft.

Which h2 sections make up the body, and the order they come in, are that file's to state. One
value, one home applies to prose as much as to configuration: a list repeated here would be the
copy a reader meets first and the copy nobody updates.

Parent and Blocked by never appear as prose sections. They leave the body entirely and become
native Jira relationships, because a prose restatement of what Jira holds natively goes stale
and the board cannot see it.

## Triage state

Triage state never reaches Jira. The five role strings in `triage-labels.md` are a readiness
axis, a Jira project's statuses are a progress axis, and an issue published from this flow is
past triage by construction. No label of any kind is written to a published issue.

## When a skill says "publish to the issue tracker"

Do not call `acli create` from a skill that is not the publishing phase. Publishing is its own
phase with a fixed gate order, and the cheapest place to correct scope is before any code is
written.

Markdown reaches Jira as ADF, converted by the team's converter in the artifact repo and fed to
`acli` through standard input. There is no markdown, wiki or format flag on any `acli jira`
subcommand; ADF is the only supported door.

## When a skill says "close the ticket"

Nothing here transitions a Jira status, ever. The honest done status differs per issue type on a
real project, and the status a team reads on its board belongs to the team and its release
pipeline rather than to this tooling. The integration branch is the record of which tickets are
done: the branch pattern in `docs/agents/workflow.json` encodes the ticket key, so `git log`
answers the question.

## When a skill says "fetch the relevant ticket"

The user normally passes the issue key directly. Read it with `acli`.

Two things to know before writing a query:

- **Inspect a `--json` shape once and read the field you need from what you saw.** Do not carry a
  `jq` path in from another site or another version. The shapes differ and a wrong path returns
  empty rather than failing.
- **Direction on a blocking link must be read back from the issue's own link fields.** The
  confirmation line printed when a link is created states the direction backwards. The inward
  side is the blocker.
