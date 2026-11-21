// fran-pdf: exports a note to PDF as reading view shows it. The note is laid out at the width
// reading view gives it, so its lines break and its diagrams are laid out as in the note, and
// the page is scaled to fit the paper. CLAUDE.md explains how it works.
//
// Sections, in order: the page, the note, the dialog, and the plugin (FranPdf).
"use strict";

const {
  Plugin, MarkdownView, MarkdownRenderer, Component, Notice, Modal, Setting, ButtonComponent
} = require("obsidian");
const { remote, shell } = require("electron");
const fs = require("fs");

// --- The page -------------------------------------------------------------------------------

// The paper sizes Obsidian's own export offers, portrait, in millimetres
const PAPER = {
  A3: {width: 297, height: 420},
  A4: {width: 210, height: 297},
  A5: {width: 148, height: 210},
  Legal: {width: 215.9, height: 355.6},
  Letter: {width: 215.9, height: 279.4},
  Tabloid: {width: 279.4, height: 431.8}
};

// The margins on offer, in millimetres, with their labels: 2cm (LibreOffice's default), 1cm
// (about Chromium's) and none
const MARGINS = [[20, "2 cm"], [10, "1 cm"], [0, "None"]];

// The page an export gets when nothing else is chosen: A4, portrait, with 2cm margins
const PAGE_DEFAULTS = {paper: "A4", landscape: false, margin: 20};

const MM_PER_INCH = 25.4;
const PX_PER_MM = 96 / MM_PER_INCH;

// Chromium lays a page out at its printable width divided by the scale. This scale makes that
// the width the note is laid out at, so the page is the note scaled to fit. Electron takes
// 0.1 to 2.
const scaleFor = (width, {paper, landscape, margin}) => {
  const across = landscape ? PAPER[paper].height : PAPER[paper].width;
  const printable = (across - 2 * margin) * PX_PER_MM;
  return Math.min(2, Math.max(0.1, printable / width));
};

// Electron takes inches. The paper goes by its size, the one scaleFor() measured, rather than
// its name: Electron's A sizes are in hundredths of an inch, which makes A4 a point taller.
// Chromium still rounds some sides up, by less than a point. Landscape turns the paper.
const printOptions = ({paper, landscape, margin}, scale) => {
  const inches = margin / MM_PER_INCH;
  return {
    pageSize: {width: PAPER[paper].width / MM_PER_INCH, height: PAPER[paper].height / MM_PER_INCH},
    landscape,
    scale,
    printBackground: true,
    margins: {top: inches, bottom: inches, left: inches, right: inches}
  };
};

// The whole page takes the note's background: Chromium paints the margins with @page's
// background, and the rest of the page with the root's, which is otherwise body's, the UI's
const pageStyle = (background) =>
  `@page { background: ${background}; } @media print { html, body { background: ${background}; } }`;

// What Obsidian's print styles (app.css, @media print) change in what reading view shows, by
// selector: the page's text font, swapped for --font-print, which falls back differently for
// characters the font lacks (a footnote's ↩︎); external links' icons, taken off; highlights'
// text, turned black (color: initial); and folded callouts, opened, with !important.
const SCREEN_STYLES = [
  [".fran-pdf", ["--font-text"]],
  [".external-link", ["background-image", "background-position", "background-size",
    "background-repeat", "padding-inline-end"]],
  ["mark", ["color"]],
  [".callout-content", ["display"], "important"]
];

// The page keeps their values from the screen, set inline, which win over a stylesheet's, and
// !important over its !important. The font goes on the page's root, whose descendants inherit
// it rather than body's.
const keepScreenStyles = (root) => {
  for (const [selector, props, priority = ""] of SCREEN_STYLES) {
    for (const el of [root, ...root.querySelectorAll(selector)]) {
      if (!el.matches(selector)) continue;
      const style = getComputedStyle(el);
      for (const prop of props) el.style.setProperty(prop, style.getPropertyValue(prop), priority);
    }
  }
};

// A table wider than the note scrolls sideways in reading view, and a page can't. The theme
// breaks its cells' long words on paper (70-print.css), but Obsidian's minimum column width,
// 6ch, can still keep it wider than the page, so such a table drops it too, and narrows to
// fit. Only a table that doesn't fit: in one that does, a column narrower than 6ch stays as
// wide as in the note. Measured on screen, where the note has its width.
const fitWideTables = (root) => {
  for (const table of root.querySelectorAll("table")) {
    if (table.offsetWidth > table.parentElement.clientWidth) {
      table.style.setProperty("--table-column-min-width", "0px");
    }
  }
};

// --- The note -------------------------------------------------------------------------------

