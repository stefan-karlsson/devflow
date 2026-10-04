#!/usr/bin/env bash
#
# devflow plugin-supplied file. The devflow plugin holds the source of truth for this
# file and copies it here. A copy that differs from the plugin's source makes the next
# install refuse rather than overwrite, and nothing overrides that refusal.
#
# skill-conformance: the Agent Skills specification's Must rules, over every skill
# directory in the subject. The claim is the specification text at commit 69ef37e, not
# the standard's reference validator, which this check never runs: the validator rejects
# unknown frontmatter keys, which the specification text does not.
#
# It asserts exactly five things and deliberately nothing else:
#   SKILL.md present, a well-formed frontmatter block, name present and equal to the
#   parent directory basename, description present, both inside the length limits.
#
# "The frontmatter is well formed" is a structural subset, not a YAML parse: a delimited
# block whose lines are `key: value`, a block scalar and its indented body, a comment or
# a blank line. No YAML parser is reachable without a dependency. The limit is stated in
# docs/agents/gauntlets.md so no reader assumes a real parser ran.
#
# Subject: GAUNTLET_SUBJECT, then the first argument, then the working directory.

set -uo pipefail

subject=${GAUNTLET_SUBJECT:-${1:-$PWD}}

if [ ! -d "$subject" ]; then
	printf 'skill-conformance: subject %s is not a directory.\n' "$subject" >&2
	exit 2
fi

name_max=64
description_max=1024

findings=0
report() { # report <skill directory> <finding>
	printf '%s: %s\n' "${1#"$subject"/}" "$2"
	findings=$((findings + 1))
}

# Every skill directory in the subject: an immediate child of any directory named
# skills, and any directory holding a SKILL.md. The union is what makes "SKILL.md
# present" an assertion rather than a tautology.
skill_dirs() {
	local hit
	while IFS= read -r hit; do
		if [ -d "$hit" ]; then
			local child
			for child in "$hit"/*/; do
				[ -d "$child" ] && printf '%s\n' "${child%/}"
			done
		else
			printf '%s\n' "${hit%/SKILL.md}"
		fi
	done < <(find "$subject" -mindepth 1 \
		\( -name '.*' -o -name node_modules \) -prune -o \
		\( \( -type f -name SKILL.md \) -o \( -type d -name skills \) \) -print 2>/dev/null) |
		sort -u
}

unquote() { # unquote <value>
	local v=$1
	case $v in
	\"*\") v=${v#\"}; v=${v%\"} ;;
	\'*\') v=${v#\'}; v=${v%\'} ;;
	esac
	printf '%s' "$v"
}

mapfile -t dirs < <(skill_dirs)

for dir in "${dirs[@]}"; do
	file=$dir/SKILL.md
	if [ ! -f "$file" ]; then
		report "$dir" "no SKILL.md, so the skill is invisible to a host that scans for one"
		continue
	fi

	# Walk the frontmatter block once, collecting top-level keys.
	malformed=
	closed=
	in_body=
	key_name=
	key_description=
	have_name=
	have_description=
	continued=
	lineno=0
	while IFS= read -r raw || [ -n "$raw" ]; do
		lineno=$((lineno + 1))
		line=${raw%$'\r'}
		if [ "$lineno" -eq 1 ]; then
			if [ "$line" != '---' ]; then
				malformed="line 1 is not the opening --- delimiter"
				break
			fi
			continue
		fi
		if [ "$line" = '---' ]; then
			closed=1
			break
		fi
		case $line in
		'' | [[:space:]]*)
			if [ -n "$line" ] && [ -z "$continued" ]; then
				malformed="line $lineno is indented but no key opened a block above it"
				break
			fi
			if [ -n "$line" ] && [ -n "$in_body" ]; then
				body=${line#"${line%%[![:space:]]*}"}
				case $in_body in
				name) key_name="${key_name:+$key_name }$body" ;;
				description) key_description="${key_description:+$key_description }$body" ;;
				esac
			fi
			continue
			;;
		'#'*)
			continue
			;;
		esac
		case $line in
		[A-Za-z0-9]*:* )
			key=${line%%:*}
			case $key in
			*[!A-Za-z0-9_-]*)
				malformed="line $lineno is neither a key nor part of a block above it"
				break
				;;
			esac
			value=${line#*:}
			value=${value# }
			value=${value%"${value##*[![:space:]]}"}
			in_body=
			continued=
			case $value in
			'' | '|' | '>' | '|-' | '>-' | '|+' | '>+')
				continued=1
				in_body=$key
				;;
			esac
			case $key in
			name)
				have_name=1
				[ -n "$in_body" ] || key_name=$(unquote "$value")
				;;
			description)
				have_description=1
				[ -n "$in_body" ] || key_description=$(unquote "$value")
				;;
			esac
			;;
		*)
			malformed="line $lineno is neither a key nor part of a block above it"
			break
			;;
		esac
	done <"$file"

	if [ -n "$malformed" ]; then
		report "$dir" "the frontmatter is not well formed: $malformed"
		continue
	fi
	if [ -z "$closed" ]; then
		report "$dir" "the frontmatter block is never closed by a --- delimiter"
		continue
	fi

	basename=${dir##*/}
	if [ -z "$have_name" ] || [ -z "$key_name" ]; then
		report "$dir" "no name in the frontmatter, so the skill is discovered under no name at all"
	else
		if [ "${#key_name}" -gt "$name_max" ]; then
			report "$dir" "name is ${#key_name} characters, over the $name_max the specification allows"
		fi
		if [ "$key_name" != "$basename" ]; then
			report "$dir" "name is '$key_name' but the directory is '$basename'; the specification requires they match"
		fi
	fi

	if [ -z "$have_description" ] || [ -z "$key_description" ]; then
		report "$dir" "no description in the frontmatter"
	elif [ "${#key_description}" -gt "$description_max" ]; then
		report "$dir" "description is ${#key_description} characters, over the $description_max the specification allows"
	fi
done

printf 'skill-conformance: %s skill directory/directories checked, %s finding(s).\n' "${#dirs[@]}" "$findings"
[ "$findings" -eq 0 ]
