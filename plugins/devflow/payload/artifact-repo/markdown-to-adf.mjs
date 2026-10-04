#!/usr/bin/env node

// devflow plugin-supplied file. The devflow plugin holds the source of truth for this
// file and copies it here. A copy that differs from the plugin's source makes the next
// install refuse rather than overwrite, and nothing overrides that refusal.
//
// Converts a draft issue's markdown to an Atlassian Document Format document, because the
// Jira CLI accepts no other structured input and stores plain text as one flat paragraph.
//
// Usage: markdown-to-adf.mjs [FILE]   (reads standard input when FILE is omitted)
// Writes the ADF document to standard output. Exits non-zero, naming the construct, when the
// markdown holds something ADF cannot carry. Node builtins only: no dependency, no manifest.
//
// Supported subset: headings, paragraphs, bullet and ordered lists including nested, inline
// code, fenced code blocks, bold, italic, links. Images are refused rather than dropped: an
// ADF media node needs an id from a prior upload and cannot be synthesised. Panel and status
// nodes are never emitted, both requiring attrs nothing in markdown supplies.

import { readFile } from 'node:fs/promises';
import { pathToFileURL } from 'node:url';

export class UnsupportedConstructError extends Error {
  constructor(construct, source, reason) {
    super(
      `Unsupported markdown construct: ${construct}. ${reason} Offending markdown: ${source}`,
    );
    this.name = 'UnsupportedConstructError';
    this.construct = construct;
    this.source = source;
  }
}

function textNode(text, marks) {
  return marks.length > 0 ? { type: 'text', text, marks } : { type: 'text', text };
}

