#!/usr/bin/env bash
#
# adapter-slot-completeness: this repository's own check. It carries no plugin-supplied
# header because the plugin does not ship it: it asserts on this plugin's packaging,
# which no consumer repository has, so it must never be mistaken for an installer orphan.
#
# Host knowledge is written in two kinds of place. The core enumerates the slots once, in
# slots.md, and every shipped adapter answers that enumeration for one host. The two are
# meant to be one list, and nothing but a check keeps them so: a slot added to the core
# alone leaves a blank nobody meets until setup time, and a heading an adapter invents
# answers a question the core never asked.
#
# The expected set is derived from the `### Slot N:` headings in slots.md and is never
# written here. Restating the seven inside this check would make it a second list, free to
# drift from the first, which is the exact failure the check exists to prevent. When the
# core gains slot eight, this check fails loudly against every adapter the same day.
#
# Headings are compared byte for byte. A near-miss spelling is the drift this check is for,
# so normalising case or whitespace before the comparison would hide it.
#
# A subject whose slots.md is missing or defines no slots exits 2 rather than passing every
# adapter against an empty expectation. So does a subject with no adapter file: a check
# that asserts nothing is worse than no check, and both are states of a tree, not findings
# about an adapter.
#
# Subject: GAUNTLET_SUBJECT, then the first argument, then the working directory.

set -uo pipefail

subject=${GAUNTLET_SUBJECT:-${1:-$PWD}}

if [ ! -d "$subject" ]; then
	printf 'adapter-slot-completeness: subject %s is not a directory.\n' "$subject" >&2
	exit 2
fi

slots_rel=plugins/devflow/skills/setup-devflow/references/slots.md
adapters_rel=plugins/devflow/adapters
slots=$subject/$slots_rel
adapters=$subject/$adapters_rel

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

# headings <file>: every `### Slot N: <name>` line, in file order, byte for byte.
headings() {
	sed -n 's/^\(### Slot [0-9][0-9]*:[[:space:]].*\)$/\1/p' -- "$1"
}

if [ ! -f "$slots" ]; then
	printf 'adapter-slot-completeness: %s is missing, so there is no enumeration to check against.\n' \
		"$slots_rel" >&2
	exit 2
fi

expected=()
while IFS= read -r line; do expected+=("$line"); done < <(headings "$slots")

if [ "${#expected[@]}" -eq 0 ]; then
	printf 'adapter-slot-completeness: %s defines no slots, so every adapter would pass against an empty expectation.\n' \
		"$slots_rel" >&2
	exit 2
fi

files=()
while IFS= read -r file; do files+=("$file"); done < <(find "$adapters" -type f 2>/dev/null | sort)

if [ "${#files[@]}" -eq 0 ]; then
	printf 'adapter-slot-completeness: no file under %s, so completeness is asserted about nothing.\n' \
		"$adapters_rel" >&2
	exit 2
fi

for file in "${files[@]}"; do
	rel=${file#"$subject"/}
	answered=()
	while IFS= read -r line; do answered+=("$line"); done < <(headings "$file")

	for want in "${expected[@]}"; do
		contains "$want" ${answered[@]+"${answered[@]}"} ||
			report "$rel" "does not answer '$want', which $slots_rel defines"
	done

	for got in ${answered[@]+"${answered[@]}"}; do
		contains "$got" "${expected[@]}" ||
			report "$rel" "answers '$got', which $slots_rel does not define"
	done
done

printf 'adapter-slot-completeness: %s slot(s) and %s adapter(s) checked, %s finding(s).\n' \
	"${#expected[@]}" "${#files[@]}" "$findings"
[ "$findings" -eq 0 ]
