#!/usr/bin/env bash
#
# Drives the issue-standards check against fixture artifact repositories and asserts
# observable outcomes only: the exit code, and what the run named in its output. Nothing
# here reaches into the check's internals, and nothing here contacts Jira.
#
# Subject: GAUNTLET_SUBJECT, falling back to the repository this file sits in.

set -uo pipefail

self_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
subject=${GAUNTLET_SUBJECT:-$(cd -- "$self_dir/.." && pwd -P)}
check=$subject/plugins/devflow/payload/artifact-repo/issue-standards.sh

work=$(mktemp -d) || exit 1
trap 'rm -rf -- "$work"' EXIT

cases=0
failures=0

report() { # report <status> <name>
	cases=$((cases + 1))
	if [ "$1" -eq 0 ]; then
		printf 'ok    %s\n' "$2"
	else
		printf 'FAIL  %s\n' "$2"
		failures=$((failures + 1))
	fi
}

# A draft that satisfies every assertion. Each case rewrites one part of it, so a failing
# case differs from a passing draft in exactly one way.
compliant_body() {
	cat <<-'EOF'
		# 01: Merchants keep a saved payment method at checkout

		## What to build

		Returning merchants stop re-entering card details, which lifts conversion.

		## Acceptance criteria

		- A saved method appears on the checkout page.
		- A saved method can be removed.

		## Out of scope

		Refunds against a saved method.

		## Affected surfaces

		- `POST /checkout`
		  - the saved-method block

		## Design

		The [spec](https://example.invalid/efforts/demo/spec.md) carries the detail.
	EOF
}

# fixture <label>, draft body on stdin, prints the repository path
fixture() {
	local dir
	dir=$(mktemp -d "$work/$1.XXXXXX") || exit 1
	mkdir -p -- "$dir/docs/agents" "$dir/efforts/demo/issues" || exit 1
	cat >"$dir/docs/agents/workflow.json" <<-'EOF'
		{
		  "tracker": {
		    "site": "example.atlassian.net",
		    "projectKey": "ABC",
		    "issueType": "Task",
		    "doneStatus": "Done"
		  }
		}
	EOF
	printf '# Saved payment methods\n\nEpic: ABC-10\n\nA demo effort.\n' >"$dir/efforts/demo/spec.md"
	cat >"$dir/efforts/demo/issues/01-saved-method.md"
	printf '%s\n' "$dir"
}

# run <repository> [check], leaving the combined output in $out and the exit code in
# $status. The check defaults to the plugin's own copy, beside the real converter.
run() {
	local runnable=${2:-$check}
	out=$( (cd -- "$1" && GAUNTLET_SUBJECT=efforts/demo/issues/01-saved-method.md "$runnable") 2>&1 )
	status=$?
}

# stubbed <label>, an ADF document on stdin, prints a path to the check standing beside a
# converter that emits that document whatever it is handed. The check finds its converter
# as its own sibling, which is where the payload installer puts it, so stubbing the
# sibling is how a document the real converter cannot emit gets in front of the check.
stubbed() {
	local dir
	dir=$(mktemp -d "$work/$1.XXXXXX") || exit 1
	cat >"$dir/document.json"
	cp -- "$check" "$dir/issue-standards.sh" || exit 1
	cat >"$dir/markdown-to-adf.mjs" <<-'EOF'
		import { readFileSync } from 'node:fs';
		process.stdout.write(
		  readFileSync(new URL('./document.json', import.meta.url), 'utf8'),
		);
	EOF
	chmod 755 -- "$dir/issue-standards.sh" "$dir/markdown-to-adf.mjs" || exit 1
	printf '%s\n' "$dir/issue-standards.sh"
}

# --- a draft that meets the standard passes ------------------------------------------

repo=$(compliant_body | fixture compliant)
run "$repo"
[ "$status" -eq 0 ]
report $? 'a draft carrying the five sections, a linked design and an epic passes'

# --- the five headings, exactly spelled ----------------------------------------------

repo=$(compliant_body | sed 's/^## Out of scope$/## Scope/' | fixture no-out-of-scope)
run "$repo"
[ "$status" -ne 0 ] && printf '%s' "$out" | grep -qF 'Out of scope'
report $? 'a draft missing the Out of scope heading fails and names it'

repo=$(compliant_body | sed 's/^## Out of scope$/## Out of **scope**/' | fixture bold-heading)
run "$repo"
[ "$status" -eq 0 ]
report $? 'a heading carrying bold still matches, because its text nodes are concatenated'

repo=$(compliant_body | sed 's/^## Acceptance criteria$/## Acceptance Criteria/' | fixture miscased-heading)
run "$repo"
[ "$status" -ne 0 ]
report $? 'a heading spelled with different capitalisation fails'

# --- every section carries something -------------------------------------------------

repo=$(compliant_body | sed '/^Refunds against a saved method\.$/d' | fixture empty-section)
run "$repo"
[ "$status" -ne 0 ] && printf '%s' "$out" | grep -qF 'Out of scope'
report $? 'an empty Out of scope section fails and names it'

# --- the design section links out ----------------------------------------------------

repo=$(compliant_body | sed 's|The \[spec\](https://example.invalid/efforts/demo/spec.md) carries the detail.|The spec carries the detail.|' | fixture design-without-link)
run "$repo"
[ "$status" -ne 0 ] && printf '%s' "$out" | grep -qF 'Design'
report $? 'a Design section with no link fails'

repo=$(compliant_body | sed 's|The \[spec\](https://example.invalid/efforts/demo/spec.md) carries the detail.|- The [spec](https://example.invalid/efforts/demo/spec.md).|' | fixture design-link-in-list)
run "$repo"
[ "$status" -eq 0 ]
report $? 'a Design link nested inside a list still satisfies the link assertion'

# --- the document is ADF, and holds nothing ADF cannot carry -------------------------

# The compliant draft as the real converter renders it, so each document below differs
# from a passing one in exactly the node or mark under test.
compliant_adf() {
	compliant_body >"$work/compliant.md"
	node -- "$subject/plugins/devflow/payload/artifact-repo/markdown-to-adf.mjs" "$work/compliant.md"
}

repo=$(compliant_body | fixture adf-shape)

for banned in media panel status; do
	stub=$(compliant_adf | jq --arg t "$banned" '.content += [{type: $t}]' | stubbed "banned-$banned")
	run "$repo" "$stub"
	[ "$status" -ne 0 ] && printf '%s' "$out" | grep -qF "$banned"
	report $? "a converted document holding a $banned node fails and names it"
done

stub=$(compliant_adf | jq '.content += [{type: "table"}]' | stubbed unknown-node)
run "$repo" "$stub"
[ "$status" -ne 0 ] && printf '%s' "$out" | grep -qF 'table'
report $? 'a converted document holding a node type outside the supported set fails and names it'

stub=$(compliant_adf | jq '.content[1].content[0].marks = [{type: "textColor"}]' | stubbed unknown-mark)
run "$repo" "$stub"
[ "$status" -ne 0 ] && printf '%s' "$out" | grep -qF 'textColor'
report $? 'a converted document holding a mark outside the supported set fails and names it'

stub=$(compliant_adf | jq '.type = "paragraph"' | stubbed not-a-doc)
run "$repo" "$stub"
[ "$status" -ne 0 ]
report $? 'a converted document whose root is not a doc node fails'

stub=$(compliant_adf | jq 'del(.version)' | stubbed no-version)
run "$repo" "$stub"
[ "$status" -ne 0 ]
report $? 'a converted document carrying no version fails'

# --- a draft the converter refuses fails the gate ------------------------------------

repo=$(compliant_body | sed 's|^Refunds against a saved method\.$|![a diagram](./diagram.png)|' | fixture unconvertible)
run "$repo"
[ "$status" -ne 0 ] && printf '%s' "$out" | grep -qiF 'image'
report $? 'a draft the converter refuses fails the gate and names the construct'

# --- the summary ---------------------------------------------------------------------

repo=$(compliant_body | sed '/^# 01: /d' | fixture no-title)
run "$repo"
[ "$status" -ne 0 ]
report $? 'a draft with no h1 title fails, because nothing supplies the summary'

repo=$( {
	compliant_body
	printf '\n# 02: A second title\n'
} | fixture two-titles)
run "$repo"
[ "$status" -ne 0 ]
report $? 'a draft with two h1 titles fails, because which one is the summary is ambiguous'

repo=$(compliant_body | sed 's/^# 01: Merchants keep/# 01: Implement/' | fixture implementation-title)
run "$repo"
[ "$status" -ne 0 ] && printf '%s' "$out" | grep -qF 'Implement'
report $? 'a title whose first word is Implement fails, past the draft ordinal'

repo=$(compliant_body | sed 's/^# 01: Merchants keep/# 01: Add/' | fixture add-title)
run "$repo"
[ "$status" -eq 0 ]
report $? 'a title whose first word is Add passes, because Add is often a legitimate outcome'

long=$(printf 'A%.0s' $(seq 1 260))
repo=$(compliant_body | sed "s/^# 01: Merchants keep a saved payment method at checkout\$/# 01: $long/" | fixture long-title)
run "$repo"
[ "$status" -ne 0 ] && printf '%s' "$out" | grep -qF '255'
report $? 'a title over 255 characters fails and names the limit'

# --- parent and issue type -------------------------------------------------------------

repo=$(compliant_body | fixture no-epic)
printf '# Saved payment methods\n\nA demo effort.\n' >"$repo/efforts/demo/spec.md"
run "$repo"
[ "$status" -ne 0 ] && printf '%s' "$out" | grep -qF 'Epic'
report $? 'an effort whose spec records no Epic fails, because the issue would have no parent'

repo=$(compliant_body | fixture foreign-epic)
printf '# Saved payment methods\n\nEpic: XYZ-10\n' >"$repo/efforts/demo/spec.md"
run "$repo"
[ "$status" -ne 0 ]
report $? 'an Epic key outside the configured project fails'

repo=$(compliant_body | fixture no-issue-type)
printf '{"tracker":{"site":"example.atlassian.net","projectKey":"ABC"}}\n' >"$repo/docs/agents/workflow.json"
run "$repo"
[ "$status" -ne 0 ] && printf '%s' "$out" | grep -qF 'issueType'
report $? 'a configuration carrying no tracker.issueType fails and names the key'

repo=$(compliant_body | fixture no-config)
rm -f -- "$repo/docs/agents/workflow.json"
run "$repo"
[ "$status" -eq 2 ]
report $? 'a working directory with no configuration exits 2, because the check could not run'

repo=$(compliant_body | fixture no-subject)
out=$( (cd -- "$repo" && GAUNTLET_SUBJECT=efforts/demo/issues/99-absent.md "$check") 2>&1 )
[ $? -eq 2 ]
report $? 'a subject that is not a file exits 2'

# --- the scope boundary ----------------------------------------------------------------
#
# The check asserts that the shape is there, never that the writing is good. These drafts
# are poor tickets by every judgement the standard cares about, and every one of them is
# the review skill's business and the human's, not an exit code's.

repo=$( {
	cat <<-'EOF'
		# 01: Add a column to the merchant_config table

		## What to build

		Add a nullable `saved_method_id` column, then wire it through the repository layer.

		## Acceptance criteria

		- It works.
		- The code is clean.

		## Out of scope

		TBD.

		## Affected surfaces

		Various.

		## Design

		[Spec](https://example.invalid/efforts/demo/spec.md)
	EOF
} | fixture judgement)
run "$repo"
[ "$status" -eq 0 ]
report $? 'a structurally correct draft passes however badly it is written: untestable criteria, implementation before outcome, a vacuous scope section'

printf 'issue-standards tests: %s case(s), %s failure(s).\n' "$cases" "$failures"
[ "$failures" -eq 0 ]
