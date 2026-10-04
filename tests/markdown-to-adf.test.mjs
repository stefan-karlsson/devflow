import { test } from 'node:test';
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { mkdtemp, rm, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

import {
  markdownToAdf,
  UnsupportedConstructError,
} from '../plugins/devflow/payload/artifact-repo/markdown-to-adf.mjs';

const CONVERTER = fileURLToPath(
  new URL('../plugins/devflow/payload/artifact-repo/markdown-to-adf.mjs', import.meta.url),
);

/** Runs the converter as the publish step runs it and reports what a shell would see. */
function runConverter(markdown, args = []) {
  try {
    const stdout = execFileSync(process.execPath, [CONVERTER, ...args], {
      input: markdown,
      encoding: 'utf8',
      stdio: ['pipe', 'pipe', 'pipe'],
    });
    return { status: 0, stdout, stderr: '' };
  } catch (error) {
    return {
      status: error.status,
      stdout: error.stdout ?? '',
      stderr: error.stderr ?? '',
    };
  }
}

/** Every node type the supported subset is allowed to emit. */
const EMITTABLE_NODE_TYPES = new Set([
  'doc',
  'heading',
  'paragraph',
  'bulletList',
  'orderedList',
  'listItem',
  'codeBlock',
  'text',
]);

/** Every mark type the supported subset is allowed to emit. */
const EMITTABLE_MARK_TYPES = new Set(['code', 'em', 'strong', 'link']);

function collectTypes(node, nodeTypes, markTypes) {
  nodeTypes.add(node.type);
  for (const mark of node.marks ?? []) {
    markTypes.add(mark.type);
  }
  for (const child of node.content ?? []) {
    collectTypes(child, nodeTypes, markTypes);
  }
}

test('a heading becomes a heading node carrying its level', () => {
  assert.deepEqual(markdownToAdf('## Out of scope'), {
    version: 1,
    type: 'doc',
    content: [
      {
        type: 'heading',
        attrs: { level: 2 },
        content: [{ type: 'text', text: 'Out of scope' }],
      },
    ],
  });
});

test('a heading containing emphasis splits across several text nodes', () => {
  const doc = markdownToAdf('## Out of **scope**');

  assert.deepEqual(doc.content, [
    {
      type: 'heading',
      attrs: { level: 2 },
      content: [
        { type: 'text', text: 'Out of ' },
        { type: 'text', text: 'scope', marks: [{ type: 'strong' }] },
      ],
    },
  ]);

  // The shape the issue check must survive: reading the first text node alone
  // yields "Out of ", so a comparison has to concatenate the whole run first.
  assert.equal(doc.content[0].content.length, 2);
  assert.notEqual(doc.content[0].content[0].text, 'Out of scope');
  assert.equal(doc.content[0].content.map((node) => node.text).join(''), 'Out of scope');
});

test('consecutive lines become one paragraph and a blank line starts the next', () => {
  assert.deepEqual(markdownToAdf('First line\nsecond line\n\nSecond paragraph').content, [
    { type: 'paragraph', content: [{ type: 'text', text: 'First line second line' }] },
    { type: 'paragraph', content: [{ type: 'text', text: 'Second paragraph' }] },
  ]);
});

test('bold carries a strong mark and italic carries an em mark', () => {
  assert.deepEqual(markdownToAdf('Plain **bold** and *italic* and _also italic_.').content, [
    {
      type: 'paragraph',
      content: [
        { type: 'text', text: 'Plain ' },
        { type: 'text', text: 'bold', marks: [{ type: 'strong' }] },
        { type: 'text', text: ' and ' },
        { type: 'text', text: 'italic', marks: [{ type: 'em' }] },
        { type: 'text', text: ' and ' },
        { type: 'text', text: 'also italic', marks: [{ type: 'em' }] },
        { type: 'text', text: '.' },
      ],
    },
  ]);
});

test('an underscore inside a word is literal, so an identifier is not silently emphasised', () => {
  assert.deepEqual(markdownToAdf('The order_id and shipment_tracking_number fields.').content, [
    {
      type: 'paragraph',
      content: [{ type: 'text', text: 'The order_id and shipment_tracking_number fields.' }],
    },
  ]);
});

test('inline code carries a code mark and keeps its emphasis characters literal', () => {
  assert.deepEqual(markdownToAdf('Run `npm **install**` now.').content, [
    {
      type: 'paragraph',
      content: [
        { type: 'text', text: 'Run ' },
        { type: 'text', text: 'npm **install**', marks: [{ type: 'code' }] },
        { type: 'text', text: ' now.' },
      ],
    },
  ]);
});

test('a link carries a link mark holding its href', () => {
  assert.deepEqual(markdownToAdf('See [the spec](https://example.invalid/spec.md).').content, [
    {
      type: 'paragraph',
      content: [
        { type: 'text', text: 'See ' },
        {
          type: 'text',
          text: 'the spec',
          marks: [{ type: 'link', attrs: { href: 'https://example.invalid/spec.md' } }],
        },
        { type: 'text', text: '.' },
      ],
    },
  ]);
});

test('emphasis inside link text stacks both marks on the same text node', () => {
  assert.deepEqual(markdownToAdf('[the **spec**](https://example.invalid/s)').content, [
    {
      type: 'paragraph',
      content: [
        {
          type: 'text',
          text: 'the ',
          marks: [{ type: 'link', attrs: { href: 'https://example.invalid/s' } }],
        },
        {
          type: 'text',
          text: 'spec',
          marks: [
            { type: 'link', attrs: { href: 'https://example.invalid/s' } },
            { type: 'strong' },
          ],
        },
      ],
    },
  ]);
});

test('a markdown image is refused by name rather than dropped or synthesised', () => {
  for (const source of [
    '![a diagram](diagram.png)',
    'Text before ![a diagram](diagram.png) and after.',
    '## Heading with ![a diagram](diagram.png)',
    '- list item with ![a diagram](diagram.png)',
    '[![a badge](badge.svg)](https://example.invalid)',
  ]) {
    assert.throws(
      () => markdownToAdf(source),
      (error) => {
        assert.ok(error instanceof UnsupportedConstructError);
        assert.equal(error.construct, 'image');
        assert.match(error.message, /image/);
        return true;
      },
      `expected a refusal for ${JSON.stringify(source)}`,
    );
  }
});

test('a fenced code block keeps its language and its lines verbatim', () => {
  const source = ['```bash', 'echo **hi**', 'echo `bye`', '```'].join('\n');

  assert.deepEqual(markdownToAdf(source).content, [
    {
      type: 'codeBlock',
      attrs: { language: 'bash' },
      content: [{ type: 'text', text: 'echo **hi**\necho `bye`' }],
    },
  ]);
});

test('a fenced code block without a language carries no attrs', () => {
  assert.deepEqual(markdownToAdf('```\nplain\n```').content, [
    { type: 'codeBlock', content: [{ type: 'text', text: 'plain' }] },
  ]);
});

test('a bullet list wraps each item in a listItem holding a paragraph', () => {
  assert.deepEqual(markdownToAdf('- first\n- second **bold**').content, [
    {
      type: 'bulletList',
      content: [
        {
          type: 'listItem',
          content: [{ type: 'paragraph', content: [{ type: 'text', text: 'first' }] }],
        },
        {
          type: 'listItem',
          content: [
            {
              type: 'paragraph',
              content: [
                { type: 'text', text: 'second ' },
                { type: 'text', text: 'bold', marks: [{ type: 'strong' }] },
              ],
            },
          ],
        },
      ],
    },
  ]);
});

test('an ordered list becomes an orderedList and does not merge with a bullet list', () => {
  assert.deepEqual(markdownToAdf('1. first\n2. second\n\n- bullet').content, [
    {
      type: 'orderedList',
      content: [
        {
          type: 'listItem',
          content: [{ type: 'paragraph', content: [{ type: 'text', text: 'first' }] }],
        },
        {
          type: 'listItem',
          content: [{ type: 'paragraph', content: [{ type: 'text', text: 'second' }] }],
        },
      ],
    },
    {
      type: 'bulletList',
      content: [
        {
          type: 'listItem',
          content: [{ type: 'paragraph', content: [{ type: 'text', text: 'bullet' }] }],
        },
      ],
    },
  ]);
});

test('a nested list sits inside its parent listItem beside that item paragraph', () => {
  const source = ['- Events', '  - OrderPlaced', '  - OrderShipped', '- APIs'].join('\n');

  assert.deepEqual(markdownToAdf(source).content, [
    {
      type: 'bulletList',
      content: [
        {
          type: 'listItem',
          content: [
            { type: 'paragraph', content: [{ type: 'text', text: 'Events' }] },
            {
              type: 'bulletList',
              content: [
                {
                  type: 'listItem',
                  content: [
                    { type: 'paragraph', content: [{ type: 'text', text: 'OrderPlaced' }] },
                  ],
                },
                {
                  type: 'listItem',
                  content: [
                    { type: 'paragraph', content: [{ type: 'text', text: 'OrderShipped' }] },
                  ],
                },
              ],
            },
          ],
        },
        {
          type: 'listItem',
          content: [{ type: 'paragraph', content: [{ type: 'text', text: 'APIs' }] }],
        },
      ],
    },
  ]);
});

test('an ordered list nests a bullet list under an item', () => {
  const source = ['1. Convert', '   - headings', '   - lists'].join('\n');

  assert.deepEqual(markdownToAdf(source).content, [
    {
      type: 'orderedList',
      content: [
        {
          type: 'listItem',
          content: [
            { type: 'paragraph', content: [{ type: 'text', text: 'Convert' }] },
            {
              type: 'bulletList',
              content: [
                {
                  type: 'listItem',
                  content: [
                    { type: 'paragraph', content: [{ type: 'text', text: 'headings' }] },
                  ],
                },
                {
                  type: 'listItem',
                  content: [{ type: 'paragraph', content: [{ type: 'text', text: 'lists' }] }],
                },
              ],
            },
          ],
        },
      ],
    },
  ]);
});

test('no input reaches a media, panel or status node', () => {
  const corpus = [
    '# Title\n\nBody with **bold**, *italic*, `code` and [a link](https://example.invalid).',
    '## Affected surfaces\n\n- Events\n  - OrderPlaced\n- APIs\n\n1. one\n2. two',
    '```json\n{"type":"media","attrs":{"id":"abc","collection":"c"}}\n```',
    'A paragraph naming media, mediaSingle, mediaGroup, panel and status as words.',
    '> a blockquote\n\n| a | table |\n| - | ----- |\n| 1 | 2 |\n\n---\n\n<div>raw html</div>',
    ':::info\nA directive that looks like a panel.\n:::',
    '{panel:info}not a panel{panel}',
    '# `media` and **panel** and [status](https://example.invalid/status)',
    '',
    '   \n\n   ',
  ];

  const nodeTypes = new Set();
  const markTypes = new Set();
  for (const source of corpus) {
    collectTypes(markdownToAdf(source), nodeTypes, markTypes);
  }

  for (const forbidden of ['media', 'mediaSingle', 'mediaGroup', 'mediaInline', 'panel', 'status']) {
    assert.ok(!nodeTypes.has(forbidden), `converter emitted a ${forbidden} node`);
  }
  assert.deepEqual([...nodeTypes].filter((type) => !EMITTABLE_NODE_TYPES.has(type)), []);
  assert.deepEqual([...markTypes].filter((type) => !EMITTABLE_MARK_TYPES.has(type)), []);
});

test('an empty document is a doc node with empty content', () => {
  assert.deepEqual(markdownToAdf(''), { version: 1, type: 'doc', content: [] });
});

test('reading markdown on standard input writes the ADF document to standard output', () => {
  const result = runConverter('## Out of scope\n\nNothing.\n');

  assert.equal(result.status, 0);
  assert.equal(result.stderr, '');
  assert.deepEqual(JSON.parse(result.stdout), markdownToAdf('## Out of scope\n\nNothing.\n'));
});

test('an image exits non-zero, names the construct on stderr and writes no document', () => {
  const result = runConverter('Here is ![a diagram](diagram.png) in the body.\n');

  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /image/);
  assert.equal(result.stdout, '');
});

test('a file argument is converted in place of standard input', async (t) => {
  const directory = await mkdtemp(join(tmpdir(), 'markdown-to-adf-'));
  t.after(() => rm(directory, { recursive: true, force: true }));
  const draft = join(directory, 'draft.md');
  await writeFile(draft, '# Title\n\n- one\n');

  const result = runConverter('', [draft]);

  assert.equal(result.status, 0);
  assert.deepEqual(JSON.parse(result.stdout), markdownToAdf('# Title\n\n- one\n'));
});
