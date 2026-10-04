#!/usr/bin/env bash
#
# Drives the two adapter checks against fixture trees built in a temporary directory,
# each holding a slots.md, an adapters/ directory and a README. Asserts observable
# outcomes only: the exit code, and the subject named in the output. Never the exact
# wording, so either check's prose can be rewritten without rewriting this file.
#
# The fixtures name slots Alpha, Beta and Gamma rather than the seven the real
# enumeration defines. A suite that fed the checks the real slot names could not tell a
# check that derives its expectation from a check that carries the list.
#
# Subject: GAUNTLET_SUBJECT, falling back to the repository this file sits in.

set -uo pipefail

self_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
subject=${GAUNTLET_SUBJECT:-$(cd -- "$self_dir/.." && pwd -P)}
completeness=$subject/docs/agents/gauntlets/adapter-slot-completeness.sh
agreement=$subject/docs/agents/gauntlets/adapter-readme-agreement.sh

work=$(mktemp -d) || exit 1
work=$(cd -- "$work" && pwd -P)
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

fixture() { # fixture <label>, prints a new empty fixture root, real path resolved
	local d
	d=$(mktemp -d "$work/$1.XXXXXX") || exit 1
	(cd -- "$d" && pwd -P)
}

slots() { # slots <root> <heading>..., writes the enumeration carrying those headings
	local root=$1 file heading
	shift
	file=$root/plugins/devflow/skills/setup-devflow/references/slots.md
	mkdir -p -- "$(dirname -- "$file")" || exit 1
	{
		printf '# The slots\n\nThe enumeration, and the only one.\n\n## The enumeration\n\n'
		for heading in "$@"; do
			printf '%s\n\nThe intent this slot states.\n\n' "$heading"
		done
	} >"$file" || exit 1
}

adapter() { # adapter <root> <slug> <heading>..., writes one adapter answering those
	local root=$1 slug=$2 file heading
	shift 2
	file=$root/plugins/devflow/adapters/$slug.md
	mkdir -p -- "$(dirname -- "$file")" || exit 1
	{
		printf '# %s\n\nOne host, answers only.\n\n' "$slug"
		for heading in "$@"; do
			printf '%s\n\nThis host spells it this way.\n\n' "$heading"
		done
	} >"$file" || exit 1
}

readme() { # readme <root> <slug>..., writes a README whose host table names those
	local root=$1 slug
	shift
	{
		printf '# devflow\n\n## Capabilities\n\n'
		printf '| # | Capability |\n| --- | --- |\n| C5 | `not-a-host` |\n\n'
		printf '## Hosts\n\n'
		printf '| Host | Adapter written against | Orchestrated build |\n| --- | --- | --- |\n'
		for slug in "$@"; do
			printf '| `%s` | Some Host 1.0 | not exercised |\n' "$slug"
		done
		printf '\nThe middle column records the release that adapter was written against.\n\n'
		printf '### Some Host\n\nInstall it like this.\n\n'
	} >"$root/README.md" || exit 1
}

run() { # run <script> <argument>..., captures stdout in $out, stderr in $errout
	local script=$1 errfile
	shift
	errfile=$(mktemp "$work/stderr.XXXXXX") || exit 1
	out=$(GAUNTLET_SUBJECT='' "$script" "$@" 2>"$errfile")
	status=$?
	errout=$(cat -- "$errfile")
}

# --- a complete adapter: both checks exit 0 -----------------------------------------

complete=$(fixture complete)
slots "$complete" '### Slot 1: Alpha' '### Slot 2: Beta' '### Slot 3: Gamma'
adapter "$complete" some-host '### Slot 1: Alpha' '### Slot 2: Beta' '### Slot 3: Gamma'
readme "$complete" some-host

run "$completeness" "$complete"
check $((status == 0 ? 0 : 1)) "slot completeness exits 0 for an adapter answering every slot"

run "$agreement" "$complete"
check $((status == 0 ? 0 : 1)) "agreement exits 0 when the adapter and the table name the same host"

# --- the subject is not a directory: exit 2 ------------------------------------------

for script in "$completeness" "$agreement"; do
	name=$(basename -- "$script")
	run "$script" "$complete/does-not-exist"
	check $((status == 2 ? 0 : 1)) "$name exits 2 for a subject that is not a directory"
	case $errout in
	*"$complete/does-not-exist"*) check 0 "$name names the subject it could not read" ;;
	*) check 1 "$name names the subject it could not read" ;;
	esac
done

# --- an adapter missing one slot heading: non-zero, and the slot is named -------------

missing=$(fixture missing-slot)
slots "$missing" '### Slot 1: Alpha' '### Slot 2: Beta' '### Slot 3: Gamma'
adapter "$missing" some-host '### Slot 1: Alpha' '### Slot 3: Gamma'
readme "$missing" some-host

