#!/usr/bin/env bash
#
# marketplace-source-path: this repository's own check, so it carries no plugin-supplied
# header. A marketplace entry whose source does not resolve installs nothing, and the
# failure surfaces on a teammate's machine rather than here.
#
# A source is read as either a path string or an object carrying a path, because a
# marketplace entry may state it either way.
#
# A path is resolved against the directory holding the marketplace manifest's own root,
# which is this repository, because that is what a host does with a local source.
#
# Subject: GAUNTLET_SUBJECT, then the first argument, then the working directory.

set -uo pipefail

subject=${GAUNTLET_SUBJECT:-${1:-$PWD}}

if [ ! -d "$subject" ]; then
	printf 'marketplace-source-path: subject %s is not a directory.\n' "$subject" >&2
	exit 2
fi

findings=0
checked=0
report() { # report <file> <finding>
	printf '%s: %s\n' "$1" "$2"
	findings=$((findings + 1))
}

# Each line is the entry's name, a tab, and the path it claims. An entry whose source is
# neither a string nor an object carrying a path yields an empty path and is reported.
extract='
	.plugins[]?
	| [ (.name // "<unnamed>"),
	    ( .source
	      | if type == "string" then .
	        elif type == "object" then (.path // "")
	        else "" end ) ]
	| @tsv
'

for rel in .claude-plugin/marketplace.json; do
	file=$subject/$rel
	if [ ! -f "$file" ]; then
		report "$rel" 'the marketplace manifest is missing'
		continue
	fi
	if ! jq -e . -- "$file" >/dev/null 2>&1; then
		report "$rel" 'the marketplace manifest is not parseable JSON'
		continue
	fi
	if [ "$(jq -r '.plugins | if type == "array" then length else 0 end' -- "$file")" -eq 0 ]; then
		report "$rel" 'no plugin entries, so the marketplace publishes nothing'
		continue
	fi

	while IFS=$'\t' read -r name path; do
		checked=$((checked + 1))
		if [ -z "$path" ]; then
			report "$rel" "entry '$name' states no source path"
			continue
		fi
		case $path in
		/*) resolved=$path ;;
		*) resolved=$subject/$path ;;
		esac
		if [ -L "$resolved" ]; then
			report "$rel" "entry '$name' sources '$path', which is a symlink; the plugin tree travels as real directories"
		elif [ ! -d "$resolved" ]; then
			report "$rel" "entry '$name' sources '$path', which resolves to no directory"
		fi
	done < <(jq -r "$extract" -- "$file")
done

printf 'marketplace-source-path: %s entry/entries checked, %s finding(s).\n' "$checked" "$findings"
[ "$findings" -eq 0 ] && [ "$checked" -gt 0 ]
