#!/usr/bin/env bash
#
# Drives the payload installer against fixture directories and asserts observable
# outcomes only: what landed on disk, what the run printed, and what it exited with.
# Nothing here reaches into the installer's internals.
#
# Subject: GAUNTLET_SUBJECT, falling back to the repository this file sits in.

set -uo pipefail

self_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
subject=${GAUNTLET_SUBJECT:-$(cd -- "$self_dir/.." && pwd -P)}
installer=$subject/plugins/devflow/scripts/install-payload.sh

# The header every plugin-supplied executable carries, written here independently of the
# installer so the two have to agree rather than share.
marker='devflow plugin-supplied file'

work=$(mktemp -d) || exit 1
trap 'rm -rf -- "$work"' EXIT

cases=0
failures=0

check() { # check <status> <name>
	cases=$((cases + 1))
	if [ "$1" -eq 0 ]; then
		printf 'ok    %s\n' "$2"
	else
		printf 'FAIL  %s\n' "$2"
		failures=$((failures + 1))
	fi
}

fresh() { # fresh <label>, prints a new empty directory path
	local d
	d=$(mktemp -d "$work/$1.XXXXXX") || exit 1
	printf '%s\n' "$d"
}

payload() { # payload <path> <body>, a conforming source file
	cat >"$1" <<-EOF
		#!/usr/bin/env bash
		# $marker. The devflow plugin holds the source of truth for this file and
		# copies it here. A copy that differs from the plugin's source makes the next
		# install refuse rather than overwrite, and nothing overrides that refusal.
		$2
	EOF
	chmod 755 "$1"
}

run() { # run <args...>, captures stdout+stderr in $out and the exit code in $status
	out=$("$installer" "$@" 2>&1)
	status=$?
}

said() { # said <text>, true when the captured output mentions it
	case $out in
	*"$1"*) return 0 ;;
	*) return 1 ;;
	esac
}

# --- files are copied where expected, with the executable bit intact ----------------

src=$(fresh src)
dst=$(fresh dst)/gauntlets
payload "$src/alpha.sh" 'exit 0'
payload "$src/beta.sh" 'exit 0'

run "$src" "$dst"
check $((status == 0 ? 0 : 1)) "a clean run exits 0"
[ -f "$dst/alpha.sh" ] && [ -f "$dst/beta.sh" ]
check $? "every source file lands in the destination"
cmp -s "$src/alpha.sh" "$dst/alpha.sh"
check $? "a copied file is byte-identical to its source"
[ -x "$dst/alpha.sh" ] && [ -x "$dst/beta.sh" ]
check $? "the executable bit survives the copy"
said "alpha.sh"
check $? "the run names each file it copied"

# --- a source file failing preflight takes the whole run down ----------------------

bad_source() { # bad_source <label>, prints a source directory holding one good file
	local d
	d=$(fresh "$1")
	payload "$d/good.sh" 'exit 0'
	printf '%s\n' "$d"
}

aborts_whole_run() { # aborts_whole_run <source> <label>
	local s=$1 d
	d=$(fresh dst)/gauntlets
	run "$s" "$d"
	check $((status != 0 ? 0 : 1)) "$2 exits non-zero"
	[ ! -e "$d/good.sh" ]
	check $? "$2 leaves the sound file in the same run uncopied"
}

src=$(bad_source src)
: >"$src/empty.sh"
chmod 755 "$src/empty.sh"
aborts_whole_run "$src" "an empty source file"

src=$(bad_source src)
payload "$src/elsewhere.sh" 'exit 0'
mv "$src/elsewhere.sh" "$work/elsewhere.sh"
ln -s "$work/elsewhere.sh" "$src/link.sh"
aborts_whole_run "$src" "a symlink in the source directory"

src=$(bad_source src)
payload "$src/plain.sh" 'exit 0'
chmod 644 "$src/plain.sh"
aborts_whole_run "$src" "a source file without the executable bit"

src=$(bad_source src)
printf '#!/usr/bin/env bash\nexit 0\n' >"$src/unmarked.sh"
chmod 755 "$src/unmarked.sh"
aborts_whole_run "$src" "a source file without the devflow header"

src=$(bad_source src)
mkdir "$src/nested"
aborts_whole_run "$src" "a subdirectory in the source directory"

# --- the destination is preflighted too --------------------------------------------

src=$(fresh src)
dst=$(fresh dst)
payload "$src/alpha.sh" 'exit 0'
payload "$src/beta.sh" 'exit 0'
printf 'not the plugin copy\n' >"$dst/alpha.sh"
before=$(cat "$dst/alpha.sh")

run "$src" "$dst"
check $((status != 0 ? 0 : 1)) "a destination file that differs from its source is refused"
[ "$(cat "$dst/alpha.sh")" = "$before" ]
check $? "the differing file is left exactly as it was"
[ ! -e "$dst/beta.sh" ]
check $? "a refusal copies nothing else either"
said "alpha.sh"
check $? "the refusal names the file"