// The note, rendered into root as reading view renders it and in the same elements, so that
// the same rules apply: the view, with readable line length; its sizer; the header with the
// inline title, which shows or not as the setting says; the sections; and the footer. The
// view also takes the note's cssclasses. Returns the view.
const renderNote = async (app, file, root, component) => {
  const view = root.createDiv("markdown-preview-view markdown-rendered is-readable-line-width");
  view.addClasses(cssClasses(app, file));
  const sizer = view.createDiv("markdown-preview-sizer markdown-preview-section");
  sizer.createDiv("mod-header mod-ui").createDiv({cls: "inline-title", text: file.basename});
  const blocks = sizer.createDiv();
  await MarkdownRenderer.render(app, await app.vault.cachedRead(file), blocks, file.path, component);
  for (const block of [...blocks.children]) sizer.append(section(block));
  blocks.remove();
  sizer.createDiv("mod-footer mod-ui");
  return view;
};

// Reading view puts each block in a section of its own, a div named after the block's element
// (el-p, el-table...), and app.css counts on it: the first block after the header and the
// last one have no outer margin. A table scrolls in its section. The front matter's section is
// part of the header. A Mermaid diagram's is el-pre, named before Obsidian draws it in place
// of the code block, which it may have done already.
const section = (block) => {
  const name = block.matches("pre.frontmatter") ? "el-pre mod-frontmatter mod-ui"
    : block.matches(".mermaid") ? "el-pre"
    : `el-${block.tagName.toLowerCase()}`;
  const div = createDiv(name);
  div.append(block);
  if (block.matches("table")) div.style.overflowX = "auto";
  return div;
};

const cssClasses = (app, file) => {
  const value = app.metadataCache.getFileCache(file)?.frontmatter?.cssclasses ?? [];
  return (Array.isArray(value) ? value : String(value).split(/[\s,]+/)).filter(Boolean);
};

// Obsidian draws a Mermaid diagram after rendering, in place of its code block, and when
// fran-diagrams is on, it puts Pele's drawing in place of the placeholder Obsidian inserts.
// Waits for both, and for images, which could otherwise wait to load until they're on
// screen, which they never are.
const DIAGRAM_TIMEOUT = 10000; // ms
const settle = async (root) => {
  const pending = "pre > code.language-mermaid, .fran-diagram-pending";
  const end = Date.now() + DIAGRAM_TIMEOUT;
  while (root.querySelector(pending)) {
    if (Date.now() > end) throw new Error("a diagram didn't finish drawing");
    await sleep(50);
  }
  await Promise.all([...root.querySelectorAll("img")].map((img) => {
    img.loading = "eager";
    return img.decode().catch(() => {});
  }));
};

// --- The dialog -----------------------------------------------------------------------------

// The theme's color schemes for PDFs, with the labels its Style Settings entry gives them
// (src/00-header.css)
const COLOR_SCHEMES = {
  "github-light": "GitHub light",
  "github-dark": "GitHub dark",
  "anuppuccin-latte": "AnuPpuccin Latte",
  "anuppuccin-frappe": "AnuPpuccin Frappé"
};

// The theme's color scheme for PDFs, --fran-pdf-color-mode, as its default or Style Settings
// sets it. Empty under a theme without one.
const themeColorScheme = () =>
  getComputedStyle(document.body).getPropertyValue("--fran-pdf-color-mode").trim();

// Asks how to export the note, in a dialog laid out as Obsidian's own Export to PDF: the page,
// and the color scheme when the theme has one for PDFs. Starts at options, and resolves to the
// options chosen, or null when cancelled.
const chooseOptions = (app, file, options) =>
  new Promise((resolve) => new ExportDialog(app, file, options, resolve).open());

class ExportDialog extends Modal {
  constructor(app, file, options, resolve) {
    super(app);
    this.file = file;
    this.options = {...options};
    this.resolve = resolve;
    this.chosen = null;
  }

