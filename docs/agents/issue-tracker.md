# Issue tracker: Local Markdown

Issues and specs for this repo live as markdown files in `.scratch/`, which is untracked.
They are an engineer's working notes on their own machine, not repository content, and the
repository is public. Nothing in `.scratch/` is committed, pushed or reviewed.

## Conventions

- One feature per directory: `.scratch/<feature-slug>/`
- The spec is `.scratch/<feature-slug>/spec.md`
- Implementation issues are one file per ticket at `.scratch/<feature-slug>/issues/<NN>-<slug>.md`, numbered from `01`, never a single combined tickets file
- Triage state is recorded as a `Status:` line near the top of each issue file (see `triage-labels.md` for the role strings)
- Comments and conversation history append to the bottom of the file under a `## Comments` heading
- `.scratch/<effort>/wayfinding/` holds answered questions from `/wayfinder`, not open work. Implementation work is only ever in `issues/`

## When a skill says "publish to the issue tracker"

Create a new file under `.scratch/<feature-slug>/` (creating the directory if needed).

## When a skill says "close the ticket"

- Append a `## Resolution` heading to the ticket file naming the branch and the merge commit that carried the work.
- Leave the `Status:` line alone. It records triage readiness, `triage-labels.md` owns its values, and none of them mean done.
- Nothing records progress as a field. The integration branch is what says which tickets are finished: a ticket branch carries its number, so `git log` on the integration branch answers a resumed build's question. There is no work-state file.

## When a skill says "fetch the relevant ticket"

Read the file at the referenced path. The user will normally pass the path or the issue number directly.

## Wayfinding operations

Used by `/wayfinder`. The **map** is a file with one **child** file per ticket.

- **Map**: `.scratch/<effort>/map.md` (the Notes / Decisions-so-far / Fog body).
- **Child ticket**: `.scratch/<effort>/wayfinding/NN-<slug>.md`, numbered from `01`, with the question in the body. A `Type:` line records the ticket type (`research`/`prototype`/`grilling`/`task`); a `Status:` line records `claimed`/`resolved`.
- **Blocking**: a `Blocked by: NN, NN` line near the top. A ticket is unblocked when every file it lists is `resolved`.
- **Frontier**: scan `.scratch/<effort>/wayfinding/` for files that are open, unblocked, and unclaimed; first by number wins.
- **Claim**: set `Status: claimed` and save before any work.
- **Resolve**: append the answer under an `## Answer` heading, set `Status: resolved`, then append a context pointer (gist + link) to the map's Decisions-so-far in `map.md`.
