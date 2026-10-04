#!/usr/bin/env bash
#
# markdown-links: this repository's own check, so it carries no plugin-supplied header.
# Every relative link in every tracked markdown file this repository owns resolves.
#
# Two exclusions, each for a reason that is not "it was failing":
#
#   .scratch/        the spec and its tickets are working notes, not shipped prose.
#   untracked files  a link is only broken once it is committed.
#
# A link inside a fenced block or an inline code span is an example rather than a link.
# So is an absolute path, a URL, a bare anchor, and a path carrying a shell or template
# expansion, none of which this check can resolve on its own.
#
# Subject: GAUNTLET_SUBJECT, then the first argument, then the working directory.

set -uo pipefail

subject=${GAUNTLET_SUBJECT:-${1:-$PWD}}

if [ ! -d "$subject" ]; then
	printf 'markdown-links: subject %s is not a directory.\n' "$subject" >&2
	exit 2
fi

if ! git -C "$subject" rev-parse --git-dir >/dev/null 2>&1; then
	printf 'markdown-links: subject %s is not a git repository, so nothing is tracked.\n' "$subject" >&2
	exit 2
fi

findings=0
report() { # report <file> <finding>
	printf '%s: %s\n' "$1" "$2"
	findings=$((findings + 1))
}

in_scope() { # in_scope <repo-relative path>
	case $1 in
	.scratch/*) return 1 ;;
	esac
	return 0
}

# One candidate target per line: inline links and images, and reference definitions.
targets() { # targets <markdown file>
	awk '
		/^[[:space:]]*(```|~~~)/ { fence = !fence; next }
		fence { next }
		{
			line = $0
			gsub(/`[^`]*`/, "", line)

			# [label]: target, a reference definition at the start of a line.
			if (match(line, /^[[:space:]]{0,3}\[[^]]+\][[:space:]]*:[[:space:]]*/)) {
				print substr(line, RSTART + RLENGTH)
				next
			}

			# [text](target) and ![alt](target), several to a line.
			rest = line
			while ((at = index(rest, "](")) > 0) {
				rest = substr(rest, at + 2)
				close_at = index(rest, ")")
				if (close_at == 0) break
				print substr(rest, 1, close_at - 1)
				rest = substr(rest, close_at + 1)
			}
		}
	' "$1"
}

files=0
while IFS= read -r -d '' rel; do
	in_scope "$rel" || continue
	files=$((files + 1))
	file=$subject/$rel
	dir=${file%/*}

	while IFS= read -r target; do
		target=${target#"${target%%[![:space:]]*}"}
		target=${target%"${target##*[![:space:]]}"}
		case $target in
		'<'*'>')
			target=${target#<}
			target=${target%>}
			;;
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
			# A scheme (https:, mailto:) rather than a path. A relative path holding a
			# colon after a slash is still a path.
			scheme=${target%%:*}
			case $scheme in
			*/*) ;;
			*[!A-Za-z0-9+.-]*) ;;
			*) continue ;;
			esac
			;;
		esac
		if [ ! -e "$dir/$target" ]; then
			report "$rel" "the link '$target' resolves to nothing"
		fi
	done < <(targets "$file")
done < <(git -C "$subject" ls-files -z -- '*.md' '*.markdown')

printf 'markdown-links: %s tracked markdown file(s) checked, %s finding(s).\n' "$files" "$findings"
[ "$findings" -eq 0 ]
