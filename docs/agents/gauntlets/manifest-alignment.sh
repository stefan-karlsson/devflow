#!/usr/bin/env bash
#
# manifest-alignment: this repository's own check. It carries no plugin-supplied header
# because the plugin does not ship it: it asserts on this plugin's packaging, which no
# consumer repository has, so it must never be mistaken for an installer orphan.
#
# Two manifests describe one plugin, the marketplace and the plugin's own, and two further
# kinds of place record the same version: the stamp in docs/agents/workflow.json that the
# router compares when /develop is typed, and a literal stamp in the body of every skill
# that compares a recorded version against the running one. Name, version, description and
# author must agree across both manifests, and every stamp must agree with them.
#
# A body stamp exists because both sides of that comparison have to come from this plugin's
# own shipped text. A version read from a recorded plugin root would compare a stale install
# against itself and agree.
#
# The stamped skills are derived by reading the bodies and are never listed here: a stamp is
# a line of the shape **devflow version: <version>** in a markdown file under
# plugins/devflow/skills/. A fourth skill that gains one is checked the day it gains it, and
# a tree where that shape matches nothing at all is a finding rather than a silent pass.
#
# The marketplace manifest must declare exactly one plugin. A second entry is not drift
# this check can quietly tolerate: it would make "the manifests agree" a claim about an
# entry nobody chose.
#
# Subject: GAUNTLET_SUBJECT, then the first argument, then the working directory.

set -uo pipefail

subject=${GAUNTLET_SUBJECT:-${1:-$PWD}}

if [ ! -d "$subject" ]; then
	printf 'manifest-alignment: subject %s is not a directory.\n' "$subject" >&2
	exit 2
fi

findings=0
report() { # report <file> <finding>
	printf '%s: %s\n' "$1" "$2"
	findings=$((findings + 1))
}

# The identity every manifest states, canonicalised so key order cannot read as drift.
identity='{name: .name, version: .version, description: .description, author: .author}'

names=()
values=()

# read_identity <relative path> <jq filter reaching the object that states the identity>
# Appends to names and values on success. Reports and appends nothing on failure, so a
# missing manifest is one finding rather than a cascade of disagreements.
read_identity() {
	local rel=$1 filter=$2 file=$subject/$1 value
	if [ ! -f "$file" ]; then
		report "$rel" 'the manifest is missing'
		return 1
	fi
	if ! jq -e . -- "$file" >/dev/null 2>&1; then
		report "$rel" 'the manifest is not parseable JSON'
		return 1
	fi
	if ! value=$(jq -cS "$filter | $identity" -- "$file" 2>/dev/null); then
		report "$rel" "no plugin identity is reachable at $filter"
		return 1
	fi
	names+=("$rel")
	values+=("$value")
}

# read_marketplace <relative path>: a marketplace states the identity inside its one
# plugin entry, so the entry count is checked before the entry is read.
read_marketplace() {
	local rel=$1 file=$subject/$1 count
	if [ ! -f "$file" ]; then
		report "$rel" 'the manifest is missing'
		return 1
	fi
	if ! jq -e . -- "$file" >/dev/null 2>&1; then
		report "$rel" 'the manifest is not parseable JSON'
		return 1
	fi
	count=$(jq -r '.plugins | if type == "array" then length else "not-an-array" end' -- "$file")
	if [ "$count" != 1 ]; then
		report "$rel" "declares $count plugin entries; this marketplace exists to publish exactly one"
		return 1
	fi
	read_identity "$rel" '.plugins[0]'
}

read_marketplace '.claude-plugin/marketplace.json'
read_identity 'plugins/devflow/.claude-plugin/plugin.json' '.'

expected=2
if [ "${#values[@]}" -lt "$expected" ]; then
	printf 'manifest-alignment: %s of %s manifests could be read, %s finding(s).\n' \
		"${#values[@]}" "$expected" "$findings"
	exit 1
fi

# The first manifest is the reference only so that a disagreement has something to be
# reported against. Both are equally authoritative, and a mismatch names both sides.
reference=${values[0]}
for i in "${!values[@]}"; do
	if [ "${values[$i]}" != "$reference" ]; then
		report "${names[$i]}" "states ${values[$i]} but ${names[0]} states $reference"
	fi
done

for field in name version description author; do
	if [ "$(jq -r --arg f "$field" '.[$f] // "" | tostring' <<<"$reference")" = '' ]; then
		report "${names[0]}" "$field is absent or empty, so agreeing about it proves nothing"
	fi
done

version=$(jq -r '.version // ""' <<<"$reference")

config=$subject/docs/agents/workflow.json
if [ ! -f "$config" ]; then
	report 'docs/agents/workflow.json' 'the configuration is missing, so the version stamp the router compares does not exist'
elif ! jq -e . -- "$config" >/dev/null 2>&1; then
	report 'docs/agents/workflow.json' 'the configuration is not parseable JSON'
else
	stamp=$(jq -r '.devflow.version // ""' -- "$config")
	if [ -z "$stamp" ]; then
		report 'docs/agents/workflow.json' 'no version stamp, so an upgrade would be silent rather than loud'
	elif [ "$stamp" != "$version" ]; then
		report 'docs/agents/workflow.json' "the version stamp is '$stamp' but the manifests state '$version'"
	fi
fi

# The body stamps, found rather than listed. Reference files are read alongside SKILL.md,
# because a version stated in a file a skill loads is a version a release has to move too.
stamps=0
skills=$subject/plugins/devflow/skills
if [ ! -d "$skills" ]; then
	report 'plugins/devflow/skills' 'the directory is missing, so no body stamp can be read'
else
	while IFS= read -r file; do
		rel=${file#"$subject"/}
		# Every stamp line in the body, so a second one cannot hide behind the first.
		while IFS= read -r stated; do
			stamps=$((stamps + 1))
			if [ -z "$stated" ]; then
				report "$rel" 'carries a version stamp with no version in it'
			elif [ "$stated" != "$version" ]; then
				report "$rel" "the body stamp is '$stated' but the manifests state '$version'"
			fi
		done < <(sed -n 's/^\*\*devflow version:[[:space:]]*\([^*]*\)\*\*.*/\1/p' -- "$file")
	done < <(find "$skills" -type f -name '*.md' | sort)
	if [ "$stamps" -eq 0 ]; then
		report 'plugins/devflow/skills' 'no body carries a version stamp, so this check asserts nothing about them'
	fi
fi

printf 'manifest-alignment: %s manifests, the configuration stamp and %s body stamp(s) checked, %s finding(s).\n' \
	"${#values[@]}" "$stamps" "$findings"
[ "$findings" -eq 0 ]
