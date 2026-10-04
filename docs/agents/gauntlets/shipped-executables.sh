#!/usr/bin/env bash
#
# shipped-executables: this repository's own check, so it carries no plugin-supplied
# header. Every file the plugin ships to be run is a non-empty regular file carrying the
# executable bit.
#
# Two directories are walked, and both hold the same class of file:
#
#   plugins/devflow/scripts/   the plugin's own scripts, invoked by the skills.
#   plugins/devflow/payload/   everything the installer copies out, which is the two
#                              gauntlet checks and the ADF converter. The installer
#                              refuses to copy a payload file that is empty, a symlink
#                              or not executable, so a lost bit here does not fail
#                              where it happened: it fails on the next person's setup.
#
# A directory that has gone missing is a finding, not a silent pass: an empty walk would
# otherwise report success over nothing at all.
#
# Subject: GAUNTLET_SUBJECT, then the first argument, then the working directory.

set -uo pipefail

subject=${GAUNTLET_SUBJECT:-${1:-$PWD}}

if [ ! -d "$subject" ]; then
	printf 'shipped-executables: subject %s is not a directory.\n' "$subject" >&2
	exit 2
fi

roots=(
	plugins/devflow/scripts
	plugins/devflow/payload
)

findings=0
checked=0
report() { # report <path> <finding>
	printf '%s: %s\n' "$1" "$2"
	findings=$((findings + 1))
}

for root in "${roots[@]}"; do
	dir=$subject/$root
	if [ ! -d "$dir" ]; then
		report "$root" 'the directory is missing, so nothing was checked where files are shipped from'
		continue
	fi

	found=0
	while IFS= read -r -d '' path; do
		rel=${path#"$subject"/}
		found=$((found + 1))
		checked=$((checked + 1))
		if [ -L "$path" ]; then
			report "$rel" 'is a symlink; a shipped file travels as a real file and a link does not survive being copied'
			continue
		fi
		if [ ! -f "$path" ]; then
			report "$rel" 'is not a regular file'
			continue
		fi
		if [ ! -s "$path" ]; then
			report "$rel" 'is empty; a command declared but unrunnable is a failure of the repository that declared it'
			continue
		fi
		if [ ! -x "$path" ]; then
			report "$rel" 'has no executable bit, and a config names it as a command'
		fi
	done < <(find "$dir" -mindepth 1 \( -type f -o -type l \) -print0 2>/dev/null | sort -z)

	if [ "$found" -eq 0 ]; then
		report "$root" 'holds no files'
	fi
done

printf 'shipped-executables: %s shipped file(s) checked, %s finding(s).\n' "$checked" "$findings"
[ "$findings" -eq 0 ]
