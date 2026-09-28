# Yazi config

Terminal file manager config. Two files:

- `yazi.toml` — runtime settings (`show_hidden = true`) + nvim opener rules.
- `theme.toml` — full color theme. Auto-loaded by yazi from same dir.

## Editor

Text files open in `nvim` via custom `edit` opener. Defined in `yazi.toml`:

```toml
[opener]
edit = [
  { run = 'nvim "$@"', block = true, for = "unix" },
]

[open]
prepend_rules = [
  { mime = "text/*", use = "edit" },
  { mime = "application/{json,x-wine-extension-ini,x-yaml,toml,xml}", use = "edit" },
  { name = "*.{md,markdown,toml,yaml,yml,json,conf,sh,zsh,bash,lua,vim,nix,py,rs,go,ts,tsx,js,jsx}", use = "edit" },
]
```

`prepend_rules` insert before built-in defaults so nvim win over default `$EDITOR` opener. `block = true` suspend yazi while nvim run; return on `:q`. Trigger key: `o` or `Enter` on matching file. Add extensions to `name` glob if missing.

## Theme

Sourced verbatim from upstream `catppuccin/yazi` flavor: **macchiato + lavender accent**.

- Source: `https://raw.githubusercontent.com/catppuccin/yazi/main/themes/macchiato/catppuccin-macchiato-lavender.toml`
- Local mods:
  - `[app] overall.bg` — kept native macchiato `#24273a` (toggle to `"reset"` to inherit terminal bg).
  - `syntect_theme` line commented out — points to `~/.config/yazi/Catppuccin-macchiato.tmTheme` which is not installed. Code-preview syntax highlighting falls back to yazi's built-in. Uncomment + drop matching `.tmTheme` from `catppuccin/bat` if syntax preview wanted.

## Swap flavor / accent

Replace `theme.toml` with another upstream variant. Pattern:

```bash
curl -fsSL https://raw.githubusercontent.com/catppuccin/yazi/main/themes/<flavor>/catppuccin-<flavor>-<accent>.toml \
  -o ~/.config/yazi/theme.toml
```

`<flavor>` ∈ {latte, frappe, macchiato, mocha}. `<accent>` ∈ {rosewater, flamingo, pink, mauve, red, maroon, peach, yellow, green, teal, sky, sapphire, blue, lavender}.

After swap, re-apply local mods:
1. Edit `[app] overall.bg` if want `"reset"` (terminal bg) or different hex.
2. Comment `syntect_theme` line (path differs per flavor: `Catppuccin-<flavor>.tmTheme`).

## Verify

Quit running yazi, relaunch: `yazi`.