run "$completeness" "$missing"
check $((status != 0 ? 0 : 1)) "slot completeness is non-zero for an adapter missing a slot"
case $out in
*'Slot 2: Beta'*) check 0 "the missing slot is named by number and name" ;;
*) check 1 "the missing slot is named by number and name" ;;
esac
case $out in
*plugins/devflow/adapters/some-host.md*) check 0 "the adapter missing a slot is named" ;;
*) check 1 "the adapter missing a slot is named" ;;
esac

run "$agreement" "$missing"
check $((status == 0 ? 0 : 1)) "agreement is unmoved by a slot the adapter does not answer"

# --- an adapter carrying a heading the enumeration does not define: non-zero ----------

extra=$(fixture extra-heading)
slots "$extra" '### Slot 1: Alpha' '### Slot 2: Beta'
adapter "$extra" some-host '### Slot 1: Alpha' '### Slot 2: Beta' '### Slot 3: Gamma'
readme "$extra" some-host

run "$completeness" "$extra"
check $((status != 0 ? 0 : 1)) "slot completeness is non-zero for a heading the enumeration does not define"
case $out in
*'Slot 3: Gamma'*) check 0 "the heading the enumeration does not define is named" ;;
*) check 1 "the heading the enumeration does not define is named" ;;
esac

# --- a near-miss spelling is drift, not a match --------------------------------------

nearmiss=$(fixture near-miss)
slots "$nearmiss" '### Slot 1: Alpha' '### Slot 2: Beta'
adapter "$nearmiss" some-host '### Slot 1: Alpha' '### Slot 2: beta'
readme "$nearmiss" some-host

run "$completeness" "$nearmiss"
check $((status != 0 ? 0 : 1)) "a heading that differs only in case is not a match"

# --- the enumeration gains a slot no adapter answers: non-zero ------------------------
#
# The drift case the check exists for. Both adapters were complete before slot 4 landed.

drifted=$(fixture enumeration-ahead)
slots "$drifted" '### Slot 1: Alpha' '### Slot 2: Beta' '### Slot 3: Gamma' '### Slot 4: Delta'
adapter "$drifted" some-host '### Slot 1: Alpha' '### Slot 2: Beta' '### Slot 3: Gamma'
adapter "$drifted" other-host '### Slot 1: Alpha' '### Slot 2: Beta' '### Slot 3: Gamma'
readme "$drifted" some-host other-host

run "$completeness" "$drifted"
check $((status != 0 ? 0 : 1)) "a slot the enumeration gains and no adapter answers is non-zero"
case $out in
*'Slot 4: Delta'*) check 0 "the slot the enumeration gained is named" ;;
*) check 1 "the slot the enumeration gained is named" ;;
esac
named=0
for slug in some-host other-host; do
	case $out in
	*"adapters/$slug.md"*) named=$((named + 1)) ;;
	esac
done
check $((named == 2 ? 0 : 1)) "every adapter missing the new slot is named, not only the first"

# --- no enumeration, or an enumeration defining nothing: non-zero ---------------------
#
# The adapters here answer nothing either, so the tree holds no disagreement to trip over.
# Only a check that refuses an empty expectation outright can fail these two.

empty=$(fixture empty-enumeration)
slots "$empty"
adapter "$empty" some-host
readme "$empty" some-host

run "$completeness" "$empty"
check $((status == 2 ? 0 : 1)) "an enumeration defining no slots exits 2 rather than passing silently"

gone=$(fixture no-enumeration)
adapter "$gone" some-host
readme "$gone" some-host

run "$completeness" "$gone"
check $((status == 2 ? 0 : 1)) "a missing enumeration exits 2 rather than passing silently"

# --- no adapter at all: both checks are asserted about nothing, so exit 2 ------------
#
# Exit 2 throughout this file means the same thing it means in the repository's other
# checks: the check could not assert, as against exit 1, which is a finding it did
# assert. A guard that collapsed to a silent pass would be invisible under "non-zero".

bare=$(fixture no-adapter)
slots "$bare" '### Slot 1: Alpha'
mkdir -p -- "$bare/plugins/devflow/adapters" || exit 1
readme "$bare" some-host

run "$completeness" "$bare"
check $((status == 2 ? 0 : 1)) "slot completeness over no adapter at all exits 2"

run "$agreement" "$bare"
check $((status == 2 ? 0 : 1)) "agreement over no adapter at all exits 2"

# --- an adapter whose slug the README does not name: non-zero -------------------------

unlisted=$(fixture adapter-unlisted)
slots "$unlisted" '### Slot 1: Alpha'
adapter "$unlisted" some-host '### Slot 1: Alpha'
adapter "$unlisted" other-host '### Slot 1: Alpha'
readme "$unlisted" some-host

run "$agreement" "$unlisted"
check $((status != 0 ? 0 : 1)) "an adapter the host table does not name is non-zero"
case $out in
*other-host*) check 0 "the adapter the table does not name is named" ;;
*) check 1 "the adapter the table does not name is named" ;;
esac

run "$completeness" "$unlisted"
check $((status == 0 ? 0 : 1)) "slot completeness is unmoved by a host the table does not name"

# --- a README host with no adapter file: non-zero -------------------------------------

