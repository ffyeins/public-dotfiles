# shellcheck shell=bash disable=SC2034,SC2154
# Shared rendering for mdread and mdtohtml. Sourced by both scripts, not run directly.
# Globals flow both ways, hence the shellcheck exclusions: callers define `prog`, `VERSION`
# and `usage`; mdr_parse_args sets `theme`, `force`, `files` and `action` for them.

# Pinned CDN assets. After bumping a version, refresh its integrity hash with:
#   curl -s <url> | openssl dgst -sha384 -binary | openssl base64 -A
# starry-night and hast-util-to-dom are pinned in the module script below (esm.sh, no SRI).
MDR_CSS_BASE="https://cdn.jsdelivr.net/npm/github-markdown-css@5.9.0"
MDR_CSS_SRI_DARK="sha384-nlth4oyFjBlAziFH2oypWWsE00W7j/6uVR4/Fz1++oPhaqeF8LujWsaX3ChXZw/1"
MDR_CSS_SRI_LIGHT="sha384-4+yp2IvYOqcJcR9WCGb7S9CwgoCBD4qxmEMxnXjwpM54P0M/z05F3YkC+NFunWrc"
MDR_MERMAID_URL="https://cdn.jsdelivr.net/npm/mermaid@11.17.2/dist/mermaid.min.js"
MDR_MERMAID_SRI="sha384-EOXBFmc3gx5mb+vn0vPvvGqACToJD24hhacX5Yx+8NUUQrHIle/Qi5Bg9o3zKwW2"
MDR_MATHJAX_URL="https://cdn.jsdelivr.net/npm/mathjax@3.2.2/es5/tex-mml-chtml.js"
MDR_MATHJAX_SRI="sha384-Wuix6BuhrWbjDBs24bXrjf4ZQ5aFeFWBuKkFekO2t8xFU0iNaLQfp2K6/1Nxveei"

mdr_usage_error() {
  echo "$prog: $1" >&2
  usage >&2
  exit 2
}

# Parse the options both commands share. Sets theme, force, files and action (run, help or
# version). $1 is 1 when --force is allowed (mdtohtml only).
mdr_parse_args() {
  local allow_force=$1
  shift
  theme=dark
  force=0
  action=run
  files=()
  while [[ $# -gt 0 ]]; do
    case $1 in
      -h|--help) action=help; return ;;
      -v|--version) action=version; return ;;
      --light) theme=light ;;
      --dark) theme=dark ;;
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
# Usage: mdr_render_html <file> <theme> [base_url]
# base_url (mdread only) becomes <base href>, so relative images and links resolve against
# the source directory; the page script then keeps #links on the page itself.
mdr_render_html() {
  local file=$1 theme=$2 base_url=${3:-}
  local body frontmatter title nonce csp css_file css_sri theme_vars mermaid_theme

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
      theme_vars='--mdr-page-bg: #ffffff; --mdr-btn-bg: #f6f8fa; --mdr-btn-border: #d0d7de; --mdr-btn-fg: #656d76; --mdr-btn-hover-bg: #eaeef2; --mdr-btn-hover-fg: #1f2328; --mdr-ok: #1a7f37;'
      ;;
    *)
      css_file=github-markdown-dark.css
      css_sri=$MDR_CSS_SRI_DARK
      mermaid_theme=dark
      theme_vars='--mdr-page-bg: #0d1117; --mdr-btn-bg: #21262d; --mdr-btn-border: #30363d; --mdr-btn-fg: #8b949e; --mdr-btn-hover-bg: #30363d; --mdr-btn-hover-fg: #e6edf3; --mdr-ok: #3fb950;'
      ;;
  esac

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
.code-wrapper { position: relative; }
.copy-btn {
  position: absolute; top: 8px; right: 8px; padding: 4px; line-height: 1;
  color: var(--mdr-btn-fg); background: var(--mdr-btn-bg);
  border: 1px solid var(--mdr-btn-border); border-radius: 6px;
  cursor: pointer; opacity: 0; transition: opacity 0.15s;
}
.code-wrapper:hover > .copy-btn, .copy-btn:focus-visible { opacity: 1; }
.copy-btn:hover { color: var(--mdr-btn-hover-fg); background: var(--mdr-btn-hover-bg); }
.copy-btn.copied { color: var(--mdr-ok); }
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

  // Copy buttons on code blocks
  var svgCopy = '<svg viewBox="0 0 16 16" width="16" height="16" fill="currentColor" aria-hidden="true"><path d="M0 6.75C0 5.784.784 5 1.75 5h1.5a.75.75 0 0 1 0 1.5h-1.5a.25.25 0 0 0-.25.25v7.5c0 .138.112.25.25.25h7.5a.25.25 0 0 0 .25-.25v-1.5a.75.75 0 0 1 1.5 0v1.5A1.75 1.75 0 0 1 9.25 16h-7.5A1.75 1.75 0 0 1 0 14.25zM5 1.75C5 .784 5.784 0 6.75 0h7.5C15.216 0 16 .784 16 1.75v7.5A1.75 1.75 0 0 1 14.25 11h-7.5A1.75 1.75 0 0 1 5 9.25z"/></svg>';
  var svgCheck = '<svg viewBox="0 0 16 16" width="16" height="16" fill="currentColor" aria-hidden="true"><path d="M13.78 4.22a.75.75 0 0 1 0 1.06l-7.25 7.25a.75.75 0 0 1-1.06 0L2.22 9.28a.751.751 0 0 1 .018-1.042.751.751 0 0 1 1.042-.018L6 10.94l6.72-6.72a.75.75 0 0 1 1.06 0z"/></svg>';
  body.querySelectorAll("pre").forEach(function (pre) {
    // Mermaid and math blocks get replaced by their rendered output
    if (pre.querySelector("code.language-mermaid, [data-math-style]")) return;
    var btn = document.createElement("button");
    btn.type = "button";
    btn.className = "copy-btn";
    btn.title = "Copy";
    btn.setAttribute("aria-label", "Copy");
    btn.innerHTML = svgCopy;
    btn.addEventListener("click", function () {
      var code = pre.querySelector("code");
      navigator.clipboard.writeText((code || pre).textContent).then(function () {
        btn.classList.add("copied");
        btn.innerHTML = svgCheck;
        setTimeout(function () {
          btn.classList.remove("copied");
          btn.innerHTML = svgCopy;
        }, 2000);
      });
    });
    var wrapper = document.createElement("div");
    wrapper.className = "code-wrapper";
    pre.parentNode.insertBefore(wrapper, pre);
    wrapper.appendChild(pre);
    wrapper.appendChild(btn);
  });

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
    printf '<script nonce="%s">\n' "$nonce"
    cat <<'JS'
document.querySelectorAll(".markdown-body pre > code.language-mermaid").forEach(function (code) {
  var div = document.createElement("div");
  div.className = "mermaid";
  div.textContent = code.textContent;
  code.parentElement.replaceWith(div);
});
JS
    printf '</script>\n'
    printf '<script nonce="%s" src="%s" integrity="%s" crossorigin="anonymous"></script>\n' \
      "$nonce" "$MDR_MERMAID_URL" "$MDR_MERMAID_SRI"
    printf '<script nonce="%s">mermaid.initialize({startOnLoad: true, theme: "%s"});</script>\n' \
      "$nonce" "$mermaid_theme"
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
