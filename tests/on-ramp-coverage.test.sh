#!/usr/bin/env bash
#
# Drives on-ramp-coverage against fixture trees built in a temporary directory, each
# holding a router SKILL.md with an on-ramp table and a probe script declaring the two
# name arrays. Asserts observable outcomes only: the exit code and the file named in the
# output. Never the exact wording, so the check's prose can be rewritten without
# rewriting this file.
#
# The fixtures name skills alpha-skill, beta-skill and gamma-skill rather than the six
# the real table routes to. A suite that fed the check the real names could not tell a
# check that reads both files from a check that carries either list inside it.
#
# Subject: GAUNTLET_SUBJECT, falling back to the repository this file sits in.

set -uo pipefail

self_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
subject=${GAUNTLET_SUBJECT:-$(cd -- "$self_dir/.." && pwd -P)}
coverage=$subject/docs/agents/gauntlets/on-ramp-coverage.sh

work=$(mktemp -d) || exit 1
work=$(cd -- "$work" && pwd -P)
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

fixture() { # fixture <label>, prints a new empty fixture root, real path resolved
	local d
	d=$(mktemp -d "$work/$1.XXXXXX") || exit 1
	(cd -- "$d" && pwd -P)
}

# router <root> <body>: writes the router skill with that body after its on-ramp heading.
router() {
	local root=$1 body=$2 file
	file=$root/plugins/devflow/skills/develop/SKILL.md
	mkdir -p -- "$(dirname -- "$file")" || exit 1
	{
		printf '# Develop\n\nOne command to remember.\n\n'
		printf '%s' "$body"
		printf '\n## After\n\nProse that follows the section.\n'
	} >"$file" || exit 1
}

# table <name>...: the on-ramp section as the router really writes it, heading, prose,
# a two-column table routing to those names, and prose after it.
table() {
	local name
	printf '## On-ramps\n\nNot everything that arrives is an effort.\n\n'
	printf '| What arrived | Whose it is |\n| --- | --- |\n'
	for name in "$@"; do
		printf '| Something that is %s shaped | `%s` |\n' "$name" "$name"
	done
	printf '\nNaming one is routing.\n\n'
}

# probe <root> <required-csv> <optional-csv>: writes a probe declaring those two arrays,
# each split across two lines, with a comment line inside one of them.
probe() {
	local root=$1 file
	file=$root/plugins/devflow/scripts/scan-skill-environment.sh
	mkdir -p -- "$(dirname -- "$file")" || exit 1
	{
		printf '#!/usr/bin/env bash\n#\n# A probe. gamma-skill appears in this comment only.\n\n'
		printf 'required_skills=(\n'
		[ -n "$2" ] && printf '\t%s\n' "${2//,/ }"
		printf ')\n\n# optional_skills: considered and not required.\noptional_skills=(\n'
		[ -n "$3" ] && printf '\t%s\n' "${3//,/ }"
		printf '\t# a comment naming delta-skill inside the array\n)\n\nexit 0\n'
	} >"$file" || exit 1
	chmod +x -- "$file" || exit 1
}

run() { # run <root>, prints output and returns the check's exit code
	GAUNTLET_SUBJECT=$1 "$coverage" 2>&1
}

# Covered, each name reached through a different list.
root=$(fixture covered)
router "$root" "$(table alpha-skill beta-skill)"
probe "$root" alpha-skill beta-skill
out=$(run "$root")
status=$?
check "$([ "$status" -eq 0 ] && echo 0 || echo 1)" 'a table whose every name is required or optional passes'
check "$(grep -q '2 on-ramp(s) checked' <<<"$out" && echo 0 || echo 1)" 'the pass counts the on-ramps it checked'

# Covered through the required list alone, and through the optional list alone.
root=$(fixture required-only)
router "$root" "$(table alpha-skill)"
probe "$root" alpha-skill ''
run "$root" >/dev/null
check "$([ $? -eq 0 ] && echo 0 || echo 1)" 'a name in the required list alone passes'

