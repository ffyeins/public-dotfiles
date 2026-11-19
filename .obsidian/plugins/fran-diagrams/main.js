// fran-diagrams: Obsidian's Mermaid diagrams, drawn by Pele the way mdread draws them, each in
// a box with buttons to copy its source, download it as SVG and expand it. CLAUDE.md explains
// how it hooks into Obsidian.
//
// Sections, in order: buttons, Download SVG, the expanded view, the height limit, Mermaid
// blocks in a note, a diagram (Diagram) and the plugin (FranDiagrams). Parts of it are mdread's
// code (lib/render.sh), with mdr- renamed to fran-, as CLAUDE.md lists: keep them in step.
// Pele is pele.global.js, pele@1.13.0.
"use strict";

const { Plugin, MarkdownView, loadMermaid } = require("obsidian");
const { EditorView } = require("@codemirror/view");

// --- Buttons (mdread) -----------------------------------------------------------------------

// GitHub's octicons, as mdread uses them
const icon = (...paths) =>
  '<svg viewBox="0 0 16 16" width="16" height="16" fill="currentColor" aria-hidden="true">' +
  paths.map((d) => `<path d="${d}"/>`).join("") + "</svg>";
const svgCopy = icon(
  "M0 6.75C0 5.784.784 5 1.75 5h1.5a.75.75 0 0 1 0 1.5h-1.5a.25.25 0 0 0-.25.25v7.5c0 .138.112.25.25.25h7.5a.25.25 0 0 0 .25-.25v-1.5a.75.75 0 0 1 1.5 0v1.5A1.75 1.75 0 0 1 9.25 16h-7.5A1.75 1.75 0 0 1 0 14.25zM5 1.75C5 .784 5.784 0 6.75 0h7.5C15.216 0 16 .784 16 1.75v7.5A1.75 1.75 0 0 1 14.25 11h-7.5A1.75 1.75 0 0 1 5 9.25z");
const svgCheck = icon(
  "M13.78 4.22a.75.75 0 0 1 0 1.06l-7.25 7.25a.75.75 0 0 1-1.06 0L2.22 9.28a.751.751 0 0 1 .018-1.042.751.751 0 0 1 1.042-.018L6 10.94l6.72-6.72a.75.75 0 0 1 1.06 0z");
const svgDownload = icon(
  "M2.75 14A1.75 1.75 0 0 1 1 12.25v-2.5a.75.75 0 0 1 1.5 0v2.5c0 .138.112.25.25.25h10.5a.25.25 0 0 0 .25-.25v-2.5a.75.75 0 0 1 1.5 0v2.5A1.75 1.75 0 0 1 13.25 14Z",
  "M7.25 7.689V2a.75.75 0 0 1 1.5 0v5.689l1.97-1.969a.749.749 0 1 1 1.06 1.06l-3.25 3.25a.749.749 0 0 1-1.06 0L4.22 6.78a.749.749 0 1 1 1.06-1.06l1.97 1.969Z");
const svgExpand = icon(
  "M1.75 10a.75.75 0 0 1 .75.75v2.5c0 .138.112.25.25.25h2.5a.75.75 0 0 1 0 1.5h-2.5A1.75 1.75 0 0 1 1 13.25v-2.5a.75.75 0 0 1 .75-.75Zm12.5 0a.75.75 0 0 1 .75.75v2.5A1.75 1.75 0 0 1 13.25 15h-2.5a.75.75 0 0 1 0-1.5h2.5a.25.25 0 0 0 .25-.25v-2.5a.75.75 0 0 1 .75-.75ZM2.75 2.5a.25.25 0 0 0-.25.25v2.5a.75.75 0 0 1-1.5 0v-2.5C1 1.784 1.784 1 2.75 1h2.5a.75.75 0 0 1 0 1.5ZM10 1.75a.75.75 0 0 1 .75-.75h2.5c.966 0 1.75.784 1.75 1.75v2.5a.75.75 0 0 1-1.5 0v-2.5a.25.25 0 0 0-.25-.25h-2.5a.75.75 0 0 1-.75-.75Z");
