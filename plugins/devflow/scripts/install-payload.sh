#!/usr/bin/env bash
#
# The devflow payload installer.
#
# Copies one directory of plugin-supplied executables into one destination directory.
# The source directory is the manifest: it copies what it finds there and knows no file
# names of its own, so a new check is a new file and never an edit here.
#
# Not user-facing. The setup skill invokes it; the install path carries a version
# segment with no stable alias, so no documented direct invocation survives a bump.

set -uo pipefail

usage() {
	cat <<-'EOF'
		usage: install-payload.sh <source-directory> <destination-directory>

		  source-directory       a payload directory inside the plugin. A relative path
		                         resolves against the plugin root, so the script finds
		                         its own payloads whether or not the host substituted a
		                         plugin-root variable.
		  destination-directory  where the payload lands, relative to the current
		                         directory. Created when absent.

		There are no options. A copy that differs from the plugin's source is refused,
		and nothing overrides that refusal.
	EOF
}

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P) || exit 1
plugin_root=$(cd -- "$script_dir/.." && pwd -P) || exit 1

for arg in "$@"; do
	case $arg in
	-*)
		printf 'install-payload: %s is not an option; this installer has none.\n' "$arg" >&2
		usage >&2
		exit 2
		;;
	esac
done

if [ "$#" -ne 2 ]; then
	printf 'install-payload: expected a source directory and a destination directory, got %s argument(s).\n' "$#" >&2
	usage >&2
	exit 2
fi

source_arg=$1
dest_arg=$2

case $source_arg in
/*) source_dir=$source_arg ;;
*) source_dir=$plugin_root/$source_arg ;;
esac

if [ -L "$source_dir" ] || [ ! -d "$source_dir" ]; then
	printf 'install-payload: %s is not a directory.\n' "$source_dir" >&2
	exit 1
fi
source_dir=$(cd -- "$source_dir" && pwd -P) || exit 1

dest_dir=$dest_arg

printf 'source       %s\n' "$source_dir"
printf 'destination  %s\n' "$dest_dir"

shopt -s nullglob dotglob
entries=("$source_dir"/*)
shopt -u nullglob dotglob

if [ "${#entries[@]}" -eq 0 ]; then
	printf 'install-payload: %s holds no files to copy.\n' "$source_dir" >&2
	exit 1
fi

# The fixed header every plugin-supplied executable carries. It has no version segment
# in it on purpose: anything stamped per release would report drift in every repo on
# every bump, including where no logic changed. It marks our files so a later run can
# tell its own copies from the repo's own checks sitting in the same directory.
header_marker='devflow plugin-supplied file'
header_lines=10

carries_header() { # carries_header <file>
	head -n "$header_lines" -- "$1" 2>/dev/null | grep -qF -- "$header_marker"
}

faults=()
fault() { faults+=("$1"); }

# Preflight every source file before writing anything. A fault anywhere takes the whole
# run down: a stray editor backup in a payload directory stops the run loudly rather
# than shipping into every repo on the team.
names=()
for entry in "${entries[@]}"; do
	name=${entry##*/}
	if [ -L "$entry" ]; then
		fault "source $name is a symlink. The payload travels as real files, and a link does not survive being copied into a repo."
		continue
	fi
	if [ ! -f "$entry" ]; then
		fault "source $name is not a regular file."
		continue
	fi
	if [ ! -s "$entry" ]; then
		fault "source $name is empty. An empty check is declared but unrunnable, which a gauntlet reports as a failure of the repo."
		continue
	fi
	if [ ! -x "$entry" ]; then
		fault "source $name has no executable bit. The payload is executables, named by a config as commands."
		continue
	fi
	if ! carries_header "$entry"; then
		fault "source $name does not carry '$header_marker' within its first $header_lines lines. An unmarked copy cannot later be told from the repo's own files, so it could never be reported as an orphan."
		continue
	fi
	names+=("$name")
done

if [ -L "$dest_dir" ]; then
	fault "destination $dest_dir is a symlink. Writing through it would put the payload somewhere the repo does not show."
elif [ -e "$dest_dir" ] && [ ! -d "$dest_dir" ]; then
	fault "destination $dest_dir exists and is not a directory."
else
	# Preflight every target: absent, or byte-identical to the file that would replace
	# it. A target that differs is refused, and no argument makes the refusal go away:
	# the way past it is reverting or deleting the file, which is a human act in the
	# repo rather than a flag in a command a model composes.
	for name in "${names[@]}"; do
		target=$dest_dir/$name
		if [ -L "$target" ]; then
			fault "$target is a symlink."
		elif [ -e "$target" ] && [ ! -f "$target" ]; then
			fault "$target exists and is not a regular file."
		elif [ -f "$target" ] && ! cmp -s -- "$source_dir/$name" "$target"; then
			fault "$target differs from the plugin's copy of $name. The installer does not overwrite a file that differs and has no option that overrides this."
		fi
	done
fi

if [ "${#faults[@]}" -ne 0 ]; then
	printf 'install-payload: %s\n' "${faults[@]}" >&2
	printf 'install-payload: nothing was copied.\n' >&2
	exit 1
fi

mkdir -p -- "$dest_dir" || exit 1

for name in "${names[@]}"; do
	target=$dest_dir/$name
	if [ -f "$target" ]; then
		printf 'unchanged    %s\n' "$target"
		continue
	fi
	cp -- "$source_dir/$name" "$target" || exit 1
	chmod 755 -- "$target" || exit 1
	printf 'copied       %s\n' "$target"
done

# An orphan is a file in the destination carrying our header that the source set no
# longer holds. It is reported and left alone: deleting a file in a team's repo is not
# this script's call, and setup rewrites the configuration in the same pass, so an
# orphan loses its declaration and goes inert without anything being removed. A file
# without the header is the repo's own, and is never mentioned at all.
shopt -s nullglob dotglob
present=("$dest_dir"/*)
shopt -u nullglob dotglob

for entry in "${present[@]}"; do
	name=${entry##*/}
	[ -L "$entry" ] && continue
	[ -f "$entry" ] || continue
	carries_header "$entry" || continue
	for known in "${names[@]}"; do
		if [ "$known" = "$name" ]; then
			continue 2
		fi
	done
	printf 'orphan       %s\n' "$entry"
done
