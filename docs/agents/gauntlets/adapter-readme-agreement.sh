#!/usr/bin/env bash
#
# adapter-readme-agreement: this repository's own check. It carries no plugin-supplied
# header because the plugin does not ship it: it asserts on this plugin's packaging,
# which no consumer repository has, so it must never be mistaken for an installer orphan.
#
# A verified host is named in two places: a file under plugins/devflow/adapters/ carrying
# its answers, and a row in the README's host table telling a reader the host is verified
# and against which release. Those two sets must be the same set, in both directions. An
# adapter the table omits is a host nobody can discover; a row with no adapter behind it
# is a promise with no answers. With the check in place a host joins or leaves in one act
# rather than two.
#
# The table is located by its rows, not by a range. The `## Hosts` section continues past
# the table with prose and a `### <host>` subsection holding install commands, so slicing
# from heading to heading would read slugs out of that prose. A data row's first cell is a
# backticked slug, and the `###` subheading carries a display name rather than a slug, so
# neither is mistaken for the other.
#
# The shape asserted after the heading is one blank line, a header row and a three-column
# delimiter. The delimiter is what actually anchors the table: a mutation pass over the
# suite found that dropping the blank-line requirement changes no outcome, because the
# parse then shifts by one and the delimiter rejects the row it lands on. The blank line is
# asserted because it is the contract the host table was written to, not because it is the
# thing keeping a wrong table out. Anyone relaxing the delimiter should know they are
# removing the anchor and not a redundant second opinion.
#
# Subject: GAUNTLET_SUBJECT, then the first argument, then the working directory.

set -uo pipefail

subject=${GAUNTLET_SUBJECT:-${1:-$PWD}}

if [ ! -d "$subject" ]; then
	printf 'adapter-readme-agreement: subject %s is not a directory.\n' "$subject" >&2
	exit 2
fi

adapters_rel=plugins/devflow/adapters
readme_rel=README.md
adapters=$subject/$adapters_rel
readme=$subject/$readme_rel

findings=0
report() { # report <file> <finding>
	printf '%s: %s\n' "$1" "$2"
	findings=$((findings + 1))
}

# contains <needle> <item>...: true when one of the items is exactly the needle. Both
# directions of the comparison below run through it, so the membership rule is written
# once rather than once per direction.
contains() {
	local needle=$1 item
	shift
	for item in "$@"; do
		[ "$item" = "$needle" ] && return 0
	done
	return 1
}

# The adapters. A slug is the file's path under adapters/ with a trailing .md removed, so
# a file that is not an adapter answers to a slug the table will not name, and is
# reported rather than skipped.
shipped=()
while IFS= read -r file; do
	slug=${file#"$adapters"/}
	shipped+=("${slug%.md}")
done < <(find "$adapters" -type f 2>/dev/null | sort)

if [ "${#shipped[@]}" -eq 0 ]; then
	printf 'adapter-readme-agreement: no file under %s, so agreement is asserted about nothing.\n' \
		"$adapters_rel" >&2
	exit 2
fi

if [ ! -f "$readme" ]; then
	printf 'adapter-readme-agreement: %s is missing, so there is no host table to agree with.\n' \
		"$readme_rel" >&2
	exit 2
fi

# The table. awk walks to the `## Hosts` heading, steps over the one blank line and the
# header row, requires the three-column delimiter, and then prints the slug out of every
# row until the first line that is not one.
listed=()
while IFS= read -r slug; do listed+=("$slug"); done < <(awk '
	/^## Hosts[[:space:]]*$/ && !seen { seen = 1; state = "blank"; next }
	state == "blank"  { state = ($0 == "" ? "header" : "broken"); next }
	state == "header" { state = ($0 ~ /^\|/ ? "delimiter" : "broken"); next }
	state == "delimiter" {
		state = ($0 ~ /^\|[[:space:]]*---[[:space:]]*\|[[:space:]]*---[[:space:]]*\|[[:space:]]*---[[:space:]]*\|[[:space:]]*$/ ? "rows" : "broken")
		next
	}
	state == "rows" {
		if ($0 !~ /^\|/) { state = "done"; next }
		if (match($0, /^\|[[:space:]]*`[a-z-]+`/)) {
			slug = substr($0, RSTART, RLENGTH)
			sub(/^\|[[:space:]]*`/, "", slug)
			sub(/`$/, "", slug)
			print slug
		} else {
			print "\x01row " NR
		}
		next
	}
	END { if (!seen) print "\x01no-heading"; else if (state == "broken") print "\x01broken" }
' <"$readme")

structural=0
rows=()
for slug in ${listed[@]+"${listed[@]}"}; do
	case $slug in
	$'\x01'no-heading)
		printf 'adapter-readme-agreement: %s carries no "## Hosts" heading, so there is no host table to agree with.\n' \
			"$readme_rel" >&2
		exit 2
		;;
	$'\x01'broken)
		report "$readme_rel" 'the host table does not follow "## Hosts" as one blank line, a header row and a three-column delimiter, so its rows cannot be read'
		structural=1
		;;
	$'\x01'row*)
		report "$readme_rel" "${slug#$'\x01'} under \"## Hosts\" does not begin with a backticked slug, so the host it names cannot be read"
		structural=1
		;;
	*) rows+=("$slug") ;;
	esac
done

# A table whose shape could not be read would otherwise report every shipped adapter as
# unnamed, which is one fault told many times.
if [ "$structural" -eq 0 ]; then
	if [ "${#rows[@]}" -eq 0 ]; then
		report "$readme_rel" 'the host table under "## Hosts" names no host, so agreement would hold over an empty set'
	fi

	for slug in "${shipped[@]}"; do
		contains "$slug" ${rows[@]+"${rows[@]}"} ||
			report "$adapters_rel/$slug.md" "is shipped but $readme_rel's host table does not name '$slug'"
	done

	for named in ${rows[@]+"${rows[@]}"}; do
		contains "$named" "${shipped[@]}" ||
			report "$readme_rel" "the host table names '$named' but $adapters_rel holds no adapter for it"
	done
fi

printf 'adapter-readme-agreement: %s adapter(s) and %s host row(s) checked, %s finding(s).\n' \
	"${#shipped[@]}" "${#rows[@]}" "$findings"
[ "$findings" -eq 0 ]
