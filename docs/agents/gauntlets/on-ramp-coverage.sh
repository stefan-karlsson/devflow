#!/usr/bin/env bash
#
# on-ramp-coverage: this repository's own check. It carries no plugin-supplied header
# because the plugin does not ship it: it asserts on this plugin's packaging, which no
# consumer repository has, so it must never be mistaken for an installer orphan.
#
# The router's on-ramp table names skills the flow routes to instead of starting an
# effort, and the dependency probe carries two lists of skill names: the ones it requires
# and the ones it considered and deliberately did not. Every name in the table must appear
# in one of those two lists.
#
# The failure this catches is a row added to the table and nowhere else. The probe's
# duplicate rule walks required plus optional and no further, so a name outside both is a
# name no part of devflow has an opinion about: it is never reported absent, which is the
# intended answer, but it is also never reported doubled, and a doubled on-ramp routes the
# engineer to whichever copy the host picked. Listing the name as optional costs one line
# and buys the duplicate rule. Nothing else here asserts that the two files agree, because
# the two are prose and shell and no reader of either walks the other.
#
# One direction only, and the asymmetry is the point. A table name missing from both lists
# is a fault. A list name missing from the table is not: the optional list is a record of
# what was considered, and it holds names that were never on-ramps.
#
# It asserts membership and nothing about installation. Whether any of these skills is on
# this machine is the probe's question, asked at run time against real roots, and a green
# run here says only that the two files name one set.
#
# The table is located by its delimiter row rather than by a range, because the heading is
# followed by prose and the table is followed by more of it. The same reasoning is written
# out at greater length in adapter-readme-agreement.sh, which parses a table under a
# heading that also carries prose.
#
# Subject: GAUNTLET_SUBJECT, then the first argument, then the working directory.

set -uo pipefail

subject=${GAUNTLET_SUBJECT:-${1:-$PWD}}

if [ ! -d "$subject" ]; then
	printf 'on-ramp-coverage: subject %s is not a directory.\n' "$subject" >&2
	exit 2
fi

router_rel=plugins/devflow/skills/develop/SKILL.md
probe_rel=plugins/devflow/scripts/scan-skill-environment.sh
router=$subject/$router_rel
probe=$subject/$probe_rel

findings=0
report() { # report <file> <finding>
	printf '%s: %s\n' "$1" "$2"
	findings=$((findings + 1))
}

# contains <needle> <item>...: true when one of the items is exactly the needle.
contains() {
	local needle=$1 item
	shift
	for item in "$@"; do
		[ "$item" = "$needle" ] && return 0
	done
	return 1
}

for pair in "$router_rel:$router" "$probe_rel:$probe"; do
	if [ ! -f "${pair#*:}" ]; then
		printf 'on-ramp-coverage: %s is missing, so the two name sets cannot be compared.\n' \
			"${pair%%:*}" >&2
		exit 2
	fi
done

# The on-ramp names. awk walks to the `## On-ramps` heading, then to the two-column
# delimiter, then prints the second cell of every row until the first line that is not
# one. A row whose second cell is not a backticked name is reported rather than skipped,
# and a heading that reaches the next `##` without a delimiter is a table that cannot be
# read at all.
onramps=()
while IFS= read -r name; do onramps+=("$name"); done < <(awk -F'|' '
	/^## On-ramps[[:space:]]*$/ && !seen { seen = 1; state = "seeking"; next }
	state == "seeking" {
		if ($0 ~ /^\|[[:space:]]*---[[:space:]]*\|[[:space:]]*---[[:space:]]*\|[[:space:]]*$/) {
			state = "rows"
		} else if ($0 ~ /^##[[:space:]]/) {
			state = "broken"
		}
		next
	}
	state == "rows" {
		if ($0 !~ /^\|/) { state = "done"; next }
		cell = $3
		gsub(/^[[:space:]]+|[[:space:]]+$/, "", cell)
		if (cell ~ /^`[a-z][a-z0-9-]*`$/) {
			gsub(/`/, "", cell)
			print cell
		} else {
			print "\x01row " NR
		}
		next
	}
	END {
		if (!seen) print "\x01no-heading"
		else if (state == "seeking" || state == "broken") print "\x01broken"
	}
' <"$router")

structural=0
names=()
for name in ${onramps[@]+"${onramps[@]}"}; do
	case $name in
	$'\x01'no-heading)
		printf 'on-ramp-coverage: %s carries no "## On-ramps" heading, so there is no table to check.\n' \
			"$router_rel" >&2
		exit 2
		;;
	$'\x01'broken)
		report "$router_rel" 'the table under "## On-ramps" is not anchored by a two-column delimiter row, so its rows cannot be read'
		structural=1
		;;
	$'\x01'row*)
		report "$router_rel" "${name#$'\x01'} under \"## On-ramps\" does not name a skill in its second cell as a backticked name"
		structural=1
		;;
	*) names+=("$name") ;;
	esac
done

if [ "$structural" -eq 0 ] && [ "${#names[@]}" -eq 0 ]; then
	printf 'on-ramp-coverage: the table under "## On-ramps" in %s names no skill, so coverage would hold over an empty set.\n' \
		"$router_rel" >&2
	exit 2
fi

# The probe's two lists, read out of the array literals that declare them. A comment on an
# array line is stripped, so a name is never read out of one.
probe_names=()
while IFS= read -r name; do probe_names+=("$name"); done < <(awk '
	/^(required_skills|optional_skills)=\(/ { inside = 1; next }
	inside && /^\)/ { inside = 0; next }
	inside { sub(/#.*/, ""); print }
' <"$probe" | tr -s '[:space:]' '\n' | grep -v '^$')

if [ "${#probe_names[@]}" -eq 0 ]; then
	printf 'on-ramp-coverage: %s declares no required_skills or optional_skills entries, so membership would hold over an empty set.\n' \
		"$probe_rel" >&2
	exit 2
fi

if [ "$structural" -eq 0 ]; then
	for name in "${names[@]}"; do
		contains "$name" "${probe_names[@]}" ||
			report "$router_rel" "the on-ramp table routes to '$name' but $probe_rel lists it as neither required nor optional, so the probe's duplicate rule does not cover it"
	done
fi

printf 'on-ramp-coverage: %s on-ramp(s) checked against %s probe name(s), %s finding(s).\n' \
	"${#names[@]}" "${#probe_names[@]}" "$findings"
[ "$findings" -eq 0 ]
