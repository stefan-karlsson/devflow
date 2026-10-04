#!/usr/bin/env bash
#
# scan-skill-environment: does this machine satisfy devflow's upstream skill dependency?
#
# devflow's phases name and load skills this plugin does not ship. Every way that
# dependency can fail, it fails silently. A skill a model was told to load and cannot
# find is not an error, the model simply proceeds without it. A renamed skill is the
# same. A disable-model-invocation key that upstream moved flips a phase from loaded to
# named with no message. A second copy resolves to whichever one the host picked. This
# script turns all four into an exit code, which is the only form the flow can act on.
#
# What it asserts is what it can see: it walks the roots it was given and reports what
# is present under them, keyed by the frontmatter name: rather than the directory
# basename, because the two differ in practice and a host resolves the frontmatter one.
# It never establishes that this host resolves anything by bare name. That is capability
# C1, a per-host fact the manual host pass establishes and this script does not, so a
# clean exit here means the files are on disk under those roots and no more than that.
#
# DEVFLOW_SKILL_ROOTS, colon-separated, replaces the roots that are scanned. It is how
# an engineer whose host reads skills from somewhere else points this probe at the roots
# their host actually reads, and it is what makes the script testable against fixtures
# rather than only against one laptop. Unset, the roots are the real ones:
# $HOME/.agents/skills and $HOME/.claude/skills, plus the repository's own
# .claude/skills and .agents/skills when a repository root is given.
#
# Plugin caches are not walked, and no plugin manifest is read. Claude Code namespaces a
# plugin's skills as <plugin>:<name>, so they are unreachable by bare name and cannot be
# the second copy this looks for. The marketplace plugin is not a supported install
# route for this dependency either.
#
# Dependency-free bash. It reads no JSON, so it needs no jq.
#
# Exit 0 the dependency is satisfied, 1 it is not, 2 the scan could not be performed.
#
# Usage: scan-skill-environment.sh [repository-root]
# The repository root, when given, adds that repository's project-scoped skill roots.

set -uo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P) || exit 2
plugin_root=$(cd -- "$script_dir/.." && pwd -P) || exit 2

# The supported floor: upstream main at or after this commit, which is v1.3 content.
# It is declared here, once, because the plugin owns it. It is deliberately not a
# workflow.json key: a repo able to set the floor is a repo able to lower it, and the
# whole point of a floor is that no repo can.
#
# It is asserted by content, never by a version string. Upstream's manifests still read
# 1.2.3 at this commit and the supported install route records no version on disk, so a
# version string here would assert something nothing writes down.
floor_commit=d81f3a1

# The eleven skills the flow requires. Absent, the phase that names one proceeds without
# it, which is the silent failure this exists to catch.
required_skills=(
	to-spec to-tickets implement implement-spec retro
	grilling domain-modeling prototype code-review pr
	setup-matt-pocock-skills
)

# The eight skills considered and deliberately not required. They are listed so a reader
# can see the decision rather than guess at an omission. Nothing below asserts their
# presence, and their absence is not a finding. They are covered by the duplicate rule,
# because a skill the flow would load if present must not be ambiguous when it is.
optional_skills=(
	triage diagnosing-bugs wayfinder improve-codebase-architecture
	research wizard to-questionnaire ask-matt
)

# The load-versus-name split the router depends on. The router names the first group,
# which is what disable-model-invocation: true buys, and loads the second, which only
# works while the key is absent. Both directions are failures: a true that has gone
# missing turns a named phase into one the model may invoke on its own, and a key that
# has appeared turns a loaded phase into one the router can only mention.
named_skills=(to-spec to-tickets implement implement-spec retro setup-matt-pocock-skills)
loaded_skills=(grilling domain-modeling prototype pr code-review)

repo_root=${1:-}
if [ -n "$repo_root" ]; then
	if [ ! -d "$repo_root" ]; then
		printf 'scan-skill-environment: %s is not a directory.\n' "$repo_root" >&2
		exit 2
	fi
	repo_root=$(cd -- "$repo_root" && pwd -P) || exit 2
fi

