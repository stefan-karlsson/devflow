#!/usr/bin/env bash
#
# Drives the dependency probe against fixture skill roots and asserts observable
# outcomes only: the exit code, and the subject each finding names. Never the wording,
# so the probe's prose can be rewritten without rewriting this file.
#
# Every case points the probe at fixture roots through DEVFLOW_SKILL_ROOTS, so no case
# reads the live machine and no case depends on what is installed on it.
#
# Subject: GAUNTLET_SUBJECT, falling back to the repository this file sits in.

set -uo pipefail

self_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
subject=${GAUNTLET_SUBJECT:-$(cd -- "$self_dir/.." && pwd -P)}
probe=$subject/plugins/devflow/scripts/scan-skill-environment.sh

# The upstream floor and the invocation split, written here independently of the probe
# so the two have to agree rather than share a list.
floor=d81f3a1
named=(to-spec to-tickets implement implement-spec retro setup-matt-pocock-skills)
loaded=(grilling domain-modeling prototype pr code-review)

work=$(mktemp -d) || exit 1
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

skill() { # skill <root> <directory> <name> <true|""> <body>
	local dir=$1/$2
	mkdir -p "$dir" || exit 1
	{
		printf -- '---\n'
		printf 'name: %s\n' "$3"
		printf 'description: a fixture skill called %s\n' "$3"
		[ -n "$4" ] && printf 'disable-model-invocation: %s\n' "$4"
		printf -- '---\n\n%s\n' "$5"
	} >"$dir/SKILL.md"
}

satisfied() { # satisfied <root>, an installation the probe should accept
	local root=$1 name
	for name in "${named[@]}"; do
		skill "$root" "$name" "$name" true "The router names this one."
	done
	for name in "${loaded[@]}"; do
		if [ "$name" = domain-modeling ]; then
			skill "$root" "$name" "$name" "" 'Write resolved terms into GLOSSARY.md as they land.'
		else
			skill "$root" "$name" "$name" "" "The router loads this one."
		fi
	done
}

run() { # run <root>..., captures stdout+stderr in $out and the exit code in $status
	local roots joined
	roots=("$@")
	joined=$(
		IFS=:
		printf '%s' "${roots[*]}"
	)
	out=$(DEVFLOW_SKILL_ROOTS=$joined "$probe" 2>&1)
	status=$?
}

said() { # said <text>, true when the captured output mentions it
	case $out in
	*"$1"*) return 0 ;;
	*) return 1 ;;
	esac
}

denied() { # denied <text>, true when the captured output does not mention it
	said "$1" && return 1
	return 0
}

# --- a satisfied installation is accepted -------------------------------------------

root=$(fresh satisfied)
satisfied "$root"

run "$root"
check $((status == 0 ? 0 : 1)) "a satisfied installation exits 0"

# The bare name is the frontmatter name, not the directory basename, because that is
# what a host resolves.
root=$(fresh renamed)
satisfied "$root"
rm -rf "$root/retro"
skill "$root" zz-not-the-name retro true "The router names this one."

run "$root"
check $((status == 0 ? 0 : 1)) "a required skill in a differently named directory is found by its frontmatter name"

# --- a missing required skill ---------------------------------------------------------

root=$(fresh missing)
satisfied "$root"
rm -rf "$root/retro"

run "$root"
check $((status != 0 ? 0 : 1)) "a missing required skill exits non-zero"
said "retro"
check $? "the missing required skill is named"
denied "$floor"
check $? "a missing required skill is not reported as a floor failure"

# --- an installation below the floor ---------------------------------------------------

root=$(fresh no-pr)
satisfied "$root"
rm -rf "$root/pr"

run "$root"
check $((status != 0 ? 0 : 1)) "an installation without the pr skill exits non-zero"
said "$floor"
check $? "the absent floor marker pr is reported against the floor"

root=$(fresh old-glossary)
satisfied "$root"
skill "$root" domain-modeling domain-modeling "" 'Write resolved terms into CONTEXT.md as they land.'

run "$root"
check $((status != 0 ? 0 : 1)) "a domain-modeling that still names CONTEXT.md exits non-zero"
said "$floor"
check $? "the stale glossary marker is reported against the floor"
said "domain-modeling"
check $? "the stale glossary marker names the skill"

# A domain-modeling that names the new file while still naming the old one is below the
# floor too: upstream's v1.3 skill mentions CONTEXT.md nowhere.
root=$(fresh both-glossaries)
satisfied "$root"
skill "$root" domain-modeling domain-modeling "" 'Write terms into GLOSSARY.md, formerly CONTEXT.md.'

run "$root"
check $((status != 0 ? 0 : 1)) "a domain-modeling that still mentions CONTEXT.md exits non-zero"
said "$floor"
check $? "a lingering CONTEXT.md is reported against the floor"

# And one that names no glossary file at all is not the v1.3 skill either.
root=$(fresh no-glossary)
satisfied "$root"
skill "$root" domain-modeling domain-modeling "" 'Write resolved terms down somewhere.'

run "$root"
check $((status != 0 ? 0 : 1)) "a domain-modeling that names no glossary file exits non-zero"
said "$floor"
check $? "a domain-modeling naming no glossary file is reported against the floor"

# --- the invocation key in the wrong place ---------------------------------------------

root=$(fresh key-gone)
satisfied "$root"
skill "$root" to-spec to-spec "" "The router names this one."

run "$root"
check $((status != 0 ? 0 : 1)) "a named skill whose disable-model-invocation key is gone exits non-zero"
said "to-spec"
check $? "the key finding names the skill"
said "disable-model-invocation"
check $? "the key finding names the key"

root=$(fresh key-added)
satisfied "$root"
skill "$root" grilling grilling true "The router loads this one."

run "$root"
check $((status != 0 ? 0 : 1)) "a loaded skill that has grown a disable-model-invocation key exits non-zero"
said "grilling"
check $? "the unexpected key finding names the skill"
said "disable-model-invocation"
check $? "the unexpected key finding names the key"

# --- two distinct real directories offering one bare name --------------------------------

first=$(fresh dup-first)
second=$(fresh dup-second)
satisfied "$first"
skill "$second" grilling grilling "" "A second, unrelated copy."

run "$first" "$second"
check $((status != 0 ? 0 : 1)) "the same bare name from two real directories exits non-zero"
said "$first/grilling"
check $? "the duplicate finding names the first path"
said "$second/grilling"
check $? "the duplicate finding names the second path"

# --- optional skills are not asserted ----------------------------------------------------

root=$(fresh optional)
satisfied "$root"
skill "$root" triage triage true "An optional skill that happens to be installed."

run "$root"
check $((status == 0 ? 0 : 1)) "an installation missing every other optional skill exits 0"

# --- the supported install layout: one real directory reached through two roots ----------
#
# This is the regression guard for the live machine. The supported install route,
# npx skills@latest add mattpocock/skills -a claude-code, puts the skills in
# ~/.agents/skills and symlinks ~/.claude/skills/<name> at them, so every correctly
# installed skill is reachable through two roots. A duplicate rule that compared roots
# rather than real directories would call all eleven doubled and refuse on a machine
# that is right.

real=$(fresh symlink-real)
linked=$(fresh symlink-linked)
satisfied "$real"
for name in "${named[@]}" "${loaded[@]}"; do
	ln -s "$real/$name" "$linked/$name"
done

run "$real" "$linked"
check $((status == 0 ? 0 : 1)) "one real directory reached through two roots exits 0"
denied "$linked"
check $? "the symlinked root is not reported as a second copy"

printf '\n%s case(s), %s failure(s)\n' "$cases" "$failures"
[ "$failures" -eq 0 ]
