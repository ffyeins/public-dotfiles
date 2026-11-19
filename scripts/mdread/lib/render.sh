# shellcheck shell=bash disable=SC2034,SC2154
# Shared rendering for mdread and mdtohtml. Sourced by both scripts, not run directly.
# Globals flow both ways, hence the shellcheck exclusions: callers define `prog`, `VERSION`
# and `usage`; mdr_parse_args sets `theme`, `mermaid`, `max_height`, `force`, `files` and
# `action` for them.

# Pinned CDN assets. After bumping a version, refresh its integrity hash with:
#   curl -s <url> | openssl dgst -sha384 -binary | openssl base64 -A
# beautiful-mermaid comes from esm.sh without SRI; starry-night and hast-util-to-dom are
# pinned in their module script below (esm.sh, no SRI).
MDR_BEAUTIFUL_URL="https://esm.sh/beautiful-mermaid@1.1.3?bundle"
MDR_CSS_BASE="https://cdn.jsdelivr.net/npm/github-markdown-css@5.9.0"
MDR_CSS_SRI_DARK="sha384-nlth4oyFjBlAziFH2oypWWsE00W7j/6uVR4/Fz1++oPhaqeF8LujWsaX3ChXZw/1"
MDR_CSS_SRI_LIGHT="sha384-4+yp2IvYOqcJcR9WCGb7S9CwgoCBD4qxmEMxnXjwpM54P0M/z05F3YkC+NFunWrc"
MDR_MERMAID_URL="https://cdn.jsdelivr.net/npm/mermaid@11.17.2/dist/mermaid.min.js"
MDR_MERMAID_SRI="sha384-EOXBFmc3gx5mb+vn0vPvvGqACToJD24hhacX5Yx+8NUUQrHIle/Qi5Bg9o3zKwW2"
MDR_PELE_URL="https://cdn.jsdelivr.net/npm/pele@1.13.0/dist/pele.global.js"
MDR_PELE_SRI="sha384-vDPV1LDXGIwjU5/gMUtHbn/WAmwRmOgkQpiq+Rm4d/BPTsdfpIUpvi2xVET6z85W"
MDR_MATHJAX_URL="https://cdn.jsdelivr.net/npm/mathjax@3.2.2/es5/tex-mml-chtml.js"
MDR_MATHJAX_SRI="sha384-Wuix6BuhrWbjDBs24bXrjf4ZQ5aFeFWBuKkFekO2t8xFU0iNaLQfp2K6/1Nxveei"

mdr_usage_error() {
  echo "$prog: $1" >&2
  usage >&2
  exit 2
}

mdr_set_mermaid() {
  case $1 in
    pele|beautiful-mermaid|mermaid) mermaid=$1 ;;
    *) mdr_usage_error "unknown mermaid renderer: '$1' (pele, beautiful-mermaid or mermaid)" ;;
  esac
}

# Diagrams taller than this are scaled down: a positive number of px (unit optional) or vh,
# or none. The value is validated here, so it can go into the page's CSS as is.
mdr_set_max_height() {
  local valid='^([0-9]+|[0-9]*\.[0-9]+)(px|vh)?$' zero='^[0.]+(px|vh)?$'
  if [[ $1 == none ]]; then
    max_height=none
  elif [[ $1 =~ $valid && ! $1 =~ $zero ]]; then
    max_height=$1
    if [[ $1 == *[0-9] ]]; then max_height+=px; fi
  else
    mdr_usage_error "invalid diagram height: '$1' (a size in px or vh, such as 600px or 80vh, or none)"
  fi
}

# Parse the options both commands share. Sets theme, mermaid (the diagram renderer),
# max_height, force, files and action (run, help or version). $1 is 1 when --force is
# allowed (mdtohtml only).
mdr_parse_args() {
  local allow_force=$1
  shift
  theme=dark
  mermaid=pele
  max_height=80vh
  force=0
  action=run
  files=()
  while [[ $# -gt 0 ]]; do
    case $1 in
      -h|--help) action=help; return ;;
      -v|--version) action=version; return ;;
      --light) theme=light ;;
      --dark) theme=dark ;;
      --mermaid=*) mdr_set_mermaid "${1#*=}" ;;
      --mermaid)
        [[ $# -ge 2 ]] || mdr_usage_error "--mermaid needs a renderer name"
        shift
        mdr_set_mermaid "$1"
        ;;
      --max-diagram-height=*) mdr_set_max_height "${1#*=}" ;;
      --max-diagram-height)
        [[ $# -ge 2 ]] || mdr_usage_error "--max-diagram-height needs a size"
        shift
        mdr_set_max_height "$1"
        ;;
      -f|--force)
        [[ $allow_force == 1 ]] || mdr_usage_error "unknown option: $1"
        force=1
        ;;
      --) shift; files+=("$@"); return ;;
      -?*) mdr_usage_error "unknown option: $1" ;;
      *) files+=("$1") ;;
    esac
    shift
  done
}

mdr_require_deps() {
  if ! command -v comrak >/dev/null 2>&1; then
    echo "$prog: comrak is required (brew install comrak)" >&2
    exit 1
  fi
}

# sed rather than ${var//…}: bash 5.2 treats & in the replacement as the matched text
mdr_escape_html() {
  printf '%s' "$1" | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g' -e 's/"/\&quot;/g'
}