roots=()
if [ -n "${DEVFLOW_SKILL_ROOTS+x}" ]; then
	if [ -z "$DEVFLOW_SKILL_ROOTS" ]; then
		printf 'scan-skill-environment: DEVFLOW_SKILL_ROOTS is set to nothing, so there is no root to scan.\n' >&2
		exit 2
	fi
	IFS=: read -r -a roots <<<"$DEVFLOW_SKILL_ROOTS"
else
	home=${HOME:-}
	if [ -z "$home" ]; then
		printf 'scan-skill-environment: HOME is unset, so the machine-wide roots cannot be found.\n' >&2
		exit 2
	fi
	roots=("$home/.agents/skills" "$home/.claude/skills")
	if [ -n "$repo_root" ]; then
		roots+=("$repo_root/.claude/skills" "$repo_root/.agents/skills")
	fi
fi

# A root that is not there is an empty root: a machine may well have one of these and not
# the other, and that is not a fault in itself. A root that exists and cannot be read is
# a fault, because then the scan does not know what it missed.
for root in "${roots[@]}"; do
	[ -e "$root" ] || continue
	if [ ! -d "$root" ] || [ ! -r "$root" ] || [ ! -x "$root" ]; then
		printf 'scan-skill-environment: %s exists but cannot be read as a skills root.\n' "$root" >&2
		exit 2
	fi
done

