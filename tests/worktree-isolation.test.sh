#!/usr/bin/env bash
#
# Drives the worktree isolation check against real git repositories with real
# worktrees, built in a temporary directory, and asserts observable outcomes only: the
# exit code, and the path on stdout. Never the wording, so the script's prose can be
# rewritten without rewriting this file.
#
# Subject: GAUNTLET_SUBJECT, falling back to the repository this file sits in.

set -uo pipefail

self_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
subject=${GAUNTLET_SUBJECT:-$(cd -- "$self_dir/.." && pwd -P)}
script=$subject/plugins/devflow/scripts/worktree-isolation.sh

# The fixtures are real repositories, so git must not read this machine's configuration
# or be steered by an inherited git environment. Nothing below depends on the user who
# runs it.
export GIT_CONFIG_GLOBAL=/dev/null
export GIT_CONFIG_SYSTEM=/dev/null
export GIT_AUTHOR_NAME=fixture
export GIT_AUTHOR_EMAIL=fixture@example.invalid
export GIT_COMMITTER_NAME=fixture
export GIT_COMMITTER_EMAIL=fixture@example.invalid
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE DEVFLOW_REPOSITORY

work=$(mktemp -d) || exit 1
work=$(cd -- "$work" && pwd -P)
# Every repository and every worktree this file registers lives under $work, so the
# removal below deregisters all of them and the checkout this suite runs in is never
# touched.
trap 'rm -rf -- "$work"' EXIT

cases=0
failures=0

check() { # check <status> <name>
	cases=$((cases + 1))
	if [ "$1" -eq 0 ]; then
		printf 'ok    %s\n' "$2"
	else
		printf 'FAIL  %s\n' "$2"
		failures=$((failures + 1))
	fi
}

fresh() { # fresh <label>, prints a new empty directory, real path resolved
	local d
	d=$(mktemp -d "$work/$1.XXXXXX") || exit 1
	(cd -- "$d" && pwd -P)
}

repo() { # repo <directory>, makes it a repository holding one commit on main
	git -C "$1" init --quiet -b main || exit 1
	printf 'one\n' >"$1/file" || exit 1
	git -C "$1" add file || exit 1
	git -C "$1" commit --quiet -m one || exit 1
}

worktree() { # worktree <repository> <branch> <label>, prints the new worktree's path
	local path=$work/$3
	git -C "$1" worktree add --quiet -b "$2" "$path" >/dev/null 2>&1 || exit 1
	(cd -- "$path" && pwd -P)
}

commit() { # commit <worktree> <text>, adds a commit there and prints the new HEAD
	printf '%s\n' "$2" >"$1/file" || exit 1
	git -C "$1" add file || exit 1
	git -C "$1" commit --quiet -m "$2" || exit 1
	git -C "$1" rev-parse HEAD
}

run() { # run <repository> <argument>..., captures stdout in $out, stderr in $errout
	local repository=$1 errfile
	shift
	errfile=$(mktemp "$work/stderr.XXXXXX") || exit 1
	out=$(DEVFLOW_REPOSITORY=$repository "$script" "$@" 2>"$errfile")
	status=$?
	errout=$(cat -- "$errfile")
}

run_in() { # run_in <directory> <argument>..., the same but with no subject named
	local directory=$1 errfile
	shift
	errfile=$(mktemp "$work/stderr.XXXXXX") || exit 1
	out=$(cd -- "$directory" && "$script" "$@" 2>"$errfile")
	status=$?
	errout=$(cat -- "$errfile")
}

# --- a branch in a real worktree, HEAD matching: exit 0 and the path on stdout -------

main=$(fresh isolated-main)
repo "$main"
tree=$(worktree "$main" ticket/one isolated-worker)
sha=$(git -C "$tree" rev-parse HEAD)

run "$main" ticket/one "$sha"
check $((status == 0 ? 0 : 1)) "a branch in a real worktree whose HEAD matches exits 0"
[ "$out" = "$tree" ]
check $? "the worktree path is on stdout and nothing else is"

# --- the branch is checked out in the main checkout: exit 1 -------------------------

sha=$(git -C "$main" rev-parse HEAD)

run "$main" main "$sha"
check $((status == 1 ? 0 : 1)) "a branch checked out in the main checkout exits 1"
[ -z "$out" ]
check $? "nothing is on stdout when the branch is in the main checkout"

# --- no worktree holds the branch: exit 2 -------------------------------------------

git -C "$main" branch unheld main || exit 1

run "$main" unheld "$sha"
check $((status == 2 ? 0 : 1)) "a branch no worktree holds exits 2"
[ -z "$out" ]
check $? "nothing is on stdout when no worktree holds the branch"

run "$main" never-created "$sha"
check $((status == 2 ? 0 : 1)) "a branch that does not exist exits 2"