root=$(fixture optional-only)
router "$root" "$(table beta-skill)"
probe "$root" '' beta-skill
run "$root" >/dev/null
check "$([ $? -eq 0 ] && echo 0 || echo 1)" 'a name in the optional list alone passes'

# One name in neither list. The name appears in the probe's comments, which must not
# count as a declaration.
root=$(fixture uncovered)
router "$root" "$(table alpha-skill gamma-skill)"
probe "$root" alpha-skill beta-skill
out=$(run "$root")
status=$?
check "$([ "$status" -eq 1 ] && echo 0 || echo 1)" 'a name in neither list fails'
check "$(grep -q 'gamma-skill' <<<"$out" && echo 0 || echo 1)" 'the finding names the uncovered skill'
check "$(grep -q '1 finding(s)' <<<"$out" && echo 0 || echo 1)" 'the covered name beside it is not reported'

# A name declared only inside a comment within an array is not declared.
root=$(fixture comment-only)
router "$root" "$(table delta-skill)"
probe "$root" alpha-skill beta-skill
run "$root" >/dev/null
check "$([ $? -eq 1 ] && echo 0 || echo 1)" 'a name appearing only in a comment inside an array fails'

# A row whose second cell is not a backticked name.
root=$(fixture unreadable-row)
router "$root" "$(printf '## On-ramps\n\nProse.\n\n| What arrived | Whose it is |\n| --- | --- |\n| Something broke | the diagnosing skill |\n\nAfter.\n\n')"
probe "$root" alpha-skill beta-skill
out=$(run "$root")
status=$?
check "$([ "$status" -eq 1 ] && echo 0 || echo 1)" 'a row not naming a backticked skill fails'
check "$(grep -q 'SKILL.md' <<<"$out" && echo 0 || echo 1)" 'the finding names the router file'

# No heading at all: the check cannot assert, rather than asserting over nothing.
root=$(fixture no-heading)
router "$root" "$(printf '## Something else\n\nNo on-ramps here.\n\n')"
probe "$root" alpha-skill beta-skill
run "$root" >/dev/null 2>&1
check "$([ $? -eq 2 ] && echo 0 || echo 1)" 'a router with no on-ramp heading cannot assert'

# A heading reaching the next one without a delimiter row.
root=$(fixture no-delimiter)
router "$root" "$(printf '## On-ramps\n\nProse and no table.\n\n')"
probe "$root" alpha-skill beta-skill
run "$root" >/dev/null
check "$([ $? -eq 1 ] && echo 0 || echo 1)" 'an on-ramp section with no table is reported'

# A delimiter with no rows under it.
root=$(fixture empty-table)
router "$root" "$(printf '## On-ramps\n\nProse.\n\n| What arrived | Whose it is |\n| --- | --- |\n\nAfter.\n\n')"
probe "$root" alpha-skill beta-skill
run "$root" >/dev/null 2>&1
check "$([ $? -eq 2 ] && echo 0 || echo 1)" 'a table naming no skill cannot assert'

# Both arrays empty: membership would hold over an empty set.
root=$(fixture empty-probe)
router "$root" "$(table alpha-skill)"
probe "$root" '' ''
run "$root" >/dev/null 2>&1
check "$([ $? -eq 2 ] && echo 0 || echo 1)" 'a probe declaring no names cannot assert'

# Either file missing, and a subject that is not a directory.
root=$(fixture no-router)
probe "$root" alpha-skill beta-skill
run "$root" >/dev/null 2>&1
check "$([ $? -eq 2 ] && echo 0 || echo 1)" 'a missing router cannot assert'

root=$(fixture no-probe)
router "$root" "$(table alpha-skill)"
run "$root" >/dev/null 2>&1
check "$([ $? -eq 2 ] && echo 0 || echo 1)" 'a missing probe cannot assert'

run "$work/not-a-directory" >/dev/null 2>&1
check "$([ $? -eq 2 ] && echo 0 || echo 1)" 'a subject that is not a directory cannot assert'

printf 'on-ramp-coverage.test: %s case(s), %s failure(s).\n' "$cases" "$failures"
[ "$failures" -eq 0 ]