unshipped=$(fixture host-unshipped)
slots "$unshipped" '### Slot 1: Alpha'
adapter "$unshipped" some-host '### Slot 1: Alpha'
readme "$unshipped" some-host other-host

run "$agreement" "$unshipped"
check $((status != 0 ? 0 : 1)) "a host row with no adapter behind it is non-zero"
case $out in
*other-host*) check 0 "the host row with no adapter is named" ;;
*) check 1 "the host row with no adapter is named" ;;
esac

# --- two adapters, both named: exit 0 -------------------------------------------------
#
# Present so neither check is known only against a set of one.

pair=$(fixture two-adapters)
slots "$pair" '### Slot 1: Alpha' '### Slot 2: Beta'
adapter "$pair" some-host '### Slot 1: Alpha' '### Slot 2: Beta'
adapter "$pair" other-host '### Slot 1: Alpha' '### Slot 2: Beta'
readme "$pair" some-host other-host

run "$completeness" "$pair"
check $((status == 0 ? 0 : 1)) "slot completeness exits 0 when two adapters each answer every slot"

run "$agreement" "$pair"
check $((status == 0 ? 0 : 1)) "agreement exits 0 when two adapters and two rows are the same set"

# --- the section continues past the table ---------------------------------------------
#
# The `## Hosts` section carries prose and a `### <host>` subsection after the table. A
# check that sliced from heading to heading, or scanned the file for backticked slugs,
# would read a host out of that prose. The fixture plants one there to prove it does not.

trailing=$(fixture prose-after-table)
slots "$trailing" '### Slot 1: Alpha'
adapter "$trailing" some-host '### Slot 1: Alpha'
{
	printf '# devflow\n\n## Hosts\n\n'
	printf '| Host | Adapter written against | Orchestrated build |\n| --- | --- | --- |\n'
	printf '| `some-host` | Some Host 1.0 | not exercised |\n\n'
	printf 'A host absent from the table, say `ghost-host`, is not a lesser tier.\n\n'
	printf '### Some Host\n\nInstall `ghost-host` is not a row either.\n\n'
	printf '| Flag | Meaning |\n| --- | --- |\n| `also-not-a-host` | a later table |\n'
} >"$trailing/README.md" || exit 1

run "$agreement" "$trailing"
check $((status == 0 ? 0 : 1)) "a backticked slug in the prose after the table is not a host row"

# --- no host table to agree with ------------------------------------------------------

tableless=$(fixture no-host-table)
slots "$tableless" '### Slot 1: Alpha'
adapter "$tableless" some-host '### Slot 1: Alpha'
printf '# devflow\n\nNo host section at all.\n' >"$tableless/README.md" || exit 1

run "$agreement" "$tableless"
check $((status == 2 ? 0 : 1)) "a README with no host section exits 2"

readmeless=$(fixture no-readme)
slots "$readmeless" '### Slot 1: Alpha'
adapter "$readmeless" some-host '### Slot 1: Alpha'

run "$agreement" "$readmeless"
check $((status == 2 ? 0 : 1)) "a missing README exits 2"

# --- the table is there but its shape is not ------------------------------------------

malformed=$(fixture malformed-table)
slots "$malformed" '### Slot 1: Alpha'
adapter "$malformed" some-host '### Slot 1: Alpha'
{
	printf '# devflow\n\n## Hosts\n'
	printf '| Host | Adapter written against | Orchestrated build |\n| --- | --- | --- |\n'
	printf '| `some-host` | Some Host 1.0 | not exercised |\n'
} >"$malformed/README.md" || exit 1

run "$agreement" "$malformed"
check $((status != 0 ? 0 : 1)) "a host table with no blank line after the heading is non-zero"

twocol=$(fixture two-column-table)
slots "$twocol" '### Slot 1: Alpha'
adapter "$twocol" some-host '### Slot 1: Alpha'
{
	printf '# devflow\n\n## Hosts\n\n'
	printf '| Host | Adapter written against |\n| --- | --- |\n'
	printf '| `some-host` | Some Host 1.0 |\n'
} >"$twocol/README.md" || exit 1

run "$agreement" "$twocol"
check $((status != 0 ? 0 : 1)) "a host table that is not three columns is non-zero"

# --- the subject comes from GAUNTLET_SUBJECT first, then the argument, then $PWD -------

for script in "$completeness" "$agreement"; do
	name=$(basename -- "$script")

	errfile=$(mktemp "$work/stderr.XXXXXX") || exit 1
	out=$(GAUNTLET_SUBJECT=$complete "$script" "$missing" 2>"$errfile")
	check $(($? == 0 ? 0 : 1)) "$name prefers GAUNTLET_SUBJECT over the first argument"

	out=$(cd -- "$complete" && GAUNTLET_SUBJECT='' "$script" 2>"$errfile")
	check $(($? == 0 ? 0 : 1)) "$name falls back to the working directory"
done

printf '\n%s case(s), %s failure(s)\n' "$cases" "$failures"
[ "$failures" -eq 0 ]
