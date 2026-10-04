#!/usr/bin/env bash
#
# devflow plugin-supplied file. The devflow plugin holds the source of truth for this
# file and copies it here. A copy that differs from the plugin's source makes the next
# install refuse rather than overwrite, and nothing overrides that refusal.
#
# issue-standards: the mechanical half of the team's Jira issue standard, over one draft
# issue, before it reaches Jira.
#
# It converts the draft once, with the ADF converter sitting beside it, and asserts
# against the resulting document rather than against the markdown. That is the choice
# that matters: the ADF is what ships, so a converter failure fails the gate instead of
# passing a draft whose markdown reads well and whose Jira rendering does not. One check
# rather than several, because a check is a standalone command with no shared state, so
# several would each pay for the conversion again.
#
# It asserts that the shape is there, never that the writing is good:
#
#   the five h2 headings present and exactly spelled, each carrying content; Design
#   carrying a link; a document that is ADF and holds no media, panel or status node; a
#   summary within 255 characters whose first word is not Implement, Refactor or Fix; a
#   declared issue type and a spec epic to be parented under.
#
# Whether the acceptance criteria are testable, whether the scope is right, whether the
# business outcome genuinely precedes the implementation, and whether a reader from
# another team could follow it are the whole substance of the standard, and no exit code
# reaches them. They are conceded to the review skill and to the human, deliberately.
#
# Two limits, stated rather than implied. "Valid ADF" here is the envelope plus the
# converter's closed node and mark vocabulary, not a run of Atlassian's schema: no
# validator is reachable without a dependency, and node nesting is unchecked. And the
# issue type is asserted to be declared rather than to match the draft, because nothing
# in a draft names an issue type; the config is its only source.
#
# Subject: GAUNTLET_SUBJECT, then the first argument. A file, not a directory.
# Working directory: the artifact repo clone.
# Exit: 0 clean, 1 findings against the draft, 2 the check could not run.

set -uo pipefail

self_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P) || exit 2
converter=$self_dir/markdown-to-adf.mjs
config=docs/agents/workflow.json

subject=${GAUNTLET_SUBJECT:-${1:-}}

abort() { # abort <message>
	printf 'issue-standards: %s\n' "$1" >&2
	exit 2
}

[ -n "$subject" ] || abort 'no draft issue named. The subject is a file path in GAUNTLET_SUBJECT.'
[ -f "$subject" ] || abort "subject $subject is not a file."
[ -f "$converter" ] || abort "the ADF converter is not beside this check at $converter. The payload installer copies the two together."
command -v node >/dev/null 2>&1 || abort 'node is not on PATH, and the ADF converter is a Node script.'
command -v jq >/dev/null 2>&1 || abort 'jq is not on PATH.'
[ -f "$config" ] || abort "$config is missing from the working directory, so tracker.projectKey and tracker.issueType cannot be read. Run setup-devflow in this repository."

# Standard error is kept apart from standard output so a warning on the way through
# cannot be mistaken for part of the document.
refusal=$(mktemp) || abort 'no temporary file could be created.'
trap 'rm -f -- "$refusal"' EXIT

if ! adf=$(node -- "$converter" "$subject" 2>"$refusal"); then
	printf 'issue-standards: %s does not convert to ADF, so nothing about its shape can be asserted.\n' "$subject" >&2
	cat -- "$refusal" >&2
	exit 1
fi

findings=()
note() { # note <finding>
	findings+=("$1")
}