const svgClose = icon(
  "M3.72 3.72a.75.75 0 0 1 1.06 0L8 6.94l3.22-3.22a.749.749 0 0 1 1.275.326.749.749 0 0 1-.215.734L9.06 8l3.22 3.22a.749.749 0 0 1-.326 1.275.749.749 0 0 1-.734-.215L8 9.06l-3.22 3.22a.751.751 0 0 1-1.042-.018.751.751 0 0 1-.018-1.042L6.94 8 3.72 4.78a.75.75 0 0 1 0-1.06Z");
const svgPlus = icon(
  "M7.75 2a.75.75 0 0 1 .75.75V7h4.25a.75.75 0 0 1 0 1.5H8.5v4.25a.75.75 0 0 1-1.5 0V8.5H2.75a.75.75 0 0 1 0-1.5H7V2.75A.75.75 0 0 1 7.75 2Z");
const svgDash = icon("M2 7.75A.75.75 0 0 1 2.75 7h10.5a.75.75 0 0 1 0 1.5H2.75A.75.75 0 0 1 2 7.75Z");

// Buttons are labelled with aria-label, which Obsidian also shows as the tooltip
const button = (doc, label, svg, onClick, className = "fran-tool") => {
  const btn = doc.createElement("button");
  btn.type = "button";
  btn.className = className;
  btn.setAttribute("aria-label", label);
  btn.innerHTML = svg;
  btn.addEventListener("click", onClick);
  return btn;
};

const copyButton = (doc, className, label, getText) => {
  const btn = button(doc, label, svgCopy, () => {
    navigator.clipboard.writeText(getText()).then(() => {
      btn.classList.add("is-copied");
      btn.innerHTML = svgCheck;
      setTimeout(() => {
        btn.classList.remove("is-copied");
        btn.innerHTML = svgCopy;
      }, 2000);
    });
  }, className);
  return btn;
};

// --- Download SVG (mdread) ------------------------------------------------------------------

// The SVG Pele drew in a diagram's box
const svgOf = (job) => job.el?.querySelector(":scope > svg");

// An SVG at its own size, without the page's sizing or what Pele's zoom left on it
const natural = (svg, w, h) => {
  svg.setAttribute("width", w);
  svg.setAttribute("height", h);
  for (const prop of ["max-width", "width", "height", "margin", "display", "cursor",
    "user-select", "touch-action", "outline"]) {
    svg.style.removeProperty(prop);
  }
  svg.removeAttribute("tabindex");
  return svg;
};