function parseInline(source, marks = []) {
  const nodes = [];
  let plain = '';
  const flush = () => {
    if (plain !== '') {
      nodes.push(textNode(plain, marks));
      plain = '';
    }
  };

  let i = 0;
  while (i < source.length) {
    const rest = source.slice(i);

    const image = /^!\[([^[\]]*)\](\([^)]*\))?/.exec(rest);
    if (image) {
      throw new UnsupportedConstructError(
        'image',
        image[0],
        'An ADF media node needs an id from a prior Media Services upload and cannot be ' +
          'synthesised from a markdown image. Remove the image or link to it instead.',
      );
    }

    const inlineCode = /^(`+)([\s\S]+?)\1/.exec(rest);
    if (inlineCode) {
      flush();
      nodes.push(textNode(inlineCode[2].trim(), [...marks, { type: 'code' }]));
      i += inlineCode[0].length;
      continue;
    }

    const link = /^\[([^[\]]*)\]\(\s*<?([^\s<>()]+)>?\s*\)/.exec(rest);
    if (link) {
      flush();
      nodes.push(
        ...parseInline(link[1], [...marks, { type: 'link', attrs: { href: link[2] } }]),
      );
      i += link[0].length;
      continue;
    }

    // CommonMark forbids intraword underscore emphasis, so `order_id` stays an identifier
    // rather than silently becoming emphasised text in an Affected surfaces list.
    const underscoreAllowed = i === 0 || !/\w/.test(source[i - 1]);
    const underscoreStrong = underscoreAllowed ? /^__([\s\S]+?)__(?!\w)/.exec(rest) : null;
    const underscoreEm = underscoreAllowed ? /^_([^_]+?)_(?!\w)/.exec(rest) : null;

    const strong = /^\*\*([\s\S]+?)\*\*/.exec(rest) || underscoreStrong;
    if (strong) {
      flush();
      nodes.push(...parseInline(strong[1], [...marks, { type: 'strong' }]));
      i += strong[0].length;
      continue;
    }

    const em = /^\*([^*]+?)\*/.exec(rest) || underscoreEm;
    if (em) {
      flush();
      nodes.push(...parseInline(em[1], [...marks, { type: 'em' }]));
      i += em[0].length;
      continue;
    }

    plain += source[i];
    i += 1;
  }

  flush();
  return nodes;
}

const HEADING = /^ {0,3}(#{1,6})\s+(.*?)\s*#*\s*$/;
const FENCE = /^ {0,3}(`{3,}|~{3,})\s*([^\s`]*)\s*$/;

const LIST_ITEM = /^(\s*)([-*+]|\d+[.)])(\s+)(.*)$/;

function matchListItem(line) {
  const match = LIST_ITEM.exec(line);
  if (!match) {
    return null;
  }
  return {
    indent: match[1].length,
    ordered: /\d/.test(match[2]),
    markerWidth: match[1].length + match[2].length + match[3].length,
    text: match[4],
  };
}

function leadingSpaces(line) {
  return /^(\s*)/.exec(line)[1].length;
}

function startsBlock(line) {
  return HEADING.test(line) || FENCE.test(line) || matchListItem(line) !== null;
}

function parseFencedCode(lines, start) {
  const open = FENCE.exec(lines[start]);
  const closing = new RegExp(`^ {0,3}${open[1][0]}{${open[1].length},}\\s*$`);
  const body = [];
  let i = start + 1;
  while (i < lines.length && !closing.test(lines[i])) {
    body.push(lines[i]);
    i += 1;
  }
  if (i < lines.length) {
    i += 1;
  }

  const node = { type: 'codeBlock' };
  if (open[2] !== '') {
    node.attrs = { language: open[2] };
  }
  const text = body.join('\n');
  if (text !== '') {
    node.content = [{ type: 'text', text }];
  }
  return [node, i];
}

function parseList(lines, start, indent) {
  const { ordered } = matchListItem(lines[start]);
  const items = [];
  let i = start;

  while (i < lines.length) {
    if (lines[i].trim() === '') {
      let lookahead = i;
      while (lookahead < lines.length && lines[lookahead].trim() === '') {
        lookahead += 1;
      }
      const next = lookahead < lines.length ? matchListItem(lines[lookahead]) : null;
      const continues =
        lookahead < lines.length &&
        ((next !== null && next.indent === indent && next.ordered === ordered) ||
          leadingSpaces(lines[lookahead]) > indent);
      if (!continues) {
        break;
      }
      i = lookahead;
      continue;
    }

    const item = matchListItem(lines[i]);
    if (item === null || item.indent !== indent || item.ordered !== ordered) {
      break;
    }

    const body = [item.text];
    i += 1;
    while (i < lines.length) {
      if (lines[i].trim() === '') {
        let lookahead = i;
        while (lookahead < lines.length && lines[lookahead].trim() === '') {
          lookahead += 1;
        }
        if (lookahead < lines.length && leadingSpaces(lines[lookahead]) > indent) {
          body.push('');
          i = lookahead;
          continue;
        }
        break;
      }
      if (leadingSpaces(lines[i]) <= indent) {
        break;
      }
      body.push(lines[i].slice(Math.min(leadingSpaces(lines[i]), item.markerWidth)));
      i += 1;
    }

    const content = parseBlocks(body);
    items.push({
      type: 'listItem',
      content: content.length > 0 ? content : [{ type: 'paragraph' }],
    });
  }

  return [{ type: ordered ? 'orderedList' : 'bulletList', content: items }, i];
}

function parseBlocks(lines) {
  const nodes = [];
  let i = 0;

  while (i < lines.length) {
    if (lines[i].trim() === '') {
      i += 1;
      continue;
    }

    if (FENCE.test(lines[i])) {
      const [node, next] = parseFencedCode(lines, i);
      nodes.push(node);
      i = next;
      continue;
    }

    const heading = HEADING.exec(lines[i]);
    if (heading) {
      nodes.push({
        type: 'heading',
        attrs: { level: heading[1].length },
        content: parseInline(heading[2]),
      });
      i += 1;
      continue;
    }

    const item = matchListItem(lines[i]);
    if (item !== null) {
      const [node, next] = parseList(lines, i, item.indent);
      nodes.push(node);
      i = next;
      continue;
    }

    const paragraph = [];
    while (i < lines.length && lines[i].trim() !== '' && !startsBlock(lines[i])) {
      paragraph.push(lines[i].trim());
      i += 1;
    }
    const content = parseInline(paragraph.join(' '));
    if (content.length > 0) {
      nodes.push({ type: 'paragraph', content });
    }
  }

  return nodes;
}

export function markdownToAdf(markdown) {
  const lines = markdown.replace(/\r\n?/g, '\n').split('\n');
  return { version: 1, type: 'doc', content: parseBlocks(lines) };
}

async function readAll(stream) {
  const chunks = [];
  for await (const chunk of stream) {
    chunks.push(chunk);
  }
  return Buffer.concat(chunks).toString('utf8');
}

async function main(argv) {
  const path = argv[2];
  const markdown =
    path === undefined
      ? await readAll(process.stdin)
      : await readFile(path, 'utf8');

  let document;
  try {
    document = markdownToAdf(markdown);
  } catch (error) {
    if (error instanceof UnsupportedConstructError) {
      process.stderr.write(`${error.message}\n`);
      process.exitCode = 1;
      return;
    }
    throw error;
  }

  process.stdout.write(`${JSON.stringify(document)}\n`);
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  await main(process.argv);
}