src=$(fresh src)
dst=$(fresh dst)
payload "$src/alpha.sh" 'exit 0'
cp "$src/alpha.sh" "$dst/alpha.sh"
touch -d '2001-01-01 00:00:00' "$dst/alpha.sh"
stamp=$(stat -c %Y "$dst/alpha.sh")

run "$src" "$dst"
check $((status == 0 ? 0 : 1)) "a destination file identical to its source is accepted"
[ "$(stat -c %Y "$dst/alpha.sh")" = "$stamp" ]
check $? "an identical file is not rewritten"
if said "copied"; then check 1 "an identical file is not reported as copied"; else check 0 "an identical file is not reported as copied"; fi

src=$(fresh src)
dst=$(fresh dst)
payload "$src/alpha.sh" 'exit 0'
payload "$work/outside.sh" 'exit 0'
ln -s "$work/outside.sh" "$dst/alpha.sh"

run "$src" "$dst"
check $((status != 0 ? 0 : 1)) "a symlink in the destination is refused"
[ -L "$dst/alpha.sh" ]
check $? "the symlink is left in place rather than written through"

src=$(fresh src)
dst=$(fresh dst)
payload "$src/alpha.sh" 'exit 0'
ln -s "$work" "$dst/wrapper"

run "$src" "$dst/wrapper"
check $((status != 0 ? 0 : 1)) "a destination directory that is a symlink is refused"

# --- orphans are reported, never deleted; the repo's own files are never mentioned ---

src=$(fresh src)
dst=$(fresh dst)
payload "$src/alpha.sh" 'exit 0'
cp "$src/alpha.sh" "$dst/alpha.sh"
payload "$dst/retired.sh" 'exit 0'
printf '#!/usr/bin/env bash\n# the repo wrote this one\nexit 0\n' >"$dst/repo-own.sh"
chmod 755 "$dst/repo-own.sh"

run "$src" "$dst"
check $((status == 0 ? 0 : 1)) "a run that finds an orphan still exits 0"
said "retired.sh"
check $? "the orphan is named"
said "orphan"
check $? "the orphan is called one"
[ -f "$dst/retired.sh" ]
check $? "the orphan is left on disk"
if said "repo-own.sh"; then check 1 "a destination file without the header is never mentioned"; else check 0 "a destination file without the header is never mentioned"; fi
[ -f "$dst/repo-own.sh" ]
check $? "a destination file without the header is left alone"

# --- nothing in a run reaches for git -----------------------------------------------

shim=$(fresh shim)
sentinel=$work/git-was-called
cat >"$shim/git" <<EOF
#!/usr/bin/env bash
printf 'called\n' >>"$sentinel"
exit 0
EOF
chmod 755 "$shim/git"

src=$(fresh src)
dst=$(fresh dst)
payload "$src/alpha.sh" 'exit 0'
payload "$dst/retired.sh" 'exit 0'
out=$(PATH=$shim:$PATH "$installer" "$src" "$dst" 2>&1)
differs=$(fresh dst)
printf 'not the plugin copy\n' >"$differs/alpha.sh"
out=$(PATH=$shim:$PATH "$installer" "$src" "$differs" 2>&1)
[ ! -e "$sentinel" ]
check $? "neither a clean run nor a refusal invokes git"

# --- there is no force flag ----------------------------------------------------------

src=$(fresh src)
dst=$(fresh dst)
payload "$src/alpha.sh" 'exit 0'
printf 'not the plugin copy\n' >"$dst/alpha.sh"
before=$(cat "$dst/alpha.sh")

for flag in --force -f --overwrite; do
	run "$flag" "$src" "$dst"
	check $((status != 0 ? 0 : 1)) "$flag is rejected"
	run "$src" "$dst" "$flag"
	check $((status != 0 ? 0 : 1)) "$flag is rejected after the arguments too"
done
[ "$(cat "$dst/alpha.sh")" = "$before" ]
check $? "no flag talks the installer past a differing file"

# --- the script locates its own payload directories ---------------------------------

fake_plugin=$(fresh plugin)
mkdir -p "$fake_plugin/scripts" "$fake_plugin/payload"
cp "$installer" "$fake_plugin/scripts/install-payload.sh"
chmod 755 "$fake_plugin/scripts/install-payload.sh"
payload "$fake_plugin/payload/alpha.sh" 'exit 0'
dst=$(fresh dst)

out=$(cd / && "$fake_plugin/scripts/install-payload.sh" payload "$dst" 2>&1)
status=$?
check $((status == 0 ? 0 : 1)) "a relative source resolves against the script's own plugin, not the working directory"
[ -f "$dst/alpha.sh" ]
check $? "the self-located payload lands in the destination"

# --- the payload the plugin actually ships passes its own preflight ------------------

dst=$(fresh dst)/gauntlets
run payload/gauntlets "$dst"
check $((status == 0 ? 0 : 1)) "the shipped gauntlet payload installs with no fault"
[ -x "$dst/skill-conformance.sh" ] && [ -x "$dst/skill-hygiene.sh" ]
check $? "both copyable checks land executable"

printf '\n%s case(s), %s failure(s)\n' "$cases" "$failures"
[ "$failures" -eq 0 ]
