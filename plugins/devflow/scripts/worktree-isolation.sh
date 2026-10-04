#!/usr/bin/env bash
#
# worktree-isolation: does this branch sit in a worktree that is not the main checkout?
#
# An orchestrator spawns each worker into a worktree of its own and then has no way of
# knowing whether it got one. A host that accepts the isolation argument and ignores it,
# and a call that dropped the argument, produce the same silent outcome: every worker
# resetting and committing in the user's own checkout. This script turns that into an
# exit code, which is the only form the flow can act on.
#
# What it asserts, and nothing more: that `git worktree list --porcelain`, read in the
# subject repository, holds a worktree whose branch line is exactly refs/heads/<branch>,
# that this worktree is not the one git lists first, and that the HEAD git reports for
# it is the string the caller passed. It reasons only about what git knows. It never
# reads the worker's own account of where it was, it does not look at the worktree's
# contents, and it says nothing about whether the work in it is sound.
#
# The parse matches refs/heads/<branch> exactly, so a branch whose name is a prefix of
# another branch's name cannot select that other branch's worktree. The first record git
# prints is the main checkout; git documents that order.
#
# Three limits of the parse. They are stated here, beside the code that has them, and
# nothing else in the repository restates them:
#
#   - A worktree with a detached HEAD carries no branch line in the porcelain record and
#     is therefore never matched, whatever commit it sits on.
#   - A worktree path containing a newline is beyond this parse, which is the case git
#     offers --porcelain -z for.
#   - The SHA comparison is string equality, so an abbreviated SHA is a false exit 3
#     rather than a match. Callers pass the SHA exactly as the worker printed it.
#
# Dependency-free bash. It reads no JSON, so it needs no jq, and it shells out to
# nothing but git.
#
# Exit 0 the branch is in a worktree that is not the main checkout and its HEAD is the
# reported SHA, and that worktree's path is on stdout and nothing else is. Exit 1 the
# branch is checked out in the main checkout. Exit 2 no worktree in this repository
# holds the branch. Exit 3 it is isolated, but HEAD is not the reported SHA. Exit 4 the
# check could not run, with the reason on stderr. Nothing but the exit-0 path is ever
# written to stdout.
#
# Usage: worktree-isolation.sh <branch> <reported-sha>
#
# DEVFLOW_REPOSITORY names the repository to inspect and is what makes this script
# testable against fixture repositories rather than only against the checkout it is run
# from. Unset, the subject is the working directory, which is the orchestrator's own
# checkout.

set -uo pipefail

unusable() { # unusable <reason>, the check could not run
	printf 'worktree-isolation: %s\n' "$1" >&2
	exit 4
}

[ "$#" -eq 2 ] || unusable 'usage: worktree-isolation.sh <branch> <reported-sha>'

branch=$1
sha=$2

[ -n "$branch" ] || unusable 'the branch argument is empty.'
[ -n "$sha" ] || unusable 'the reported SHA argument is empty.'

repository=${DEVFLOW_REPOSITORY:-$PWD}
[ -d "$repository" ] || unusable "the subject $repository is not a directory."

listing=$(git -C "$repository" worktree list --porcelain 2>&1) ||
	unusable "git could not list the worktrees of $repository: $listing"

path=
head=
index=0
found=
found_head=
matched=0

while IFS= read -r line; do
	case $line in
	'worktree '*)
		path=${line#worktree }
		head=
		index=$((index + 1))
		;;
	'HEAD '*)
		head=${line#HEAD }
		;;
	# Quoted, so a branch name is matched as text and never as a glob, and matched
	# whole, so refs/heads/feature does not answer for refs/heads/feature-two.
	"branch refs/heads/$branch")
		found=$path
		found_head=$head
		matched=$index
		break
		;;
	esac
done <<<"$listing"

[ "$matched" -eq 0 ] && exit 2
[ "$matched" -eq 1 ] && exit 1
[ "$found_head" = "$sha" ] || exit 3

printf '%s\n' "$found"
exit 0
