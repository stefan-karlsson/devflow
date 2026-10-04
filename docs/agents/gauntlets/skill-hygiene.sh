#!/usr/bin/env bash
#
# devflow plugin-supplied file. The devflow plugin holds the source of truth for this
# file and copies it here. A copy that differs from the plugin's source makes the next
# install refuse rather than overwrite, and nothing overrides that refusal.
#
# skill-hygiene: what the Agent Skills specification only recommends, kept separate from
# skill-conformance so that neither check overstates what it proves. Two assertions:
#
#   every relative file reference in a SKILL.md resolves, and SKILL.md stays under 500
#   lines.
#
# A reference inside a fenced code block is an example rather than a reference and is
# left alone. So is an absolute path, a URL, a bare anchor, and a path carrying a shell
# or template expansion, none of which this check can resolve on its own.
#
# Subject: GAUNTLET_SUBJECT, then the first argument, then the working directory.

set -uo pipefail

subject=${GAUNTLET_SUBJECT:-${1:-$PWD}}

if [ ! -d "$subject" ]; then
	printf 'skill-hygiene: subject %s is not a directory.\n' "$subject" >&2
	exit 2
fi

line_max=500

findings=0
report() { # report <skill file> <finding>
	printf '%s: %s\n' "${1#"$subject"/}" "$2"
	findings=$((findings + 1))
}

references() { # references <skill file>, one candidate target per line
	awk '
		/^[[:space:]]*(```|~~~)/ { fence = !fence; next }
		fence { next }
		{
			line = $0
			gsub(/`[^`]*`/, "", line)
			rest = line
			while (match(rest, /\]\([^)]*\)/)) {
				print substr(rest, RSTART + 2, RLENGTH - 3)
				rest = substr(rest, RSTART + RLENGTH)
			}
			if (match(line, /^\[[^]]+\]:[[:space:]]*[^[:space:]]+/)) {
				target = line
				sub(/^\[[^]]+\]:[[:space:]]*/, "", target)
				sub(/[[:space:]].*$/, "", target)
				print target
			}
		}
	' "$1"
}

mapfile -t files < <(find "$subject" -mindepth 1 \
	\( -name '.*' -o -name node_modules \) -prune -o \
	-type f -name SKILL.md -print 2>/dev/null | sort)

for file in "${files[@]}"; do
	dir=${file%/SKILL.md}

	lines=$(awk 'END { print NR }' "$file")
	if [ "$lines" -gt "$line_max" ]; then
		report "$file" "$lines lines, over the $line_max the specification recommends"
	fi

	while IFS= read -r target; do
		target=${target#"${target%%[![:space:]]*}"}
		target=${target%"${target##*[![:space:]]}"}
		case $target in
		'<'*'>') target=${target#<}; target=${target%>} ;;
		esac
		target=${target%% *}
		target=${target%%\#*}
		target=${target%%\?*}
		target=${target//%20/ }
		case $target in
		'') continue ;;
		/* | \#*) continue ;;
		*'$'* | *'{'*) continue ;;
		[A-Za-z]*:*)
			# A scheme (https:, mailto:, file:) rather than a path. A relative path
			# holding a colon after a slash is still a path.
			scheme=${target%%:*}
			case $scheme in
			*/*) ;;
			*[!A-Za-z0-9+.-]*) ;;
			*) continue ;;
			esac
			;;
		esac
		if [ ! -e "$dir/$target" ]; then
			report "$file" "the reference '$target' resolves to nothing"
		fi
	done < <(references "$file")
done

printf 'skill-hygiene: %s skill file(s) checked, %s finding(s).\n' "${#files[@]}" "$findings"
[ "$findings" -eq 0 ]
