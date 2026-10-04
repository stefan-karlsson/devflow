#!/usr/bin/env bash
#
# manifest-alignment: this repository's own check. It carries no plugin-supplied header
# because the plugin does not ship it: it asserts on this plugin's packaging, which no
# consumer repository has, so it must never be mistaken for an installer orphan.
#
# Two manifests describe one plugin, the marketplace and the plugin's own, and a third
# place records the same version: the stamp in docs/agents/workflow.json that the router
# compares when /develop is typed. Name, version, description and author must agree
# across both manifests, and the stamp must agree with them.
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

config=$subject/docs/agents/workflow.json
if [ ! -f "$config" ]; then
	report 'docs/agents/workflow.json' 'the configuration is missing, so the version stamp the router compares does not exist'
elif ! jq -e . -- "$config" >/dev/null 2>&1; then
	report 'docs/agents/workflow.json' 'the configuration is not parseable JSON'
else
	stamp=$(jq -r '.devflow.version // ""' -- "$config")
	version=$(jq -r '.version // ""' <<<"$reference")
	if [ -z "$stamp" ]; then
		report 'docs/agents/workflow.json' 'no version stamp, so an upgrade would be silent rather than loud'
	elif [ "$stamp" != "$version" ]; then
		report 'docs/agents/workflow.json' "the version stamp is '$stamp' but the manifests state '$version'"
	fi
fi

printf 'manifest-alignment: %s manifests and the version stamp checked, %s finding(s).\n' \
	"${#values[@]}" "$findings"
[ "$findings" -eq 0 ]