# --- isolated, but HEAD is not the reported SHA: exit 3 -----------------------------

stale=$(git -C "$tree" rev-parse HEAD)
commit "$tree" two >/dev/null

run "$main" ticket/one "$stale"
check $((status == 3 ? 0 : 1)) "a real worktree whose HEAD is not the reported SHA exits 3"
[ -z "$out" ]
check $? "nothing is on stdout when HEAD is not the reported SHA"

run "$main" ticket/one "$(git -C "$tree" rev-parse HEAD)"
check $((status == 0 ? 0 : 1)) "the same worktree at the reported SHA exits 0"

# --- the check could not run: exit 4 ------------------------------------------------

sha=$(git -C "$tree" rev-parse HEAD)
plain=$(fresh outside-any-repository)

run "$plain" ticket/one "$sha"
check $((status == 4 ? 0 : 1)) "a subject that is not a git repository exits 4"
[ -n "$errout" ]
check $? "the reason a non-repository subject could not be checked is on stderr"
[ -z "$out" ]
check $? "nothing is on stdout when the subject is not a git repository"

run "$plain/does-not-exist" ticket/one "$sha"
check $((status == 4 ? 0 : 1)) "a subject directory that does not exist exits 4"

run "$main" ticket/one
check $((status == 4 ? 0 : 1)) "a missing SHA argument exits 4"
[ -n "$errout" ]
check $? "the reason a missing argument could not be checked is on stderr"
[ -z "$out" ]
check $? "nothing is on stdout when an argument is missing"

run "$main"
check $((status == 4 ? 0 : 1)) "a missing branch argument exits 4"

run "$main" '' "$sha"
check $((status == 4 ? 0 : 1)) "an empty branch argument exits 4"

run "$main" ticket/one ''
check $((status == 4 ? 0 : 1)) "an empty SHA argument exits 4"

# --- with no subject named, the subject is the working directory ---------------------

run_in "$main" ticket/one "$sha"
check $((status == 0 ? 0 : 1)) "run from the main checkout with no subject named exits 0"
[ "$out" = "$tree" ]
check $? "the worktree path is on stdout when the subject is the working directory"

run_in "$plain" ticket/one "$sha"
check $((status == 4 ? 0 : 1)) "run outside a git repository exits 4"

# --- a branch whose name is a prefix of another branch's name -----------------------
#
# The longer name is registered first, so a parse that matched refs/heads/<branch> as a
# prefix rather than exactly would answer with the wrong worktree here.

prefix_main=$(fresh prefix-main)
repo "$prefix_main"
long=$(worktree "$prefix_main" feature-two prefix-long)
short=$(worktree "$prefix_main" feature prefix-short)

run "$prefix_main" feature "$(git -C "$short" rev-parse HEAD)"
check $((status == 0 ? 0 : 1)) "a branch that is a prefix of another branch's name exits 0"
[ "$out" = "$short" ]
check $? "the prefix branch answers with its own worktree, not the longer branch's"

run "$prefix_main" feature-two "$(git -C "$long" rev-parse HEAD)"
check $((status == 0 ? 0 : 1)) "the longer branch exits 0"
[ "$out" = "$long" ]
check $? "the longer branch answers with its own worktree"

# --- a detached-HEAD worktree holds no branch ---------------------------------------
#
# The worktree is still there and still at the reported SHA. It holds no branch, so
# nothing in this repository holds the branch.

detached_main=$(fresh detached-main)
repo "$detached_main"
detached=$(worktree "$detached_main" ticket/detached detached-worker)
sha=$(git -C "$detached" rev-parse HEAD)
git -C "$detached" checkout --quiet --detach >/dev/null 2>&1 || exit 1

run "$detached_main" ticket/detached "$sha"
check $((status == 2 ? 0 : 1)) "a detached-HEAD worktree at the reported SHA exits 2"
[ -z "$out" ]
check $? "nothing is on stdout for a detached-HEAD worktree"

# --- the branch is checked out in a separate clone of the same repository -----------

clone_main=$(fresh clone-main)
repo "$clone_main"
git -C "$clone_main" branch cloned main || exit 1
clone=$(fresh clone-copy)
git clone --quiet "$clone_main" "$clone/copy" >/dev/null 2>&1 || exit 1
git -C "$clone/copy" checkout --quiet cloned || exit 1
sha=$(git -C "$clone/copy" rev-parse HEAD)

run "$clone_main" cloned "$sha"
check $((status == 2 ? 0 : 1)) "a branch checked out in a separate clone exits 2"
[ -z "$out" ]
check $? "nothing is on stdout for a branch held only by a separate clone"

printf '\n%s case(s), %s failure(s)\n' "$cases" "$failures"
[ "$failures" -eq 0 ]