// A standalone copy of a diagram that looks the way it does in the note
const exportSvg = (job) => {
  const live = svgOf(job);
  const svg = natural(live.cloneNode(true), job.w, job.h);
  svg.setAttribute("viewBox", `0 0 ${job.w} ${job.h}`); // undo Pele's zoom
  // Custom properties it uses but gets from the page (the --pele-* colors) go on its root
  const markup = svg.outerHTML;
  const computed = getComputedStyle(live);
  for (const [, name] of markup.matchAll(/var\(\s*(--[\w-]+)/g)) {
    if (new RegExp(name + "\\s*:").test(markup)) continue;
    const value = computed.getPropertyValue(name).trim();
    if (value) svg.style.setProperty(name, value);
  }
  // Pele draws on a transparent background; give it the box's
  svg.style.backgroundColor = getComputedStyle(job.wrap).backgroundColor;
  // XMLSerializer, not outerHTML: HTML in <foreignObject> must be well-formed XML
  return '<?xml version="1.0" encoding="UTF-8"?>\n' +
    new XMLSerializer().serializeToString(svg) + "\n";
};

// Saves it as <base>-diagram-<n>.svg; Electron asks where
const download = (job, {base, n}) => {
  if (!svgOf(job)) return;
  const url = URL.createObjectURL(new Blob([exportSvg(job)], {type: "image/svg+xml"}));
  const a = job.doc.createElement("a");
  a.href = url;
  a.download = `${base}-diagram-${n}.svg`;
  job.doc.body.append(a);
  a.click();
  a.remove();
  setTimeout(() => URL.revokeObjectURL(url), 60000);
};

// --- The expanded view (mdread) -------------------------------------------------------------

// Pan and zoom for the expanded diagram in view, a scrolling box: dragging pans by scrolling
// it, and zooming resizes the SVG. 100% is the diagram's natural size. Returns show(svg, w, h),
// which puts an SVG of that natural size under the zoom, and the zoom controls, [- 100% +].
const zoomSteps = [0.1, 0.25, 0.33, 0.5, 0.67, 0.75, 0.9, 1, 1.1, 1.25, 1.5, 1.75, 2, 2.5, 3, 4, 5];
const minZoom = zoomSteps[0], maxZoom = zoomSteps.at(-1);
const panZoom = (doc, view, keys) => {
  let svg, w = 0, h = 0, scale = 1;
  const size = () => {
    if (!svg || !(w > 0 && h > 0)) return;
    svg.style.width = `${w * scale}px`;
    svg.style.height = `${h * scale}px`;
  };
  // Zooms keeping the diagram's point under (x, y) in place, the view's center by default
  const zoomTo = (next, x, y) => {
    next = Math.min(Math.max(next, minZoom), maxZoom);
    if (svg && next !== scale) {
      const box = view.getBoundingClientRect();
      x ??= box.left + view.clientWidth / 2;
      y ??= box.top + view.clientHeight / 2;
      const before = svg.getBoundingClientRect();
      scale = next;
      size();
      const after = svg.getBoundingClientRect();
      view.scrollLeft += after.left - x + (x - before.left) * (after.width / before.width);
      view.scrollTop += after.top - y + (y - before.top) * (after.height / before.height);
    }
    level.textContent = `${Math.round(scale * 100)}%`;
    level.setAttribute("aria-label", `Reset zoom (${level.textContent})`);
    zoomOut.setAttribute("aria-disabled", scale <= minZoom);
    zoomIn.setAttribute("aria-disabled", scale >= maxZoom);
  };
  const step = (dir) => dir > 0
    ? zoomSteps.find((s) => s > scale * 1.001) ?? maxZoom
    : zoomSteps.findLast((s) => s < scale / 1.001) ?? minZoom;

  const controls = doc.createElement("div");
  controls.className = "fran-zoom";
  const zoomOut = button(doc, "Zoom out", svgDash, () => zoomTo(step(-1)), "");
  const level = button(doc, "Reset zoom", "100%", () => zoomTo(1), "fran-zoom-level");
  const zoomIn = button(doc, "Zoom in", svgPlus, () => zoomTo(step(1)), "");
  controls.append(zoomOut, level, zoomIn);
  zoomTo(scale);

  // Dragging pans, with the mouse: touch scrolls by itself. Not on the scrollbars. It cancels
  // the press's default (text selection, focus), so it focuses the view for the arrow keys.
  let drag;
  view.addEventListener("pointerdown", (e) => {
    const box = view.getBoundingClientRect();
    if (e.pointerType !== "mouse" || e.button !== 0 ||
        e.clientX >= box.left + view.clientWidth || e.clientY >= box.top + view.clientHeight) return;
    e.preventDefault();
    view.focus({preventScroll: true});
    drag = {id: e.pointerId, x: e.clientX + view.scrollLeft, y: e.clientY + view.scrollTop};
    view.setPointerCapture(e.pointerId);
    view.classList.add("fran-panning");
  });
  view.addEventListener("pointermove", (e) => {
    if (e.pointerId !== drag?.id) return;
    view.scrollLeft = drag.x - e.clientX;
    view.scrollTop = drag.y - e.clientY;
  });
  const endDrag = (e) => {
    if (e.pointerId !== drag?.id) return;
    drag = undefined;
    view.classList.remove("fran-panning");
  };
  // On release, or when the browser takes the capture away (pointercancel, a lost focus)
  view.addEventListener("pointerup", endDrag);
  view.addEventListener("lostpointercapture", endDrag);

  // The wheel zooms rather than scrolls, and so does pinching: Chromium sends a pinch as a
  // wheel event with ctrlKey. Wheel deltas in lines or pages become pixels, then each event
  // zooms by at most 2^0.48.
  view.addEventListener("wheel", (e) => {
    e.preventDefault();
    const px = e.deltaY * (e.deltaMode === 1 ? 20 : e.deltaMode === 2 ? 400 : 1);
    const delta = Math.min(Math.max(-px, -24), 24);
    zoomTo(scale * 2 ** (delta * 0.02), e.clientX, e.clientY);
  }, {passive: false});

  // + / = zoom in, - zooms out, 0 resets. Stopped here so Obsidian's hotkeys don't see them.
  keys.addEventListener("keydown", (e) => {
    if (e.ctrlKey || e.metaKey || e.altKey) return;
    if (e.key === "+" || e.key === "=") zoomTo(step(1));
    else if (e.key === "-") zoomTo(step(-1));
    else if (e.key === "0") zoomTo(1);
    else return;
    e.preventDefault();
    e.stopPropagation();
  });

  // The diagram opens centered: as a flex item with auto margins when it fits, and scrolled to
  // its middle when it doesn't. A redraw (Pele's, when fonts change) keeps the scroll.
  const show = (el, width, height) => {
    const first = !svg;
    svg = el;
    w = width;
    h = height;
    size();
    if (first) {
      view.scrollLeft = (view.scrollWidth - view.clientWidth) / 2;
      view.scrollTop = (view.scrollHeight - view.clientHeight) / 2;
    }
  };
  return {show, controls};
};

// The width a container lays its diagram out in: Pele's, in a note, has padding
const contentWidth = (el) => {
  const style = getComputedStyle(el);
  return el.clientWidth - parseFloat(style.paddingLeft) - parseFloat(style.paddingRight);
};

// Shows diagram number n in a modal dialog at its natural size, with pan and zoom (panZoom).
// Esc, the close button or a click outside closes it.
const expand = (job, opener, pele, n) => {
  if (!svgOf(job)) return;
  const {doc} = job;
  const dialog = doc.createElement("dialog");
  dialog.className = "fran-dialog";
  dialog.setAttribute("aria-label", `Diagram ${n}`);
  const view = doc.createElement("div");
  view.className = "fran-dialog-view";
  view.tabIndex = 0; // so the arrow keys pan
  const zoom = panZoom(doc, view, dialog);
  dialog.append(view, button(doc, "Close", svgClose, () => dialog.close()), zoom.controls);
  doc.body.append(dialog);
  dialog.showModal();

  // A new Pele drawing, laid out once for the dialog's width, without Pele's zoom. Once
  // drawn, its container shrinks to fit it, so it centers and scrolls. Never laid out
  // narrower than the note's diagram is: Pele turns a left-right diagram that doesn't fit
  // top to bottom when its width is under 640px, and the dialog could be narrower than the
  // note.
  const div = doc.createElement("div");
  div.className = "fran-diagram-pele";
  div.style.width = "100%";
  view.append(div);
  const mounted = pele.mount(div, job.text, {
    zoom: false,
    maxWidth: Math.max(div.clientWidth, contentWidth(job.el)),
    onRender(result) {
      div.style.width = "";
      zoom.show(div.querySelector(":scope > svg"), result.width, result.height);
    }
  });
  view.focus({preventScroll: true});
  dialog.addEventListener("click", (e) => {
    if (e.target === dialog) dialog.close();
  });
  dialog.addEventListener("close", () => {
    mounted.destroy();
    dialog.remove();
    if (!doc.activeElement || doc.activeElement === doc.body) {
      opener.focus({preventScroll: true});
    }
  });
};

// --- The height limit -----------------------------------------------------------------------

// Capping a diagram's width at the limit times its aspect ratio scales it down with its
// proportions kept, since its height is auto. styles.css registers --fran-diagram-cap as a
// length, huge for none, so the cap is always valid and follows the option live. The
// fallback, the same as styles.css's initial-value, covers a render before styles.css applies.
const capOf = (svg) => svg ? getComputedStyle(svg).getPropertyValue("--fran-diagram-cap").trim() : "";
const fitHeight = (svg, w, h) => {
  if (!svg || !(w > 0 && h > 0)) return;
  const max = `calc(var(--fran-diagram-cap, 100000px) * ${+(w / h).toFixed(4)})`;
  svg.style.maxWidth = `min(${svg.style.maxWidth || "100%"}, ${max})`;
};

// --- Mermaid blocks in a note ---------------------------------------------------------------

// Diagram sources compared line by line without surrounding whitespace: Obsidian hands over
// a block's text without the indentation of a list item or the markers of a quote
const normalize = (text) => text.split("\n").map((line) => line.trim()).join("\n").trim();

// A note's Mermaid blocks, in order, including those in lists, quotes and callouts: each one's
// source, normalized, and the line (from 0) its opening fence is on
const mermaidBlocks = (text) => {
  const blocks = [];
  let fence, lines, start;
  for (const [i, raw] of text.split("\n").entries()) {
    const line = raw.replace(/^(\s*>)+/, "");
    if (!fence) {
      const open = /^\s*(`{3,}|~{3,})\s*mermaid\b/i.exec(line);
      if (open) [fence, lines, start] = [open[1], [], i];
    } else if (new RegExp(`^\\s*${fence[0]}{${fence.length},}\\s*$`).test(line)) {
      blocks.push({text: normalize(lines.join("\n")), line: start});
      fence = undefined;
    } else {
      lines.push(line);
    }
  }
  return blocks;
};

// --- A diagram ------------------------------------------------------------------------------

// One diagram: a box with Pele's drawing and the buttons, which takes the place of Obsidian's
// placeholder. Its fields keep the names mdread's code reads (text, doc, el, wrap, w, h), so
// exportSvg, download and expand stay mdread's.
class Diagram {
  constructor(plugin, text, doc) {
    this.plugin = plugin;
    this.text = text;
    this.doc = doc;
    this.el = doc.createElement("div"); // Pele draws in it
    this.el.className = "fran-diagram-pele";

    const open = () => expand(this, expandButton, plugin.pele, plugin.locate(this).n);
    const expandButton = button(doc, "Expand diagram", svgExpand, open);
    const tools = doc.createElement("div");
    tools.className = "fran-diagram-tools";
    tools.append(
      copyButton(doc, "fran-tool", "Copy diagram source", () => this.text),
      button(doc, "Download SVG", svgDownload, () => download(this, plugin.locate(this))),
      expandButton
    );
    this.wrap = doc.createElement("div");
    this.wrap.className = "fran-diagram";
    this.wrap.append(this.el, tools);

    // Double-clicking the diagram expands it too, but not on the buttons or Pele's zoom
    // controls. Capturing, so Pele's own double-click zoom never sees it; and the double-click
    // doesn't select a word of the diagram's text.
    const onControls = (e) => e.target.closest?.(".fran-diagram-tools, .pele-zoom");
    this.wrap.addEventListener("dblclick", (e) => {
      if (onControls(e)) return;
      e.stopPropagation();
      e.preventDefault();
      open();
    }, true);
    this.wrap.addEventListener("mousedown", (e) => {
      if (e.detail > 1 && !onControls(e)) e.preventDefault();
    });

    // Pele disables + or - at its zoom limits and hides its reset button at the fit, and a
    // focused button it does that to loses the focus to the page, without an event. The zoom
    // row, shown on keyboard focus, would then fade out under the user, so when that button
    // had keyboard focus, the row's first button still in use takes it. After a mouse click
    // the focus goes, as before, so Space still scrolls the note. Capturing, to see the focus
    // before Pele's own click handler runs. Pele hides reset with display: none, which leaves
    // it no boxes.
    const usable = (btn) => !btn.disabled && btn.getClientRects().length > 0;
    this.wrap.addEventListener("click", (e) => {
      const btn = e.target.closest?.(".pele-zoom > button");
      if (!btn?.matches(":focus-visible")) return;
      setTimeout(() => {
        if (!usable(btn)) [...btn.parentElement.children].find(usable)?.focus();
      });
    }, true);
  }

  // Puts the box where the placeholder is and has Pele draw in it. mount() measures text with
  // the box's font, fits the diagram to its width, and offers zoom when the diagram shows
  // smaller than its natural size: too wide, or capped by the height limit.
  mount(pending) {
    pending.replaceWith(this.wrap);
    try {
      this.mounted = this.plugin.pele.mount(this.el, this.text, {
        onRender: (result) => this.rendered(result),
        onError: (err) => {
          if (this.wrap.isConnected) this.fail(err);
        }
      });
    } catch (err) {
      this.fail(err);
    }
  }

  // After every drawing: the first time before mount() returns, so before the zoom exists;
  // later (a resize, new fonts) after it, when the zoom needs a refresh to see the cap
  rendered(result) {
    this.w = result.width;
    this.h = result.height;
    const svg = svgOf(this);
    fitHeight(svg, this.w, this.h);
    this.cap = capOf(svg);
    this.mounted?.zoom?.refresh();
  }

  // After any style change. A new height limit resizes the diagram through CSS, without a
  // redraw, so Pele's zoom has to look again to offer itself, or stop. Only when the limit
  // changed, since a refresh also undoes the user's zoom.
  styleChanged() {
    const cap = capOf(svgOf(this));
    if (!this.mounted?.zoom || !cap || cap === this.cap) return;
    this.cap = cap;
    this.mounted.zoom.refresh();
  }

  // A diagram Pele can't draw keeps its source under a note, with a copy button
  fail(err) {
    const {doc} = this;
    const note = doc.createElement("p");
    note.className = "fran-diagram-error";
    note.textContent = `Pele can't render this diagram: ${err?.message || err}`;
    const pre = doc.createElement("pre");
    const code = doc.createElement("code");
    code.textContent = this.text;
    pre.append(code, copyButton(doc, "copy-code-button", "Copy", () => this.text));
    this.wrap.replaceWith(note, pre);
  }
}

// --- The plugin -----------------------------------------------------------------------------

module.exports = class FranDiagrams extends Plugin {
  async onload() {
    this.observers = new Map(); // document -> MutationObserver, one per window
    this.diagrams = new WeakMap(); // .fran-diagram box -> its Diagram
    this.sections = new WeakMap(); // reading view section -> its post-processor context
    this.pele = await this.loadPele();
    await this.hookMermaid();

    this.registerMarkdownPostProcessor((el, ctx) => this.sections.set(el, ctx));
    this.observe(document);
    this.registerEvent(this.app.workspace.on("window-open", (_, win) => this.observe(win.document)));
    this.registerEvent(this.app.workspace.on("window-close", (_, win) => this.unobserve(win.document)));
    // Style Settings fires css-change after it sets a value, such as a new height limit
    this.registerEvent(this.app.workspace.on("css-change", () => {
      for (const doc of this.observers.keys()) {
        for (const wrap of doc.querySelectorAll(".fran-diagram")) {
          this.diagrams.get(wrap)?.styleChanged();
        }
      }
    }));
    // Notes open before the plugin loaded show mermaid.js's drawings; draw them again
    this.app.workspace.onLayoutReady(() => this.redraw(".mermaid > svg"));
  }

  onunload() {
    for (const doc of [...this.observers.keys()]) {
      for (const dialog of doc.querySelectorAll("dialog.fran-dialog")) dialog.close();
      this.unobserve(doc);
    }
    // Give the notes showing Pele's drawings back to mermaid.js
    this.redraw(".fran-diagram, .fran-diagram-pending");
  }

  // The global build declares `var pele`; run it in a function and keep that
  async loadPele() {
    const code = await this.app.vault.adapter.read(`${this.manifest.dir}/pele.global.js`);
    return new Function(`${code}\n;return pele;`)();
  }

  // Obsidian draws a diagram, in reading view and Live Preview alike, by calling the global
  // mermaid.render(id, source, container) and putting the .svg of its result into a new
  // <div class="mermaid">. This render returns a placeholder naming the source instead, and
  // the observers put a Diagram in its place once Obsidian inserts it. Keys are unique to
  // this load of the plugin, so a placeholder left over from before a reload can't pick up
  // another diagram's source.
  async hookMermaid() {
    this.sources = new Map(); // placeholder key -> diagram source
    this.keyPrefix = `${Date.now().toString(36)}-`;
    this.nextKey = 0;
    const mermaid = await loadMermaid();
    const render = mermaid.render;
    mermaid.render = async (id, text) => {
      const key = this.keyPrefix + ++this.nextKey;
      this.sources.set(key, text);
      return {svg: `<div class="fran-diagram-pending" data-fran-diagram="${key}"></div>`};
    };
    this.register(() => (mermaid.render = render));
  }

  redraw(selector) {
    this.app.workspace.iterateAllLeaves((leaf) => {
      if (leaf.view instanceof MarkdownView && leaf.view.containerEl.querySelector(selector)) {
        leaf.rebuildView();
      }
    });
  }

  // Puts a Diagram in every placeholder that appears in this window's document
  observe(doc) {
    const attachAll = (root) => {
      for (const el of root.querySelectorAll(".fran-diagram-pending")) this.attach(el);
    };
    const observer = new MutationObserver((records) => {
      for (const record of records) {
        for (const node of record.addedNodes) {
          if (node.nodeType !== Node.ELEMENT_NODE) continue;
          if (node.classList.contains("fran-diagram-pending")) this.attach(node);
          else if (node.firstElementChild) attachAll(node);
        }
      }
    });
    observer.observe(doc.body, {childList: true, subtree: true});
    this.observers.set(doc, observer);
    attachAll(doc.body);
  }

  unobserve(doc) {
    this.observers.get(doc)?.disconnect();
    this.observers.delete(doc);
  }

  attach(pending) {
    const key = pending.getAttribute("data-fran-diagram");
    const text = this.sources.get(key);
    this.sources.delete(key);
    if (text === undefined) return;
    const diagram = new Diagram(this, text, pending.ownerDocument);
    this.diagrams.set(diagram.wrap, diagram);
    diagram.mount(pending);
  }

  // The note a diagram is in, and its number there among the note's Mermaid blocks, for the
  // downloaded file's name and the expanded view's label. Of several blocks with its source,
  // it's the one on the lines it's drawn from. A diagram outside a note view (a hover
  // preview) is "diagram", number 1.
  locate(diagram) {
    let view;
    this.app.workspace.iterateAllLeaves((leaf) => {
      if (!view && leaf.view instanceof MarkdownView && leaf.view.containerEl.contains(diagram.wrap)) {
        view = leaf.view;
      }
    });
    const base = (view?.file?.basename || "diagram").replace(/[\\/:*?"<>|\x00-\x1f]/g, "-");
    const blocks = mermaidBlocks(view?.getViewData() ?? "");
    const text = normalize(diagram.text);
    const lines = this.lines(diagram.wrap);
    const here = (b) => lines && b.line >= lines.start && b.line <= lines.end;
    let i = blocks.findIndex((b) => b.text === text && here(b));
    if (i < 0) i = blocks.findIndex((b) => b.text === text);
    return {base, n: i + 1 || 1};
  }

  // The lines of its note (from 0) a diagram is drawn from, or undefined where they aren't
  // known. In Live Preview, they're the ones the editor's widget around it replaces. In
  // reading view, they're its section's, which only a post-processor's context can tell.
  lines(wrap) {
    const content = wrap.closest(".cm-content");
    if (content) {
      const cm = EditorView.findFromDOM(content);
      if (!cm) return;
      const {from, to} = cm.lineBlockAt(cm.posAtDOM(wrap));
      return {start: cm.state.doc.lineAt(from).number - 1, end: cm.state.doc.lineAt(to).number - 1};
    }
    for (let el = wrap.parentElement; el; el = el.parentElement) {
      const info = this.sections.get(el)?.getSectionInfo(el);
      if (info) return {start: info.lineStart, end: info.lineEnd};
    }
  }
};