# The bare name a host would list this skill under.
skill_name() { # skill_name <skill directory>
	local dir=$1 name
	[ -f "$dir/SKILL.md" ] || return 1
	name=$(awk '
		NR == 1 && $0 != "---" { exit }
		NR == 1 { next }
		$0 == "---" { exit }
		/^name:[[:space:]]*/ {
			sub(/^name:[[:space:]]*/, "")
			sub(/[[:space:]]+$/, "")
			print
			exit
		}
	' "$dir/SKILL.md")
	case $name in
	\"*\")
		name=${name#\"}
		name=${name%\"}
		;;
	\'*\')
		name=${name#\'}
		name=${name%\'}
		;;
	esac
	[ -n "$name" ] || name=${dir##*/}
	printf '%s' "$name"
}

# A top-level frontmatter value. Exit 1 says the key is not there, which is a different
# fact from an empty value and the one the invocation split turns on. Only column one is
# matched, so a nested key such as the one under pr's metadata: block is not mistaken for
# a top-level setting.
frontmatter_value() { # frontmatter_value <skill directory> <key>
	local dir=$1 key=$2 value
	[ -f "$dir/SKILL.md" ] || return 1
	value=$(awk -v key="$key" '
		NR == 1 && $0 != "---" { exit 1 }
		NR == 1 { next }
		$0 == "---" { exit !found }
		index($0, key ":") == 1 {
			found = 1
			sub(/^[^:]*:[[:space:]]*/, "")
			sub(/[[:space:]]+$/, "")
			print
			exit
		}
		END { exit !found }
	' "$dir/SKILL.md") || return 1
	case $value in
	\"*\")
		value=${value#\"}
		value=${value%\"}
		;;
	\'*\')
		value=${value#\'}
		value=${value%\'}
		;;
	esac
	printf '%s' "$value"
}

# Every immediate child of a skills root that holds a SKILL.md, as "<name><tab><real
# path>". The child is resolved rather than printed as reached, which is what the
# duplicate rule below is counting on.
list_root() { # list_root <skills root>
	local root=$1 child real name
	[ -d "$root" ] || return 0
	root=$(cd -- "$root" && pwd -P) || return 0
	for child in "$root"/*/; do
		child=${child%/}
		[ -d "$child" ] || continue
		real=$(cd -P -- "$child" && pwd -P) || continue
		name=$(skill_name "$real") || continue
		printf '%s\t%s\n' "$name" "$real"
	done
}

installed=$(
	for root in "${roots[@]}"; do
		list_root "$root"
	done | sort -u
)

# The distinct real directories offering one bare name.
paths_for() { # paths_for <bare name>
	[ -n "$installed" ] || return 0
	awk -F'\t' -v name="$1" '$1 == name { print $2 }' <<<"$installed"
}

findings=0
finding() { # finding <kind> <subject> <detail>
	printf '%-16s%-26s%s\n' "$1" "$2" "${3:-}"
	findings=$((findings + 1))
}

# The floor, by its two content markers.
#
# Marker A is the pr skill, which upstream added under engineering/ at v1.3. pr is also
# one of the eleven required skills, and its absence is reported here as a floor failure
# alone: an install without pr is below the floor by construction, and reporting the same
# absence twice would leave the two categories inseparable in the output. The required
# check below therefore skips pr, which is the other half of this decision.
if [ -z "$(paths_for pr)" ]; then
	finding below-floor pr "upstream main at or after $floor_commit, which added this skill"
fi

# Marker B is the name of the glossary file, which upstream renamed from CONTEXT.md to
# GLOSSARY.md at v1.3. A domain-modeling that is not there at all is a missing required
# skill rather than a floor failure, so this marker is only read when the skill exists.
domain_modeling=$(paths_for domain-modeling | head -n 1)
if [ -n "$domain_modeling" ]; then
	if ! grep -qF -- 'GLOSSARY.md' "$domain_modeling/SKILL.md" ||
		grep -qF -- 'CONTEXT.md' "$domain_modeling/SKILL.md"; then
		finding below-floor domain-modeling "upstream main at or after $floor_commit, which renamed the glossary to GLOSSARY.md"
	fi
fi

for name in "${required_skills[@]}"; do
	[ "$name" = pr ] && continue
	[ -n "$(paths_for "$name")" ] && continue
	finding missing-required "$name" "no skill of this name is reachable from the scanned roots"
done

for name in "${named_skills[@]}"; do
	dir=$(paths_for "$name" | head -n 1)
	[ -n "$dir" ] || continue
	if [ "$(frontmatter_value "$dir" disable-model-invocation || true)" != true ]; then
		finding invocation-key "$name" "disable-model-invocation must be true, the router names this skill rather than loading it"
	fi
done

for name in "${loaded_skills[@]}"; do
	dir=$(paths_for "$name" | head -n 1)
	[ -n "$dir" ] || continue
	if frontmatter_value "$dir" disable-model-invocation >/dev/null; then
		finding invocation-key "$name" "disable-model-invocation must be absent, the router loads this skill"
	fi
done

# One real directory, reachable through however many roots, is one copy. Upstream's
# installer puts the skills under one root and symlinks the host's own root at them, one
# link per skill, so on a correct install every one of these names is reachable through
# two roots. A rule that compared root directories would call all nineteen doubled and
# refuse on a machine that is right, which is why the candidates are resolved with pwd -P
# and counted by real path. The README names the install command, per host, because the
# flag that picks the host's root is the one part of it that is not the same everywhere.
#
# The rule covers the names this flow resolves and no others. A second copy of some other
# skill is somebody else's configuration and nothing devflow would load.
for name in "${required_skills[@]}" "${optional_skills[@]}"; do
	mapfile -t copies < <(paths_for "$name")
	[ "${#copies[@]}" -gt 1 ] || continue
	finding duplicate "$name" "${copies[*]}"
done

# This plugin's own skills. Both skill directories are counted: a host that reads only
# one of them lists fewer skills and never more, so counting both states the cost at its
# upper bound rather than under it.
ours=$(
	list_root "$plugin_root/skills"
	list_root "$plugin_root/claude/skills"
)
ours=$(sort -u <<<"$ours")

count_names() { # count_names <tab-separated lines>
	[ -n "$1" ] || {
		printf '0'
		return 0
	}
	cut -f1 <<<"$1" | sort -u | grep -c . || true
}

before=$(count_names "$installed")
after=$(count_names "$(printf '%s\n%s\n' "$installed" "$ours")")

# Three counts, kept because the cost they measure is real and local: every installed
# skill's description sits in the context window on every turn, so what this plugin adds
# is paid on every turn of every session. A figure measured on another machine is wrong
# on this one, which is why it is measured here.
printf 'skills-before   %s\n' "$before"
printf 'skills-after    %s\n' "$after"
printf 'devflow-adds    %s\n' "$((after - before))"
printf 'findings        %s\n' "$findings"

[ "$findings" -eq 0 ]
