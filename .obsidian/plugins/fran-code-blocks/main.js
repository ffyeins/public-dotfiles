/*
  fran-code-blocks: in the editor, gives every line of a code block the
  length of the block's longest line, in columns, as the CSS variable
  --fran-code-block-cols. fran-theme sizes the lines with it, so a block
  whose long lines don't wrap is drawn at one width, the longest line's,
  instead of each line ending at its own text. The plugin draws nothing
  itself.

  CSS alone can't do it: in CodeMirror a block is a run of sibling line
  elements, and each is sized from its own text. The length comes from the
  note's text instead, in columns, which code's monospace font makes a
  width.
*/

const { Plugin } = require("obsidian");
const { Decoration, ViewPlugin } = require("@codemirror/view");
const { RangeSetBuilder, countColumn } = require("@codemirror/state");
const { syntaxTree } = require("@codemirror/language");

/* Obsidian's syntax tree has a node for each line of a fenced code block,
   blank lines included, named after the line's classes joined with "_":
   "HyperMD-codeblock_HyperMD-codeblock-begin_..." for the opening fence,
   "HyperMD-codeblock_..._HyperMD-codeblock-end_..." for the closing one. */
const hasClass = (node, name) => node.name.split("_").includes(name);
const isCode = (node) => hasClass(node, "HyperMD-codeblock");
const isBegin = (node) => hasClass(node, "HyperMD-codeblock-begin");
const isEnd = (node) => hasClass(node, "HyperMD-codeblock-end");

/* The code blocks that overlap from..to, in order, as document ranges. A
   block can start before from and end after to. Past the part of the note
   parsed so far, a block ends at its last parsed line. */
function blocksIn(tree, from, to) {
  const blocks = [];
  for (let node = tree.topNode.childAfter(from); node && node.from <= to; node = node.nextSibling) {
    if (!isCode(node)) continue;
    let first = node;
    while (!isBegin(first) && first.prevSibling && isCode(first.prevSibling) && !isEnd(first.prevSibling)) {
      first = first.prevSibling;
    }
    let last = node;
    while (!isEnd(last) && last.nextSibling && isCode(last.nextSibling) && !isBegin(last.nextSibling)) {
      last = last.nextSibling;
    }
    blocks.push({ from: first.from, to: last.to });
    node = last;
  }
  return blocks;
}

/* The block's longest line, in columns, with tabs at the editor's tab
   size, as CodeMirror counts them */
function longestLine(state, block) {
  const { doc } = state;
  let cols = 0;
  for (let n = doc.lineAt(block.from).number, end = doc.lineAt(block.to).number; n <= end; n++) {
    cols = Math.max(cols, countColumn(doc.line(n).text, state.tabSize));
  }
  return cols;
}

/* A line decoration on each drawn line of each block. CodeMirror merges its
   style attribute with those of Obsidian's own line decorations. */
function decorations(view) {
  const { state } = view;
  const tree = syntaxTree(state);
  const builder = new RangeSetBuilder();
  for (const { from, to } of view.visibleRanges) {
    for (const block of blocksIn(tree, from, to)) {
      const deco = Decoration.line({
        attributes: { style: `--fran-code-block-cols: ${longestLine(state, block)}` },
      });
      const end = Math.min(block.to, to);
      for (let line = state.doc.lineAt(Math.max(block.from, from)); ; line = state.doc.line(line.number + 1)) {
        builder.add(line.from, line.from, deco);
        if (line.to >= end) break;
      }
    }
  }
  return builder.finish();
}

/* Recomputed when the text, the drawn part of the note or the parse
   changes. Obsidian parses a long note in steps, so a block's end can
   arrive after it first shows. */
const blockWidths = ViewPlugin.fromClass(
  class {
    constructor(view) {
      this.decorations = decorations(view);
    }

    update(update) {
      if (update.docChanged || update.viewportChanged || syntaxTree(update.startState) !== syntaxTree(update.state)) {
        this.decorations = decorations(update.view);
      }
    }
  },
  { decorations: (plugin) => plugin.decorations },
);

module.exports = class FranCodeBlocks extends Plugin {
  onload() {
    this.registerEditorExtension(blockWidths);
  }
};
