# Sketchybar Configuration

macOS top bar replacement using [SketchyBar](https://felixkratz.github.io/SketchyBar/) with [AeroSpace](https://github.com/nikitabobko/AeroSpace) tiling window manager integration.

## File Structure

- `sketchybarrc` — Main entry point. Configures bar appearance (fully transparent with blur), sets default item styles, and sources item scripts.
- `colors.sh` — Color definitions. Exports `BAR_COLOR`, `ITEM_BG_COLOR`, `ACCENT_COLOR`, `UNFOCUSED_BG_COLOR`, `EMPTY_TEXT_COLOR`, `SELECTED_BG_COLOR`, `SELECTED_TEXT_COLOR`, and `WHITE`. Multiple color schemes are available (teal is active, others commented out).
- `items/spaces.sh` — Creates workspace items from AeroSpace. Builds a monitor-to-display mapping, then creates a `space.$sid` item for each workspace in a single batched `sketchybar` call (including the hidden `space_trigger` item that subscribes to `aerospace_workspace_change` and `front_app_switched`). After creation, triggers `aerospace_workspace_change` once so `plugins/aerospace.sh` handles all initial styling — this avoids duplicating the styling logic.
- `items/front_app.sh` — Front app display (currently disabled in sketchybarrc).
- `plugins/aerospace.sh` — Handles `aerospace_workspace_change` and `front_app_switched` events via a single `space_trigger` item. Runs three aerospace queries in parallel (visible workspaces, all workspaces, all windows), then builds icon strings for all workspaces in one pass via `build_all_workspace_icons`. Updates every `space.$sid` item in a single batched `sketchybar` call with `--animate tanh 7`. Empty workspace status is derived from window data (no separate `--empty` query).
- `plugins/front_app.sh` — Front app event handler. Sources `icon_map_fn.sh` and uses the `icon_result` global variable.
- `plugins/icon_map_fn.sh` — Defines the `icon_map` function (only a function definition, no standalone execution). Sets the `icon_result` global variable to a `sketchybar-app-font` icon string (e.g. `:firefox:`). Unknown apps fall through to `:default:`. Sourced by `front_app.sh` and `icon_builder.sh`. Generated from the `sketchybar-app-font` repo (see Updating App Icons below).
- `plugins/icon_builder.sh` — Provides two functions: `get_workspace_icons` (queries a single workspace's windows, used for one-off lookups) and `build_all_workspace_icons` (parses pre-fetched `aerospace list-windows --all` output in one pass, setting `WS_ICONS_<ws>` and `WS_HAS_WINDOWS_<ws>` global variables for each workspace). Icons are deduplicated and capped at 5 per workspace. Sourced by `plugins/aerospace.sh`.

## Color Format

SketchyBar uses `0xAARRGGBB` format. `AA` is alpha (00=transparent, ff=opaque, 80=~50%).

## Style Design

- Bar has a near-transparent background (`0x15000000`) with `blur_radius=30` for a frosted glass effect. Note: blur requires non-zero alpha to render.
- Unfocused non-empty workspace items have a translucent dark background with solid white text.
- Unfocused empty workspace items have a translucent dark background with translucent white text (`EMPTY_TEXT_COLOR`).
- Visible workspace items (one per display) have an opaque white background with translucent black text.
- Non-empty workspace items display app icons next to the workspace number using `sketchybar-app-font:Regular:16.0` in the label. Icons are deduplicated and capped at 5 per workspace. Empty workspaces show only the workspace number.
- Workspace item width is dynamic — it grows/shrinks based on the number of app icons.
- Font: Roboto Mono Bold 16.0 (workspace numbers), sketchybar-app-font Regular 16.0 (app icons).

## AeroSpace Integration

The `aerospace_workspace_change` event is triggered in two ways from `aerospace.toml`:
- `exec-on-workspace-change` — fires automatically when switching workspaces.
- `move-node-to-workspace` bindings — each chains an `exec-and-forget sketchybar --trigger aerospace_workspace_change` so the bar updates immediately when a window is moved to another workspace.

The `space_trigger` item also subscribes to sketchybar's built-in `front_app_switched` event, so the bar updates when windows are opened or closed (since these typically change the focused app).

## Bash Compatibility

macOS ships with bash 3.2 (due to GPLv3 licensing), which does not support associative arrays (`declare -A`). Scripts must avoid associative arrays with non-numeric keys — letter keys like `WS_ICONS[B]` silently evaluate to index `0` in bash 3.2. The `DISPLAY_MAP` in `spaces.sh` works only because its keys are numeric monitor IDs.

## Updating App Icons

The `plugins/icon_map_fn.sh` mappings and `sketchybar-app-font.ttf` font are generated from the cloned repo at `sketchybar-app-font/` (upstream: `kvndrsslr/sketchybar-app-font`). To update:

```bash
cd sketchybar-app-font
git pull
npm install   # only if dependencies changed
node build.js
cp dist/sketchybar-app-font.ttf ~/Library/Fonts/sketchybar-app-font.ttf
```

Then copy the case statement body from `dist/icon_map.sh` into `plugins/icon_map_fn.sh`, keeping the function name as `icon_map` (upstream uses `__icon_map`). Finally run `sketchybar --reload`.

The font is also installed via `brew install --cask font-sketchybar-app-font`, but the cask only provides the font file — icon mappings must be updated manually from the repo build.

## Reloading

After making changes, run `sketchybar --reload` to apply. If `aerospace.toml` was changed, also reload AeroSpace config (service mode: alt-shift-; then esc).