  onOpen() {
    const {contentEl, options} = this;
    this.modalEl.addClass("mod-narrow");
    this.setTitle("Export to PDF");
    contentEl.createEl("p", {
      cls: "u-muted u-break-word",
      text: `Export “${this.file.basename}” to PDF with the settings below.`
    });
    new Setting(contentEl).setName("Page size").addDropdown((dropdown) => {
      for (const name of Object.keys(PAPER)) dropdown.addOption(name, name);
      dropdown.setValue(options.paper).onChange((value) => { options.paper = value; });
    });
    new Setting(contentEl).setName("Landscape").addToggle((toggle) => {
      toggle.setValue(options.landscape).onChange((value) => { options.landscape = value; });
    });
    new Setting(contentEl).setName("Margin").addDropdown((dropdown) => {
      for (const [mm, label] of MARGINS) dropdown.addOption(String(mm), label);
      dropdown.setValue(String(options.margin))
        .onChange((value) => { options.margin = Number(value); });
    });
    if (options.colorScheme) {
      new Setting(contentEl).setName("Color scheme").addDropdown((dropdown) => {
        dropdown.addOptions(COLOR_SCHEMES).setValue(options.colorScheme)
          .onChange((value) => { options.colorScheme = value; });
      });
    }
    const buttons = this.modalEl.createDiv("modal-button-container");
    const exportButton = new ButtonComponent(buttons).setButtonText("Export to PDF").setCta()
      .onClick(() => {
        this.chosen = options;
        this.close();
      });
    new ButtonComponent(buttons).setButtonText("Cancel").onClick(() => this.close());
    // Export starts with the focus, as in Obsidian's dialog, so Enter exports
    activeWindow.setTimeout(() => exportButton.buttonEl.focus());
  }

  onClose() {
    this.contentEl.empty();
    this.resolve(this.chosen);
  }
}

// --- The plugin -----------------------------------------------------------------------------

module.exports = class FranPdf extends Plugin {
  onload() {
    this.addCommand({
      id: "export",
      name: "Export to PDF",
      checkCallback: (checking) => {
        const view = this.app.workspace.getActiveViewOfType(MarkdownView);
        if (!view?.file) return false;
        if (!checking) this.exportWithDialog(view);
        return true;
      }
    });
  }

  // Saves the note, since the export reads it from the vault and Obsidian saves edits only
  // after a pause. Then asks how to export it and where to save the PDF, exports there, and
  // opens the PDF in the system's app for PDFs, as Obsidian's own export does.
  //
  // The dialog starts at the page last exported with, kept in the plugin's data, and at the
  // theme's color scheme for PDFs, which isn't kept, so that the theme's setting stays the
  // default.
  async exportWithDialog(view) {
    const {file} = view;
    await view.save();
    const start = {...PAGE_DEFAULTS, ...(await this.loadData()), colorScheme: themeColorScheme()};
    const options = await chooseOptions(this.app, file, start);
    if (!options) return;
    const {colorScheme, ...page} = options;
    await this.saveData(page);
    const {canceled, filePath} = await remote.dialog.showSaveDialog({
      defaultPath: `${file.basename}.pdf`,
      filters: [{name: "PDF", extensions: ["pdf"]}],
      properties: ["showOverwriteConfirmation"]
    });
    if (canceled || !filePath) return;
    const notice = new Notice(`Exporting ${file.basename} to PDF…`, 0);
    try {
      await this.exportPdf(file, filePath, options);
      notice.setMessage(`Saved ${filePath}`);
      const error = await shell.openPath(filePath); // "" once opened
      if (error) notice.setMessage(`Saved ${filePath}, but couldn't open it: ${error}`);
    } catch (err) {
      console.error("fran-pdf:", err);
      notice.setMessage(`Couldn't export ${file.basename}: ${err?.message || err}`);
    }
    setTimeout(() => notice.hide(), 5000);
  }

  // Renders the note in this window, out of sight, and prints the window. The note goes in
  // body > .print, the one part of the window that Obsidian's print styles leave showing, and
  // styles.css keeps it out of sight on screen and sets its width. The PDF's title is the
  // note's name. One export at a time, since a print would include every note being exported.
  //
  // options are the page (PAGE_DEFAULTS' fields) and colorScheme, one of the theme's color
  // schemes for PDFs. One left out takes its default, and the color scheme the theme's.
  async exportPdf(file, filepath, options = {}) {
    if (this.exporting) throw new Error("another export is still running");
    this.exporting = true;
    const {colorScheme, ...page} = {...PAGE_DEFAULTS, ...options};
    const component = new Component();
    component.load();
    const root = document.body.createDiv("print fran-pdf");
    // The theme reads its color scheme for PDFs on this root, body > .print (11-palette-note.css)
    if (colorScheme) root.style.setProperty("--fran-pdf-color-mode", colorScheme);
    const style = document.head.createEl("style");
    const title = document.title;
    try {
      const view = await renderNote(this.app, file, root, component);
      await settle(root);
      keepScreenStyles(root);
      fitWideTables(root);
      style.textContent = pageStyle(getComputedStyle(view).backgroundColor);
      document.title = file.basename;
      const scale = scaleFor(root.getBoundingClientRect().width, page);
      const pdf = await remote.getCurrentWebContents().printToPDF(printOptions(page, scale));
      await fs.promises.writeFile(filepath, pdf);
    } finally {
      document.title = title;
      style.remove();
      root.remove();
      component.unload();
      this.exporting = false;
    }
  }
};
