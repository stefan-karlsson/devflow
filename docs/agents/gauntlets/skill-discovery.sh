#!/usr/bin/env bash
#
# skill-discovery: this repository's own check, so it carries no plugin-supplied header. It
# asserts on this plugin's packaging, which no consumer repository has, and must never be
# mistaken for an installer orphan.
#
# Claude Code discovers `skills/<name>/SKILL.md` one level under the plugin root with no
# manifest entry. A skill placed anywhere else is reached only by a manifest entry naming
# the directory holding it, and a skill reached by neither registers nowhere: no host
# refuses it, no check downstream reads it, and the capability is simply absent. That is a
# silent failure, so it is the one this check exists to make loud.
#
# Two assertions, which together say the default scan is the whole story:
#
#   the manifest declares no skills key, so nothing is scanned in addition to the default
#   every SKILL.md sits exactly one level under skills/, where the default scan reaches it
#
# The first keeps the second meaningful. An array could make a misplaced skill reachable,
# and then this check would be asserting a layout the plugin no longer depends on. Adding
# a skills key is a packaging decision, not a fix for a misplaced directory, so it fails
# here and is argued for on its own terms.
#
# This check walks whatever sits under skills/ and never names a skill, so adding or
# removing one of the six the plugin ships needs no edit here. Enumerating them would make
# this a fixed-set check, which the specification excludes on purpose and which would
# need an edit every time a skill is added.
#
# Subject: GAUNTLET_SUBJECT, then the first argument, then the working directory.

set -uo pipefail

subject=${GAUNTLET_SUBJECT:-${1:-$PWD}}

if [ ! -d "$subject" ]; then
	printf 'skill-discovery: subject %s is not a directory.\n' "$subject" >&2
	exit 2
fi

plugin_rel=plugins/devflow
plugin=$subject/$plugin_rel
manifest_rel=$plugin_rel/.claude-plugin/plugin.json
manifest=$subject/$manifest_rel

findings=0
report() { # report <file> <finding>
	printf '%s: %s\n' "$1" "$2"
	findings=$((findings + 1))
}

if [ ! -d "$plugin" ]; then
	printf 'skill-discovery: %s is not a directory, so there is no plugin to check.\n' "$plugin_rel" >&2
	exit 2
fi
if [ ! -f "$manifest" ]; then
	printf 'skill-discovery: %s is missing.\n' "$manifest_rel" >&2
	exit 2
fi
if ! jq -e . -- "$manifest" >/dev/null 2>&1; then
	printf 'skill-discovery: %s is not parseable JSON.\n' "$manifest_rel" >&2
	exit 2
fi

# The manifest. A skills key of any shape is reported, including an empty array: the key
# is the claim that something beyond the default scan is wanted, and nothing here is.
if [ "$(jq -r 'has("skills")' -- "$manifest")" = true ]; then
	report "$manifest_rel" 'a skills key is declared; the default skills/ scan reaches every skill this plugin ships, so nothing is scanned in addition to it'
fi

# The tree. A skill directory is one holding a SKILL.md, because that file is what a host
# registers. Its path relative to the plugin root must be exactly skills/<name>/SKILL.md.
# A glob matches a separator like any other character, so depth is judged by stripping the
# prefix and the file name and asking whether a separator survives in between.
checked=0
while IFS= read -r file; do
	rel=${file#"$plugin"/}
	checked=$((checked + 1))
	case $rel in
	skills/*/SKILL.md)
		name=${rel#skills/}
		name=${name%/SKILL.md}
		case $name in
		*/*)
			report "$plugin_rel/$rel" 'is nested below skills/<name>/, which the default scan does not descend into, so the skill registers nowhere'
			;;
		esac
		;;
	skills/SKILL.md)
		report "$plugin_rel/$rel" 'sits in skills/ itself rather than in a directory under it, and the scan reads the immediate child directories, so the skill registers nowhere'
		;;
	*)
		report "$plugin_rel/$rel" 'is outside skills/, which the default scan does not read, so the skill registers nowhere'
		;;
	esac
done < <(find "$plugin" -type f -name SKILL.md 2>/dev/null | sort)

if [ "$checked" -eq 0 ]; then
	printf 'skill-discovery: no SKILL.md found under %s, so discovery is asserted about nothing.\n' \
		"$plugin_rel" >&2
	exit 2
fi

printf 'skill-discovery: the manifest and %s skill file(s) checked, %s finding(s).\n' \
	"$checked" "$findings"
[ "$findings" -eq 0 ]