# Everything the converted document can answer on its own, in one pass. The five section
# names are written here rather than read from the standard: they are the standard, they
# do not vary by repo, and a check that read its own expectations from the file under
# review would assert nothing.
assertions=$(
	cat <<-'JQ'
		def htext: ((.content // []) | map(.text // "") | join("")) ;

		# A section runs from its own heading to the next heading of level 1 or 2, so a
		# level 3 subheading divides a section rather than ending it.
		def bodyafter($top; $i):
			([$top | to_entries[]
				| select(.key > $i and .value.type == "heading" and ((.value.attrs.level // 7) <= 2))
				| .key] | first) as $next
			| [$top | to_entries[]
				| select(.key > $i and ($next == null or .key < $next))
				| .value] ;

		def marktypes: [recurse(.content[]?) | .marks[]? | .type] ;

		. as $doc
		| ($doc.content // []) as $top
		| ["What to build", "Acceptance criteria", "Out of scope", "Affected surfaces", "Design"] as $required
		| [$top | to_entries[]
			| select(.value.type == "heading" and (.value.attrs.level // 0) == 2)
			| {at: .key, text: (.value | htext)}] as $h2
		| [$top[] | select(.type == "heading" and (.attrs.level // 0) == 1) | htext] as $h1
		| ([recurse(.content[]?) | .type] | unique) as $nodetypes
		| (["media", "panel", "status"] | map(select(. as $t | $nodetypes | index($t) != null))) as $banned
		| ($nodetypes - ["doc", "heading", "paragraph", "bulletList", "orderedList", "listItem", "codeBlock", "text"]) as $foreign
		| (marktypes | unique | . - ["code", "em", "strong", "link"]) as $foreignmarks
		| [
			(if ($doc.type // "") != "doc" then
				"the converted document is rooted at a " + ($doc.type // "node with no type") + " rather than a doc node, so Jira will not accept it"
			 else empty end),
			(if ($doc.version // null) != 1 then
				"the converted document does not carry version 1, which every ADF document must"
			 else empty end),
			(if ($doc.content | type) != "array" then
				"the converted document has no content array"
			 else empty end),
			(if ($banned | length) > 0 then
				"the converted document holds " + ($banned | join(" and ")) + " node(s), which this flow never emits and cannot be made valid: a media node needs an id from a prior upload, and panel and status need attrs nothing in markdown supplies"
			 else empty end),
			(if ($foreign | length) > 0 then
				"the converted document holds node type(s) outside the supported set: " + ($foreign | join(", "))
			 else empty end),
			(if ($foreignmarks | length) > 0 then
				"the converted document holds mark type(s) outside the supported set: " + ($foreignmarks | join(", "))
			 else empty end),
			(([recurse(.content[]?) | select(.type == "text") | select((.text | type) != "string")] | length) as $untexted
			 | if $untexted > 0 then
				"the converted document holds " + ($untexted | tostring) + " text node(s) carrying no text string"
			   else empty end),
			(([recurse(.content[]?) | select(.type == "heading") | select((.attrs.level | type) != "number" or .attrs.level < 1 or .attrs.level > 6)] | length) as $unlevelled
			 | if $unlevelled > 0 then
				"the converted document holds " + ($unlevelled | tostring) + " heading(s) with no level between 1 and 6"
			   else empty end),
			(if ($h1 | length) == 0 then
				"the draft carries no h1 title, and the title is what becomes the Jira summary"
			 elif ($h1 | length) > 1 then
				"the draft carries " + ($h1 | length | tostring) + " h1 titles, so which one becomes the summary is ambiguous"
			 else
				($h1[0] | sub("^[0-9]+[.:)][ \t]*"; "")) as $summary
				| (if ($summary | length) > 255 then
					"the summary is " + ($summary | length | tostring) + " characters, over the 255 a Jira summary allows"
				   else empty end),
				  (if ($summary | test("^(implement|refactor|fix)\\b"; "i")) then
					"the summary opens with \"" + ($summary | split(" ") | .[0]) + "\", which frames the ticket as an implementation rather than an outcome"
				   else empty end)
			 end)
		]
		+ [
			$required[] as $name
			| [$h2[] | select(.text == $name)] as $hits
			| if ($hits | length) == 0 then
				"the h2 heading \"" + $name + "\" is missing, or is not spelled exactly that way"
			  elif ($hits | length) > 1 then
				"the h2 heading \"" + $name + "\" appears " + ($hits | length | tostring) + " times, so which section is which is ambiguous"
			  else
				bodyafter($top; $hits[0].at) as $body
				| (if ($body | any(.type != "heading")) then empty
				   else "the section \"" + $name + "\" carries nothing before the next heading" end),
				  (if $name == "Design" and (([$body[] | marktypes] | flatten | index("link")) == null) then
					"the Design section carries no link, so the draft names no spec to read"
				   else empty end)
			  end
		]
		| .[]
	JQ
)

while IFS= read -r finding; do
	[ -n "$finding" ] && note "$finding"
done < <(printf '%s' "$adf" | jq -r -- "$assertions")

# The two values the draft cannot carry. Issue type is config and nothing else, so the
# assertion is that the config declares it rather than that the draft agrees with it.
# Parent is the spec epic: publishing creates one Epic per spec and writes its key back
# as an Epic line in the effort's spec.md, so a draft whose effort has no such line would
# be created with no parent at all.
jq -e . -- "$config" >/dev/null 2>&1 ||
	abort "$config is not parseable JSON, so tracker.projectKey and tracker.issueType cannot be read."

project_key=$(jq -r '.tracker.projectKey // "" | tostring' -- "$config")
issue_type=$(jq -r '.tracker.issueType // "" | tostring' -- "$config")

[ -n "$project_key" ] ||
	note "$config carries no tracker.projectKey, so the project the issue belongs to is not declared. Run setup-devflow in this repository."
[ -n "$issue_type" ] ||
	note "$config carries no tracker.issueType, so the type the issue would be created with is not declared. Run setup-devflow in this repository."

spec=$(dirname -- "$subject")/../spec.md
if [ ! -f "$spec" ]; then
	note "the effort holding this draft has no spec.md beside its issues directory, so no Epic key can be read and the issue would be created with no parent"
else
	epic=$(grep -m1 -E '^[[:space:]]*[*_]*Epic:' -- "$spec" 2>/dev/null)
	epic=${epic#*:}
	epic=$(printf '%s' "$epic" | tr -d '*_`[:space:]')
	if [ -z "$epic" ]; then
		note "$spec records no Epic line, so the draft has no parent to be created under. Publishing creates the spec epic first and writes its key back."
	elif [ -n "$project_key" ] && ! printf '%s' "$epic" | grep -qE "^${project_key}-[0-9]+$"; then
		note "the Epic key $epic in $spec is not an issue in the configured project $project_key"
	fi
fi

if [ "${#findings[@]}" -eq 0 ]; then
	printf 'issue-standards: %s meets the mechanical standard.\n' "$subject"
	exit 0
fi

printf 'issue-standards: %s\n' "${findings[@]}" >&2
printf 'issue-standards: %s finding(s) in %s. The gauntlet checks that the shape is there, never that the writing is good.\n' \
	"${#findings[@]}" "$subject" >&2
exit 1