# file:// URL for an absolute directory, with a trailing slash so it works as <base href>
mdr_dir_url() {
  local p=$1
  p=${p//[%]/%25}
  p=${p//[ ]/%20}
  p=${p//[#]/%23}
  p=${p//[?]/%3F}
  printf 'file://%s/' "${p%/}"
}

# GFM's tagfilter: neutralize raw-HTML tags GitHub never passes through. comrak deprecated
# its own tagfilter extension, so apply it to the output. Tags inside code are already
# escaped by then, so only raw HTML matches.
mdr_tagfilter() {
  sed -E 's#<(/?)([Tt][Ii][Tt][Ll][Ee]|[Tt][Ee][Xx][Tt][Aa][Rr][Ee][Aa]|[Ss][Tt][Yy][Ll][Ee]|[Xx][Mm][Pp]|[Ii][Ff][Rr][Aa][Mm][Ee]|[Nn][Oo][Ee][Mm][Bb][Ee][Dd]|[Nn][Oo][Ff][Rr][Aa][Mm][Ee][Ss]|[Ss][Cc][Rr][Ii][Pp][Tt]|[Pp][Ll][Aa][Ii][Nn][Tt][Ee][Xx][Tt])([[:space:]/>]|$)#\&lt;\1\2\3#g'
}

# GitHub shows YAML front matter as a table; comrak drops it from the body. Flat
# `key: value` blocks become a one-row table, anything else a YAML code block. Detection
# mirrors comrak: exact `---` lines around a non-empty block at the top of the file.
mdr_frontmatter() {
  LC_ALL=C awk '
    function esc(s) {
      gsub(/&/, "\\&amp;", s); gsub(/</, "\\&lt;", s); gsub(/>/, "\\&gt;", s)
      return s
    }
    { sub(/\r$/, "") }
    NR == 1 {
      sub(/^\357\273\277/, "")
      if ($0 != "---") exit
      inside = 1
      next
    }
    inside && $0 == "---" { closed = 1; exit }
    inside { lines[++n] = $0 }
    END {
      if (!closed || n == 0) exit
      flat = 1
      for (i = 1; i <= n; i++) {
        if (lines[i] ~ /^[ \t]*(#.*)?$/) continue
        if (lines[i] !~ /^[A-Za-z0-9_-]+:[ \t]*[^ \t]/) { flat = 0; break }
      }
      if (!flat) {
        printf "<pre><code class=\"language-yaml\">"
        for (i = 1; i <= n; i++) printf "%s\n", esc(lines[i])
        printf "</code></pre>\n"
        exit
      }
      k = 0
      for (i = 1; i <= n; i++) {
        if (lines[i] ~ /^[ \t]*(#.*)?$/) continue
        c = index(lines[i], ":")
        v = substr(lines[i], c + 1)
        sub(/^[ \t]+/, "", v); sub(/[ \t]+$/, "", v)
        if (v ~ /^".*"$/ || v ~ /^\047.*\047$/) v = substr(v, 2, length(v) - 2)
        keys[++k] = substr(lines[i], 1, c - 1)
        vals[k] = v
      }
      printf "<table>\n<thead>\n<tr>"
      for (i = 1; i <= k; i++) printf "<th>%s</th>", esc(keys[i])
      printf "</tr>\n</thead>\n<tbody>\n<tr>"
      for (i = 1; i <= k; i++) printf "<td>%s</td>", esc(vals[i])
      printf "</tr>\n</tbody>\n</table>\n"
    }
  '
}

# Render one markdown file to a complete HTML page on stdout.
# Usage: mdr_render_html <file> <theme> <mermaid renderer> <max diagram height> [base_url]
# base_url (mdread only) becomes <base href>, so relative images and links resolve against
# the source directory; the page script then keeps #links on the page itself.
mdr_render_html() {
  local file=$1 theme=$2 renderer=$3 max_height=$4 base_url=${5:-}
  local body frontmatter title nonce csp css_file css_sri theme_vars mermaid_theme pele_vars libs

  body=$(comrak --config-file none --unsafe \
    -e table,strikethrough,autolink,tasklist,footnotes,alerts,math-dollars,math-code \
    --tasklist-classes --gemoji --header-id-prefix '' \
    --front-matter-delimiter '---' --syntax-highlighting none < "$file") || return 1
  body=$(printf '%s\n' "$body" | mdr_tagfilter) || return 1
  frontmatter=$(mdr_frontmatter < "$file") || return 1
  title=$(mdr_escape_html "${file##*/}")
  nonce=$(od -An -tx1 -N16 /dev/urandom | tr -d ' \n')

  case $theme in
    light)
      css_file=github-markdown-light.css
      css_sri=$MDR_CSS_SRI_LIGHT
      mermaid_theme=default
      theme_vars='--mdr-page-bg: #ffffff; --mdr-diagram-bg: #f6f8fa; --mdr-btn-bg: #ffffff; --mdr-btn-border: #d1d9e0; --mdr-btn-fg: #818b98; --mdr-btn-text-fg: #59636e; --mdr-btn-hover-bg: #eff2f5; --mdr-btn-hover-fg: #1f2328; --mdr-ok: #1a7f37; --mdr-focus: #0969da; --mdr-error: #d1242f; --mdr-backdrop: #c8d1da66;'
      pele_vars='--pele-bg: #f6f8fa; --pele-fg: #1f2328; --pele-line: #1f2328; --pele-muted: #59636e; --pele-surface: #ffffff; --pele-surface-alt: #eff2f5; --pele-border: #d1d9e0; --pele-accent: #0969da; --pele-error: #d1242f; --pele-critical: #d1242f;'
      ;;
    *)
      css_file=github-markdown-dark.css
      css_sri=$MDR_CSS_SRI_DARK
      mermaid_theme=dark
      theme_vars='--mdr-page-bg: #0d1117; --mdr-diagram-bg: #151b23; --mdr-btn-bg: #212830; --mdr-btn-border: #3d444d; --mdr-btn-fg: #9198a1; --mdr-btn-text-fg: #9198a1; --mdr-btn-hover-bg: #262c36; --mdr-btn-hover-fg: #f0f6fc; --mdr-ok: #3fb950; --mdr-focus: #1f6feb; --mdr-error: #f85149; --mdr-backdrop: #21283066;'
      pele_vars='--pele-bg: #151b23; --pele-fg: #f0f6fc; --pele-line: #f0f6fc; --pele-muted: #9198a1; --pele-surface: #212830; --pele-surface-alt: #2a313c; --pele-border: #3d444d; --pele-accent: #4493f8; --pele-error: #f85149; --pele-critical: #f85149;'
      ;;
  esac
  # Pele's defaults are light; give its diagrams GitHub's colors for the theme. Diagrams sit on
  # --mdr-diagram-bg (GitHub's code block color), so that's Pele's background, and its node
  # fill is another shade.
  if [[ $renderer != mermaid ]]; then theme_vars+=" $pele_vars"; fi
  # The diagram script caps each diagram's width at this height times its aspect ratio
  if [[ $max_height != none ]]; then theme_vars+=" --mdr-diagram-max-height: $max_height;"; fi

  # Only scripts carrying this run's nonce execute, so script in the markdown's raw HTML
  # (inline handlers, javascript: links) can't. strict-dynamic lets our scripts load their
  # own dependencies; wasm-unsafe-eval is for starry-night's regex engine.
  csp="default-src 'none'; script-src 'nonce-$nonce' 'strict-dynamic' 'wasm-unsafe-eval'; style-src 'unsafe-inline' https://cdn.jsdelivr.net; font-src https://cdn.jsdelivr.net data:; img-src * data: blob: file:; media-src * data: blob: file:; connect-src https://esm.sh https://cdn.jsdelivr.net; base-uri 'none'; form-action 'none'; object-src 'none'"

  printf '<!DOCTYPE html>\n'
  if [[ -n $base_url ]]; then
    printf '<html lang="en" data-theme="%s" data-preview>\n<head>\n<meta charset="utf-8">\n' "$theme"
    # Before the CSP: base-uri 'none' then blocks any <base> coming from the markdown
    printf '<base href="%s">\n' "$(mdr_escape_html "$base_url")"
  else
    printf '<html lang="en" data-theme="%s">\n<head>\n<meta charset="utf-8">\n' "$theme"
  fi
  printf '<meta http-equiv="Content-Security-Policy" content="%s">\n' "$csp"
  printf '<meta name="viewport" content="width=device-width, initial-scale=1">\n'
  printf '<meta name="generator" content="%s %s">\n' "$prog" "$VERSION"
  printf '<title>%s</title>\n' "$title"
  printf '<link rel="stylesheet" href="%s/%s" integrity="%s" crossorigin="anonymous">\n' \
    "$MDR_CSS_BASE" "$css_file" "$css_sri"
  printf '<style>\n:root { %s }\n' "$theme_vars"
  cat <<'CSS'
body { margin: 0; background: var(--mdr-page-bg); }
.markdown-body { box-sizing: border-box; min-width: 200px; max-width: 980px; margin: 0 auto; padding: 32px 28px; }
@media (max-width: 767px) { .markdown-body { padding: 15px; } }
.copy-btn, .mdr-tool {
  padding: 4px; line-height: 1;
  color: var(--mdr-btn-fg); background: var(--mdr-btn-bg);
  border: 1px solid var(--mdr-btn-border); border-radius: 6px; cursor: pointer;
}
.copy-btn:hover, .mdr-tool:hover { color: var(--mdr-btn-hover-fg); background: var(--mdr-btn-hover-bg); }
.copy-btn.copied, .mdr-tool.copied { color: var(--mdr-ok); }
/* github-markdown-css leaves buttons the browser's focus ring */
.copy-btn:focus-visible, .mdr-tool:focus-visible, .mdr-zoom > button:focus-visible,
.mdr-diagram .pele-zoom > button:focus-visible {
  outline: 2px solid var(--mdr-focus); outline-offset: -2px;
}
.code-wrapper, .mdr-diagram { position: relative; }
.copy-btn, .mdr-diagram-tools {
  position: absolute; top: 8px; right: 8px; z-index: 1; opacity: 0; transition: opacity 0.15s;
}
.code-wrapper:hover > .copy-btn, .copy-btn:focus-visible,
.mdr-diagram:hover > .mdr-diagram-tools, .mdr-diagram-tools:has(:focus-visible) { opacity: 1; }
/* A code block that scrolls sideways fades out at each edge it has more to scroll to. The fade
   spans the text lines only, so it stays off the corners and the horizontal scrollbar. */
.code-wrapper::before, .code-wrapper::after {
  content: ""; position: absolute; top: 1rem; bottom: 1rem; width: 16px;
  pointer-events: none; opacity: 0; transition: opacity 0.15s;
}
.code-wrapper::before { left: 0; background: linear-gradient(to right, var(--mdr-diagram-bg), transparent); }
.code-wrapper::after { right: 0; background: linear-gradient(to left, var(--mdr-diagram-bg), transparent); }
.code-wrapper.mdr-more-left::before, .code-wrapper.mdr-more-right::after { opacity: 1; }
/* Tables have striped rows rather than one background, so a mask fades them into the page */
.markdown-body table.mdr-more-left { mask-image: linear-gradient(to right, transparent, #000 16px); }
.markdown-body table.mdr-more-right { mask-image: linear-gradient(to left, transparent, #000 16px); }
.markdown-body table.mdr-more-left.mdr-more-right {
  mask-image: linear-gradient(to right, transparent, #000 16px, #000 calc(100% - 16px), transparent);
}
.mdr-diagram-tools { display: flex; gap: 4px; }
.mdr-diagram {
  margin-bottom: 16px; padding: 16px; background: var(--mdr-diagram-bg); border-radius: 6px;
  /* Pele's zoom controls go bottom right, under the diagram buttons, lined up with them */
  --pele-zoom-top: auto; --pele-zoom-bottom: 8px; --pele-zoom-right: 8px;
}
/* ... in a row rather than Pele's column (inline styles, hence !important): [reset - +]. Pele
   shows its reset button, after + and -, once zoomed in; reversed, the row grows to the left, so
   + and - stay under the cursor. A diagram too short for the diagram buttons above the zoom row
   gets the height they need, with the diagram centered in it: 8px + 28px buttons + 8px + 30px
   zoom row + 8px, less the 32px of padding. They take the diagram buttons' colors: their inline
   styles read these --pele-* variables, but the buttons' transparent background and inherited
   color are inline too, hence !important on hover. Pele disables + or - at its zoom limits. Like
   the diagram buttons, they show on hover or with keyboard focus, the zoomable diagram's too. */
.mdr-diagram .pele-zoom {
  flex-direction: row-reverse !important;
  --pele-bg: var(--mdr-btn-bg); --pele-fg: var(--mdr-btn-fg); --pele-border: var(--mdr-btn-border);
  --pele-radius: 6px;
  opacity: 0; transition: opacity 0.15s;
}
.mdr-diagram:hover .pele-zoom, .mdr-diagram:has(:focus-visible) .pele-zoom { opacity: 1; }
.mdr-diagram .pele-zoom > button:hover:not(:disabled) {
  color: var(--mdr-btn-hover-fg) !important; background: var(--mdr-btn-hover-bg) !important;
}
.mdr-diagram > .pele-diagram:has(> .pele-zoom:not([hidden])) {
  display: grid; align-content: center; min-height: 50px;
}
/* Pele's container has the padding instead: zoomed in, Pele draws over its container's padding,
   so the zoomed diagram reaches the box's edges, clipped to its rounded corners. The clip would
   hide the focus ring Pele's zoomable SVG gets outside it, so the ring goes inside. */
.mdr-diagram:has(> .pele-diagram) { padding: 0; overflow: clip; }
.mdr-diagram > .pele-diagram { padding: 16px; }
.mdr-diagram > .pele-diagram > svg:focus-visible {
  outline: 2px solid var(--mdr-focus); outline-offset: -2px;
}
.beautiful-mermaid > svg, .pele-diagram > svg, .mermaid-diagram > svg {
  display: block; max-width: 100%; height: auto; margin: 0 auto;
}
.mdr-diagram-error { color: var(--mdr-error); }
.mdr-dialog {
  box-sizing: border-box; width: calc(100vw - 48px); height: calc(100vh - 48px);
  max-width: none; max-height: none; padding: 0; overflow: hidden;
  color: inherit; background: var(--mdr-diagram-bg);
  border: 1px solid var(--mdr-btn-border); border-radius: 12px;
}
/* github-markdown-css zeroes the last child's bottom margin, which would pin it to the bottom */
.markdown-body > .mdr-dialog { margin: auto !important; }
/* ::backdrop inherits custom properties only since 2024 (Chrome 122, Safari 17.4, Firefox 120) */
.mdr-dialog::backdrop { background: var(--mdr-backdrop, #21283066); }
.mdr-dialog > .mdr-tool { position: absolute; top: 12px; right: 12px; z-index: 1; }
/* Dragging scrolls it to pan; the zoom sets the diagram's size */
.mdr-dialog-view {
  box-sizing: border-box; display: flex; width: 100%; height: 100%;
  padding: 48px 24px; overflow: auto; overflow-anchor: none;
  cursor: grab; user-select: none; -webkit-user-select: none;
}
.mdr-dialog-view.mdr-panning { cursor: grabbing; }
.mdr-dialog-view:focus { outline: none; }
.mdr-dialog-view > * { flex: none; margin: auto; }
.mdr-dialog-view > svg, .mdr-dialog-view > .pele-diagram > svg { max-width: none; }
.mdr-zoom {
  position: absolute; right: 12px; bottom: 12px; z-index: 1; display: flex; align-items: center;
  background: var(--mdr-btn-bg); border: 1px solid var(--mdr-btn-border); border-radius: 6px;
}
.mdr-zoom > button {
  padding: 4px 6px; font: inherit; line-height: 1; color: var(--mdr-btn-fg);
  background: none; border: 0; border-radius: 5px; cursor: pointer;
}
.mdr-zoom > button:hover { color: var(--mdr-btn-hover-fg); background: var(--mdr-btn-hover-bg); }
.mdr-zoom > button[aria-disabled="true"] { opacity: 0.4; cursor: default; background: none; }
/* Text, so it keeps 4.5:1 where the light theme's icon gray is lighter */
.mdr-zoom > .mdr-zoom-level {
  min-width: 5ch; padding: 4px 2px; font-size: 12px; font-variant-numeric: tabular-nums;
  color: var(--mdr-btn-text-fg);
}
html:has(.mdr-dialog[open]) { overflow: hidden; }
</style>
</head>
<body>
<div class="markdown-body">
CSS
  if [[ -n $frontmatter ]]; then printf '%s\n' "$frontmatter"; fi
  printf '%s\n</div>\n' "$body"

  printf '<script nonce="%s">\n' "$nonce"
  cat <<'JS'
(function () {
  var root = document.documentElement;
  var theme = root.getAttribute("data-theme");
  var body = document.querySelector(".markdown-body");

  // Theme-specific images: GitHub's #gh-dark-mode-only / #gh-light-mode-only suffixes, and
  // <picture> sources keyed on prefers-color-scheme (which follows the OS, not --light/--dark)
  var other = theme === "dark" ? "light" : "dark";
  body.querySelectorAll('img[src$="#gh-' + other + '-mode-only"]').forEach(function (img) {
    img.remove();
  });
  body.querySelectorAll("picture > source[media]").forEach(function (source) {
    var m = /prefers-color-scheme:\s*(dark|light)/.exec(source.getAttribute("media"));
    if (!m) return;
    if (m[1] === theme) source.setAttribute("media", "all");
    else source.remove();
  });

  // Heading anchors: comrak emits an empty a.anchor; the stylesheet draws the link icon
  // into .octicon-link on hover
  body.querySelectorAll("a.anchor").forEach(function (a) {
    var icon = document.createElement("span");
    icon.className = "octicon octicon-link";
    a.appendChild(icon);
  });

  // Alert icons: comrak emits GitHub's alert markup without the octicons
  var icons = {
    note: '<svg class="octicon mr-2" viewBox="0 0 16 16" width="16" height="16" fill="currentColor" aria-hidden="true"><path d="M0 8a8 8 0 1 1 16 0A8 8 0 0 1 0 8m8-6.5a6.5 6.5 0 1 0 0 13 6.5 6.5 0 0 0 0-13M6.5 7.75A.75.75 0 0 1 7.25 7h1a.75.75 0 0 1 .75.75v2.75h.25a.75.75 0 0 1 0 1.5h-2a.75.75 0 0 1 0-1.5h.25v-2h-.25a.75.75 0 0 1-.75-.75M8 6a1 1 0 1 1 0-2 1 1 0 0 1 0 2"/></svg>',
    tip: '<svg class="octicon mr-2" viewBox="0 0 16 16" width="16" height="16" fill="currentColor" aria-hidden="true"><path d="M8 1.5c-2.363 0-4 1.69-4 3.75 0 .984.424 1.625.984 2.304l.214.253c.223.264.47.556.673.848.284.411.537.896.621 1.49a.75.75 0 0 1-1.484.211c-.04-.282-.163-.547-.37-.847a8 8 0 0 0-.542-.68c-.084-.1-.173-.205-.268-.32C3.201 7.75 2.5 6.766 2.5 5.25 2.5 2.31 4.863 0 8 0s5.5 2.31 5.5 5.25c0 1.516-.701 2.5-1.328 3.259-.095.115-.184.22-.268.319-.207.245-.383.453-.541.681-.208.3-.33.565-.37.847a.75.75 0 0 1-1.485-.212c.084-.593.337-1.078.621-1.489.203-.292.45-.584.673-.848l.213-.253c.561-.679.985-1.32.985-2.304 0-2.06-1.637-3.75-4-3.75M5.75 12h4.5a.75.75 0 0 1 0 1.5h-4.5a.75.75 0 0 1 0-1.5M6 15.25a.75.75 0 0 1 .75-.75h2.5a.75.75 0 0 1 0 1.5h-2.5a.75.75 0 0 1-.75-.75"/></svg>',
    important: '<svg class="octicon mr-2" viewBox="0 0 16 16" width="16" height="16" fill="currentColor" aria-hidden="true"><path d="M0 1.75C0 .784.784 0 1.75 0h12.5C15.216 0 16 .784 16 1.75v9.5A1.75 1.75 0 0 1 14.25 13H8.06l-2.573 2.573A1.458 1.458 0 0 1 3 14.543V13H1.75A1.75 1.75 0 0 1 0 11.25Zm1.75-.25a.25.25 0 0 0-.25.25v9.5c0 .138.112.25.25.25h2a.75.75 0 0 1 .75.75v2.19l2.72-2.72a.749.749 0 0 1 .53-.22h6.5a.25.25 0 0 0 .25-.25v-9.5a.25.25 0 0 0-.25-.25Zm7 2.25v2.5a.75.75 0 0 1-1.5 0v-2.5a.75.75 0 0 1 1.5 0M9 9a1 1 0 1 1-2 0 1 1 0 0 1 2 0"/></svg>',
    warning: '<svg class="octicon mr-2" viewBox="0 0 16 16" width="16" height="16" fill="currentColor" aria-hidden="true"><path d="M6.457 1.047c.659-1.234 2.427-1.234 3.086 0l6.082 11.378A1.75 1.75 0 0 1 14.082 15H1.918a1.75 1.75 0 0 1-1.543-2.575Zm1.763.707a.25.25 0 0 0-.44 0L1.698 13.132a.25.25 0 0 0 .22.368h12.164a.25.25 0 0 0 .22-.368Zm.53 3.996v2.5a.75.75 0 0 1-1.5 0v-2.5a.75.75 0 0 1 1.5 0M9 11a1 1 0 1 1-2 0 1 1 0 0 1 2 0"/></svg>',
    caution: '<svg class="octicon mr-2" viewBox="0 0 16 16" width="16" height="16" fill="currentColor" aria-hidden="true"><path d="M4.47.22A.749.749 0 0 1 5 0h6c.199 0 .389.079.53.22l4.25 4.25c.141.14.22.331.22.53v6a.749.749 0 0 1-.22.53l-4.25 4.25A.749.749 0 0 1 11 16H5a.749.749 0 0 1-.53-.22L.22 11.53A.749.749 0 0 1 0 11V5c0-.199.079-.389.22-.53Zm.84 1.28L1.5 5.31v5.38l3.81 3.81h5.38l3.81-3.81V5.31L10.69 1.5ZM8 4a.75.75 0 0 1 .75.75v3.5a.75.75 0 0 1-1.5 0v-3.5A.75.75 0 0 1 8 4m0 8a1 1 0 1 1 0-2 1 1 0 0 1 0 2"/></svg>'
  };
  body.querySelectorAll(".markdown-alert").forEach(function (alert) {
    var type = /markdown-alert-(note|tip|important|warning|caution)/.exec(alert.className);
    var title = alert.querySelector(".markdown-alert-title");
    if (type && title) title.insertAdjacentHTML("afterbegin", icons[type[1]]);
  });

  // Copy buttons: on code blocks here, and on diagrams through window.mdr
  var svgCopy = '<svg viewBox="0 0 16 16" width="16" height="16" fill="currentColor" aria-hidden="true"><path d="M0 6.75C0 5.784.784 5 1.75 5h1.5a.75.75 0 0 1 0 1.5h-1.5a.25.25 0 0 0-.25.25v7.5c0 .138.112.25.25.25h7.5a.25.25 0 0 0 .25-.25v-1.5a.75.75 0 0 1 1.5 0v1.5A1.75 1.75 0 0 1 9.25 16h-7.5A1.75 1.75 0 0 1 0 14.25zM5 1.75C5 .784 5.784 0 6.75 0h7.5C15.216 0 16 .784 16 1.75v7.5A1.75 1.75 0 0 1 14.25 11h-7.5A1.75 1.75 0 0 1 5 9.25z"/></svg>';
  var svgCheck = '<svg viewBox="0 0 16 16" width="16" height="16" fill="currentColor" aria-hidden="true"><path d="M13.78 4.22a.75.75 0 0 1 0 1.06l-7.25 7.25a.75.75 0 0 1-1.06 0L2.22 9.28a.751.751 0 0 1 .018-1.042.751.751 0 0 1 1.042-.018L6 10.94l6.72-6.72a.75.75 0 0 1 1.06 0z"/></svg>';
  function copyButton(className, label, getText) {
    var btn = document.createElement("button");
    btn.type = "button";
    btn.className = className;
    btn.title = label;
    btn.setAttribute("aria-label", label);
    btn.innerHTML = svgCopy;
    btn.addEventListener("click", function () {
      navigator.clipboard.writeText(getText()).then(function () {
        btn.classList.add("copied");
        btn.innerHTML = svgCheck;
        setTimeout(function () {
          btn.classList.remove("copied");
          btn.innerHTML = svgCopy;
        }, 2000);
      });
    });
    return btn;
  }
  // Marks the sides a box that scrolls sideways can still scroll to, for the CSS edge fades
  function trackEdges(box, marked) {
    function update() {
      var left = box.scrollLeft, max = box.scrollWidth - box.clientWidth;
      marked.classList.toggle("mdr-more-left", left > 1);
      marked.classList.toggle("mdr-more-right", left < max - 1);
    }
    box.addEventListener("scroll", update, {passive: true});
    new ResizeObserver(update).observe(box);
  }
  function addCodeCopy(pre) {
    var wrapper = document.createElement("div");
    wrapper.className = "code-wrapper";
    pre.parentNode.insertBefore(wrapper, pre);
    wrapper.appendChild(pre);
    wrapper.appendChild(copyButton("copy-btn", "Copy", function () {
      return (pre.querySelector("code") || pre).textContent;
    }));
    trackEdges(pre, wrapper);
  }
  body.querySelectorAll("pre").forEach(function (pre) {
    // Mermaid and math blocks get replaced by their rendered output; the diagram script adds
    // the button to a diagram it can't draw
    if (!pre.querySelector("code.language-mermaid, [data-math-style]")) addCodeCopy(pre);
  });
  // github-markdown-css makes each table its own scroll box
  body.querySelectorAll("table").forEach(function (table) { trackEdges(table, table); });
  window.mdr = {copyButton: copyButton, addCodeCopy: addCodeCopy};

  // mdread points <base> at the source directory, which would send #links there too
  if (root.hasAttribute("data-preview")) {
    document.addEventListener("click", function (e) {
      var a = e.target.closest && e.target.closest('a[href^="#"]');
      if (!a || e.defaultPrevented || e.button !== 0 || e.metaKey || e.ctrlKey || e.shiftKey || e.altKey) return;
      e.preventDefault();
      location.hash = a.getAttribute("href");
    });
  }
})();
JS
  printf '</script>\n'

  if [[ $body == *'<code class="language-mermaid"'* ]]; then
    # Only the libraries this renderer can load, so the page names nothing it won't fetch
    if [[ $renderer == mermaid ]]; then
      libs="mermaid: [\"$MDR_MERMAID_URL\", \"$MDR_MERMAID_SRI\"]"
    else
      libs="pele: [\"$MDR_PELE_URL\", \"$MDR_PELE_SRI\"]"
    fi
    if [[ $renderer == beautiful-mermaid ]]; then libs="beautiful: \"$MDR_BEAUTIFUL_URL\", $libs"; fi
    # A module, for top-level await while the libraries load
    printf '<script type="module" nonce="%s">\n' "$nonce"
    printf 'const renderer = "%s", mermaidTheme = "%s", libs = {%s};\n' \
      "$renderer" "$mermaid_theme" "$libs"
    cat <<'JS'
// Each Mermaid block becomes a diagram in a .mdr-diagram wrapper, with buttons to copy its
// source, download it as SVG and expand it. By default Pele draws everything. With
// --mermaid beautiful-mermaid, beautiful-mermaid draws the types it knows (flowchart, state,
// sequence, class, ER, XY chart) and Pele the rest, plus any diagram beautiful-mermaid throws
// on; with --mermaid mermaid, mermaid.js draws everything. Each library loads only if a
// diagram needs it.
const root = document.documentElement;
const jobs = [...document.querySelectorAll(".markdown-body pre > code.language-mermaid")]
  .map((code, i) => ({pre: code.parentElement, text: code.textContent, n: i + 1}));
const light = root.getAttribute("data-theme") === "light";
// --max-diagram-height; not set with none
const limited = getComputedStyle(root).getPropertyValue("--mdr-diagram-max-height").trim() !== "";

const icon = (...paths) =>
  '<svg viewBox="0 0 16 16" width="16" height="16" fill="currentColor" aria-hidden="true">' +
  paths.map((d) => `<path d="${d}"/>`).join("") + "</svg>";
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

const button = (label, svg, onClick, className = "mdr-tool") => {
  const btn = document.createElement("button");
  btn.type = "button";
  btn.className = className;
  btn.title = label;
  btn.setAttribute("aria-label", label);
  btn.innerHTML = svg;
  btn.addEventListener("click", onClick);
  return btn;
};

// Loads a library's script; if it fails, the renderer's blocks stay as source with a copy
// button. Resolves to whether it loaded.
const load = ([src, integrity], list) => new Promise((resolve) => {
  const script = document.createElement("script");
  script.src = src;
  script.integrity = integrity;
  script.crossOrigin = "anonymous";
  script.onload = () => resolve(true);
  script.onerror = () => {
    list.forEach((job) => mdr.addCodeCopy(job.pre));
    resolve(false);
  };
  document.head.append(script);
});

const svgOf = (job) => job.el?.querySelector(":scope > svg");
// The width a container lays its diagram out in: Pele's, on the page, has padding
const contentWidth = (el) => {
  const style = getComputedStyle(el);
  return el.clientWidth - parseFloat(style.paddingLeft) - parseFloat(style.paddingRight);
};
const viewBox = (svg) => {
  const [, , w, h] = (svg.getAttribute("viewBox") || "").split(/[\s,]+/).map(Number);
  return {w, h};
};

// Puts a renderer's container where the block was, in a wrapper with the diagram's buttons.
// Double-clicking the diagram expands it too.
const place = (job, className) => {
  const el = document.createElement("div");
  el.className = className;
  const expandButton = button("Expand diagram", svgExpand, () => expand(job, expandButton));
  const tools = document.createElement("div");
  tools.className = "mdr-diagram-tools";
  tools.append(
    mdr.copyButton("mdr-tool", "Copy diagram source", () => job.text),
    button("Download SVG", svgDownload, () => download(job)),
    expandButton
  );
  job.wrap = document.createElement("div");
  job.wrap.className = "mdr-diagram";
  job.wrap.append(el, tools);
  // Not on the buttons or Pele's zoom controls. Capturing, so Pele's own double-click zoom
  // never sees it; and the double-click doesn't select a word of the diagram's text.
  const onControls = (e) => e.target.closest?.(".mdr-diagram-tools, .pele-zoom");
  job.wrap.addEventListener("dblclick", (e) => {
    if (onControls(e)) return;
    e.stopPropagation();
    e.preventDefault();
    expand(job, expandButton);
  }, true);
  job.wrap.addEventListener("mousedown", (e) => {
    if (e.detail > 1 && !onControls(e)) e.preventDefault();
  });
  // Pele disables + or - at its zoom limits and hides its reset button at the fit, and a
  // focused button it does that to loses the focus to the page, without an event. The zoom
  // row, shown on keyboard focus, would then fade out under the user, so when that button
  // had keyboard focus, the row's first button still in use takes it. After a mouse click
  // the focus goes, as before, so Space still scrolls the page. Capturing, to see the focus
  // before Pele's own click handler runs. Pele hides reset with display: none, which leaves
  // it no boxes.
  const usable = (btn) => !btn.disabled && btn.getClientRects().length > 0;
  job.wrap.addEventListener("click", (e) => {
    const btn = e.target.closest?.(".pele-zoom > button");
    if (!btn?.matches(":focus-visible")) return;
    setTimeout(() => {
      if (!usable(btn)) [...btn.parentElement.children].find(usable)?.focus();
    });
  }, true);
  job.pre.replaceWith(job.wrap);
  job.el = el;
  return el;
};

// A diagram that can't be drawn keeps its source under a note, with the code copy button
const fail = (job, name, err) => {
  const note = document.createElement("p");
  note.className = "mdr-diagram-error";
  note.textContent = `${name} can't render this diagram: ${err?.message || err}`;
  job.wrap.replaceWith(note, job.pre);
  mdr.addCodeCopy(job.pre);
};

// --max-diagram-height: capping a diagram's width at that height times its aspect ratio
// scales it down with its proportions kept, since its height is auto
const fitHeight = (svg, w, h) => {
  if (!limited || !svg || !(w > 0 && h > 0)) return;
  const cap = `calc(var(--mdr-diagram-max-height) * ${+(w / h).toFixed(4)})`;
  svg.style.maxWidth = `min(${svg.style.maxWidth || "100%"}, ${cap})`;
};

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

// A standalone copy of a diagram that looks the way it does on the page
const exportSvg = (job) => {
  const live = svgOf(job);
  const svg = natural(live.cloneNode(true), job.w, job.h);
  if (job.mounted) svg.setAttribute("viewBox", `0 0 ${job.w} ${job.h}`); // undo Pele's zoom
  // Custom properties it uses but gets from the page (Pele's --pele-* colors) go on its root
  const markup = svg.outerHTML;
  const computed = getComputedStyle(live);
  for (const [, name] of markup.matchAll(/var\(\s*(--[\w-]+)/g)) {
    if (new RegExp(name + "\\s*:").test(markup)) continue;
    const value = computed.getPropertyValue(name).trim();
    if (value) svg.style.setProperty(name, value);
  }
  // Every renderer draws on a transparent background; give it the one it has on the page
  svg.style.backgroundColor = getComputedStyle(job.wrap).backgroundColor;
  // XMLSerializer, not outerHTML: HTML labels in <foreignObject> must be well-formed XML
  return '<?xml version="1.0" encoding="UTF-8"?>\n' +
    new XMLSerializer().serializeToString(svg) + "\n";
};

// <title> is the markdown file's name
const fileBase = document.title.replace(/\.(md|markdown|mdown|mkd|mkdn)$/i, "")
  .replace(/[\\/:*?"<>|\x00-\x1f]/g, "-") || "page";
const download = (job) => {
  if (!svgOf(job)) return;
  const url = URL.createObjectURL(new Blob([exportSvg(job)], {type: "image/svg+xml"}));
  const a = document.createElement("a");
  a.href = url;
  a.download = `${fileBase}-diagram-${job.n}.svg`;
  document.body.append(a);
  a.click();
  a.remove();
  setTimeout(() => URL.revokeObjectURL(url), 60000);
};

// Pan and zoom for the expanded diagram in view, a scrolling box: dragging pans by scrolling
// it, and zooming resizes the SVG. 100% is the diagram's natural size. Returns show(svg, w, h), which
// puts an SVG of that natural size under the zoom, and the zoom controls, [- 100% +].
const zoomSteps = [0.1, 0.25, 0.33, 0.5, 0.67, 0.75, 0.9, 1, 1.1, 1.25, 1.5, 1.75, 2, 2.5, 3, 4, 5];
const minZoom = zoomSteps[0], maxZoom = zoomSteps.at(-1);
const panZoom = (view, keys) => {
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

  const controls = document.createElement("div");
  controls.className = "mdr-zoom";
  const zoomOut = button("Zoom out", svgDash, () => zoomTo(step(-1)), "");
  const level = button("Reset zoom", "100%", () => zoomTo(1), "mdr-zoom-level");
  const zoomIn = button("Zoom in", svgPlus, () => zoomTo(step(1)), "");
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
    view.classList.add("mdr-panning");
  });
  view.addEventListener("pointermove", (e) => {
    if (e.pointerId !== drag?.id) return;
    view.scrollLeft = drag.x - e.clientX;
    view.scrollTop = drag.y - e.clientY;
  });
  const endDrag = (e) => {
    if (e.pointerId !== drag?.id) return;
    drag = undefined;
    view.classList.remove("mdr-panning");
  };
  // On release, or when the browser takes the capture away (pointercancel, a lost focus)
  view.addEventListener("pointerup", endDrag);
  view.addEventListener("lostpointercapture", endDrag);

  // The wheel zooms rather than scrolls, and so does pinching: Chrome and Firefox send a pinch
  // as a wheel event with ctrlKey, Safari as gesture events (any wheel events it sends during
  // one are ignored, so it can't zoom twice). Wheel deltas in lines or pages (Firefox) become
  // pixels, then each event zooms by at most 2^0.48.
  view.addEventListener("wheel", (e) => {
    e.preventDefault();
    if (pinchFrom) return;
    const px = e.deltaY * (e.deltaMode === 1 ? 20 : e.deltaMode === 2 ? 400 : 1);
    const delta = Math.min(Math.max(-px, -24), 24);
    zoomTo(scale * 2 ** (delta * 0.02), e.clientX, e.clientY);
  }, {passive: false});
  let pinchFrom = 0;
  view.addEventListener("gesturestart", (e) => {
    e.preventDefault();
    pinchFrom = scale;
  });
  view.addEventListener("gesturechange", (e) => {
    e.preventDefault();
    if (pinchFrom) zoomTo(pinchFrom * e.scale, e.clientX, e.clientY);
  });
  view.addEventListener("gestureend", () => (pinchFrom = 0));

  keys.addEventListener("keydown", (e) => {
    if (e.ctrlKey || e.metaKey || e.altKey) return;
    if (e.key === "+" || e.key === "=") zoomTo(step(1));
    else if (e.key === "-") zoomTo(step(-1));
    else if (e.key === "0") zoomTo(1);
    else return;
    e.preventDefault();
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

// Shows a diagram in a modal dialog at its natural size, with pan and zoom (panZoom). Esc,
// the close button or a click outside closes it.
const expand = (job, opener) => {
  const live = svgOf(job);
  if (!live) return;
  const dialog = document.createElement("dialog");
  dialog.className = "mdr-dialog";
  dialog.setAttribute("aria-label", `Diagram ${job.n}`);
  const view = document.createElement("div");
  view.className = "mdr-dialog-view";
  view.tabIndex = 0; // so the arrow keys pan
  const zoom = panZoom(view, dialog);
  dialog.append(view, button("Close", svgClose, () => dialog.close()), zoom.controls);
  // Inside .markdown-body, for the page's font and colors
  document.querySelector(".markdown-body").append(dialog);
  dialog.showModal();
  let mounted;
  if (job.mounted) {
    // A new Pele drawing, laid out once for the dialog's width, without Pele's zoom. Once
    // drawn, its container shrinks to fit it, so it centers and scrolls like the others.
    // Never laid out narrower than on the page: Pele turns a left-right diagram that doesn't
    // fit top to bottom when its width is under 640px, and in windows under 768px wide the
    // dialog's view is narrower than the page's diagram, so it could turn there alone.
    const div = document.createElement("div");
    div.className = "pele-diagram";
    div.style.width = "100%";
    view.append(div);
    mounted = pele.mount(div, job.text, {
      zoom: false,
      maxWidth: Math.max(div.clientWidth, contentWidth(job.el)),
      onRender(result) {
        div.style.width = "";
        zoom.show(div.querySelector(":scope > svg"), result.width, result.height);
      }
    });
  } else {
    const svg = natural(live.cloneNode(true), job.w, job.h);
    view.append(svg);
    zoom.show(svg, job.w, job.h);
  }
  view.focus({preventScroll: true});
  dialog.addEventListener("click", (e) => {
    if (e.target === dialog) dialog.close();
  });
  dialog.addEventListener("close", () => {
    mounted?.destroy();
    dialog.remove();
    if (!document.activeElement || document.activeElement === document.body) {
      opener.focus({preventScroll: true});
    }
  });
};

// A diagram's type is named on its first line that isn't blank or a %% comment
const beautifulType =
  /^(graph|flowchart|statediagram(-v2)?|sequencediagram|classdiagram|erdiagram|xychart(-beta)?)\b/i;
const header = (text) =>
  text.split("\n").map((line) => line.trim()).find((line) => line && !line.startsWith("%%")) || "";

// Returns the diagrams it couldn't draw: all of them if beautiful-mermaid doesn't load
const drawBeautiful = async (list) => {
  let lib;
  try {
    lib = await import(libs.beautiful);
  } catch {
    return list;
  }
  // Its colors derive from the background, so give it the one diagrams sit on
  const colors = {
    ...lib.THEMES[light ? "github-light" : "github-dark"],
    bg: getComputedStyle(root).getPropertyValue("--mdr-diagram-bg").trim()
  };
  const failed = [];
  for (const job of list) {
    let svg;
    try {
      // The SVG's stylesheet @imports its font from Google Fonts, which the CSP blocks; drop
      // it so the text falls back to the system font
      svg = lib.renderMermaidSVG(job.text, {...colors, transparent: true})
        .replace(/@import url\([^)]*\);/g, "");
    } catch {
      failed.push(job);
      continue;
    }
    place(job, "beautiful-mermaid").innerHTML = svg;
    const drawn = svgOf(job);
    if (drawn) ({w: job.w, h: job.h} = viewBox(drawn));
    fitHeight(drawn, job.w, job.h);
  }
  return failed;
};

const drawPele = async (list) => {
  if (!(await load(libs.pele, list))) return;
  for (const job of list) {
    const div = place(job, "pele-diagram");
    // mount() measures text with the page's font, fits the diagram to its container's width
    // and offers zoom when the diagram shows smaller than its natural size: too wide, or
    // capped by fitHeight. onRender runs on every redraw; on the first, before the zoom
    // exists, and later after it, so the zoom then needs a refresh to see the cap.
    job.mounted = pele.mount(div, job.text, {
      onRender(result) {
        job.w = result.width;
        job.h = result.height;
        fitHeight(svgOf(job), job.w, job.h);
        job.mounted?.zoom?.refresh();
      },
      onError(err) {
        if (job.wrap.isConnected) fail(job, "pele", err);
      }
    });
  }
};

const drawMermaid = async (list) => {
  if (!(await load(libs.mermaid, list))) return;
  // render() one diagram at a time rather than run(), so each failure is caught and handled
  // like Pele's; suppressErrorRendering keeps mermaid.js from drawing its own error picture
  mermaid.initialize({startOnLoad: false, theme: mermaidTheme, suppressErrorRendering: true});
  for (const job of list) {
    const div = place(job, "mermaid-diagram");
    try {
      // Drawn inside the div, so the page's styles apply while mermaid.js measures text
      const {svg, bindFunctions} = await mermaid.render(`mdr-mermaid-${job.n}`, job.text, div);
      div.innerHTML = svg;
      bindFunctions?.(div);
      const drawn = svgOf(job);
      if (drawn) ({w: job.w, h: job.h} = viewBox(drawn));
      fitHeight(drawn, job.w, job.h);
    } catch (err) {
      fail(job, "mermaid.js", err);
    }
  }
};

if (renderer === "mermaid") {
  await drawMermaid(jobs);
} else {
  let forPele = jobs;
  if (renderer === "beautiful-mermaid") {
    const mine = jobs.filter((job) => beautifulType.test(header(job.text)));
    forPele = jobs.filter((job) => !mine.includes(job));
    // If beautiful-mermaid doesn't load, Pele draws its diagrams too
    if (mine.length) forPele.push(...(await drawBeautiful(mine)));
  }
  if (forPele.length) await drawPele(forPele);
}
JS
    printf '</script>\n'
  fi

  if [[ $body == *'data-math-style='* ]]; then
    printf '<script nonce="%s">\n' "$nonce"
    cat <<'JS'
(function () {
  // comrak marks math with data-math-style. Hand MathJax exactly those elements, wrapped in
  // \( \) or \[ \], so it never scans the page for $ delimiters.
  var nodes = [];
  document.querySelectorAll(".markdown-body [data-math-style]").forEach(function (el) {
    var display = el.getAttribute("data-math-style") === "display";
    var target = el.parentElement.tagName === "PRE" ? el.parentElement : el;
    var node = document.createElement(target.tagName === "PRE" ? "div" : "span");
    node.textContent = display ? "\\[" + el.textContent + "\\]" : "\\(" + el.textContent + "\\)";
    target.replaceWith(node);
    nodes.push(node);
  });
  window.MathJax = {
    tex: {inlineMath: [["\\(", "\\)"]], displayMath: [["\\[", "\\]"]]},
    startup: {
      typeset: false,
      pageReady: function () { return MathJax.typesetPromise(nodes); }
    }
  };
})();
JS
    printf '</script>\n'
    printf '<script nonce="%s" src="%s" integrity="%s" crossorigin="anonymous" async></script>\n' \
      "$nonce" "$MDR_MATHJAX_URL" "$MDR_MATHJAX_SRI"
  fi

  if [[ $frontmatter$body == *'<pre><code class="language-'* ]]; then
    printf '<script type="module" nonce="%s">\n' "$nonce"
    cat <<'JS'
import {common, createStarryNight} from "https://esm.sh/@wooorm/starry-night@3.11.0?bundle";
import {toDom} from "https://esm.sh/hast-util-to-dom@4.0.1?bundle";

// Grammars outside starry-night's common bundle, fetched only when a page uses them
// (code block language -> TextMate scope)
const extra = {
  toml: "source.toml", dockerfile: "source.dockerfile", docker: "source.dockerfile",
  containerfile: "source.dockerfile", tsx: "source.tsx", jsx: "source.js",
  console: "text.shell-session", "shell-session": "text.shell-session",
  hcl: "source.hcl", terraform: "source.hcl.terraform", tf: "source.hcl.terraform",
  nix: "source.nix", elixir: "source.elixir", ex: "source.elixir", exs: "source.elixir",
  haskell: "source.haskell", hs: "source.haskell", scala: "source.scala", dart: "source.dart",
  zig: "source.zig", powershell: "source.powershell", ps1: "source.powershell",
  pwsh: "source.powershell", bat: "source.batchfile", batch: "source.batchfile",
  cmd: "source.batchfile", nginx: "source.nginx", proto: "source.proto",
  protobuf: "source.proto", latex: "text.tex.latex", tex: "text.tex", vue: "text.html.vue",
  svelte: "source.svelte", groovy: "source.groovy", gradle: "source.groovy.gradle",
  clojure: "source.clojure", clj: "source.clojure", erlang: "source.erlang",
  erl: "source.erlang", ocaml: "source.ocaml", fsharp: "source.fsharp", julia: "source.julia",
  cmake: "source.cmake", gitignore: "source.gitignore", jsonc: "source.json.comments",
  dotenv: "source.dotenv", env: "source.dotenv", csv: "source.csv", solidity: "source.solidity",
  glsl: "source.glsl", matlab: "source.matlab", crystal: "source.crystal", nim: "source.nim",
  d: "source.d", gleam: "source.gleam", prisma: "source.prisma", astro: "source.astro",
  editorconfig: "source.editorconfig", apacheconf: "source.apacheconf"
};
const grammarUrl = (scope) => "https://esm.sh/@wooorm/starry-night@3.11.0/" + scope + "?bundle";

const codes = [...document.querySelectorAll('.markdown-body pre > code[class*="language-"]')];
const flagOf = (code) =>
  [...code.classList].find((c) => c.startsWith("language-")).slice(9).toLowerCase();
const starryNight = await createStarryNight(common);
const register = async (scopes) => {
  const grammars = await Promise.all(
    [...scopes].map((scope) => import(grammarUrl(scope)).then((m) => m.default, () => null))
  );
  await starryNight.register(grammars.filter(Boolean));
};

const registered = new Set(starryNight.scopes());
const missingBefore = new Set(starryNight.missingScopes());
const wanted = new Set(
  codes
    .map(flagOf)
    .filter((flag) => !starryNight.flagToScope(flag) && extra[flag])
    .map((flag) => extra[flag])
    .filter((scope) => !registered.has(scope))
);
if (wanted.size) {
  await register(wanted);
  // Grammars can embed others (CSS in Vue, shell in Dockerfile); fetch those one level deep
  const embedded = starryNight.missingScopes().filter((scope) => !missingBefore.has(scope));
  if (embedded.length) await register(embedded);
}

for (const code of codes) {
  const flag = flagOf(code);
  const scope = starryNight.flagToScope(flag) || extra[flag];
  if (!scope || !starryNight.scopes().includes(scope)) continue;
  code.replaceChildren(toDom(starryNight.highlight(code.textContent, scope), {fragment: true}));
}
JS
    printf '</script>\n'
  fi

  printf '</body>\n</html>\n'
}
