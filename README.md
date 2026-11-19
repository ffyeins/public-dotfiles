# Public dotfiles

The public part of my dotfiles: zsh, git, tmux, Neovim and terminal configs,
macOS window management, Obsidian, AI agent setup and a few scripts. The
source is a private `~/dotfiles` repo; this one holds copies of the paths
listed in `file-list.txt`.

## Contents

- `.config/`: aerospace (`aerospace-work` for the work machine), bat, borders,
  ghostty, lazygit, nvim, sketchybar, yazi
- `.zshenv`: PATH setup, sourced by every zsh invocation
- `.zshrc`, `.zshrc.macos`: shell config; `.zshrc` sources `.zshrc.macos` on macOS
- `.gitconfig`: git aliases, delta as the pager
- `.tmux.conf`: Catppuccin theme, custom bindings
- `.obsidian/`: Obsidian settings, plugins, themes and snippets
- `ai/`: `AGENTS.md` (context for AI coding agents) and Claude Code config
- `docs/`: notes
- `fonts/`: JetBrains Mono Nerd Font
- `gitfiles/`: a `.gitignore` template (OS, editor and secret files)
- `iterm2/`: iTerm2 preferences and color schemes (macOS)
- `scripts/`: mdread, mdprint and tmux helpers (see [Scripts](#scripts))

## Syncing from ~/dotfiles

Add a file or directory to `file-list.txt`, then run:

```bash
./sync.sh
```

It runs `rsync -arL --files-from=file-list.txt ~/dotfiles/ <this repo>/`,
then commits everything in the repo with the message "update" (`git add .`
and the `cm` alias from `.gitconfig`) and shows `git status`. It doesn't push.

- **It always commits.** Extra arguments go to rsync, so `./sync.sh -nv`
  doesn't copy anything, but it still commits whatever had already changed
  here. To preview without committing, run rsync yourself:

  ```bash
  rsync -arLnv --files-from=file-list.txt ~/dotfiles/ ./
  ```

- **Everything under a listed directory goes public**, including files added
  to it later.
- **Symlinks are copied as the files they point to** (`-L`).
- **Nothing is deleted.** A file removed from `~/dotfiles`, or a path removed
  from `file-list.txt`, stays here until you `git rm` it.

## Setup

### 1. Clone

```bash
git clone https://github.com/ffyeins/public-dotfiles.git ~/dotfiles
```

Clone it to `~/dotfiles`. `.zshrc`, `.tmux.conf` and the AeroSpace startup
script load files from that path.

### 2. Install tools

```bash
brew install neovim tmux bat eza fzf git-delta lazygit yazi
brew install tree-sitter-cli          # required by nvim-treesitter
brew install zsh-syntax-highlighting  # sourced at the end of .zshrc
brew install comrak                   # mdread and mdtohtml
brew install jq                       # Claude Code git-guard hook
```

### 3. Install fonts

```bash
tar -xzf ~/dotfiles/fonts/JetBrainsMonoNerdFontMono.tar.gz

# macOS: double-click each .ttf file or copy them to ~/Library/Fonts/
# Linux: copy them to ~/.local/share/fonts/ and run 'fc-cache -f -v'
```

### 4. Symlinks

```bash
DOTFILES=~/dotfiles

# Shell, git, tmux
ln -sf "$DOTFILES/.zshenv" ~/.zshenv
ln -sf "$DOTFILES/.zshrc" ~/.zshrc
ln -sf "$DOTFILES/.gitconfig" ~/.gitconfig
ln -sf "$DOTFILES/.tmux.conf" ~/.tmux.conf

# ~/.config
mkdir -p ~/.config
ln -sf "$DOTFILES/.config/nvim" ~/.config/nvim
ln -sf "$DOTFILES/.config/lazygit" ~/.config/lazygit
ln -sf "$DOTFILES/.config/yazi" ~/.config/yazi
ln -sf "$DOTFILES/.config/ghostty" ~/.config/ghostty
ln -sf "$DOTFILES/.config/bat" ~/.config/bat
ln -sf "$DOTFILES/.config/sketchybar" ~/.config/sketchybar
ln -sf "$DOTFILES/.config/borders" ~/.config/borders
ln -sf "$DOTFILES/.config/aerospace" ~/.config/aerospace
# Work machine: use this instead of the aerospace line above
# ln -sf "$DOTFILES/.config/aerospace-work" ~/.config/aerospace

# Compile .config/bat/themes into bat's cache, where delta also reads its
# syntax themes. Rerun after adding or changing a theme.
bat cache --build

# Claude Code: CLAUDE.md (imports ai/AGENTS.md), settings and the git-guard hook
# (the hook needs jq; ln -sf replaces existing files, so back them up first)
mkdir -p ~/.claude/hooks
ln -sf "$DOTFILES/ai/claude/CLAUDE.md" ~/.claude/CLAUDE.md
ln -sf "$DOTFILES/ai/claude/settings.json" ~/.claude/settings.json
ln -sf "$DOTFILES/ai/claude/hooks/git-guard.sh" ~/.claude/hooks/git-guard.sh

# Obsidian (repeat for each vault)
VAULT=~/your-vault
mkdir -p "$VAULT/.obsidian"
ln -sf "$DOTFILES/.obsidian/app.json" "$VAULT/.obsidian/app.json"
ln -sf "$DOTFILES/.obsidian/appearance.json" "$VAULT/.obsidian/appearance.json"
ln -sf "$DOTFILES/.obsidian/core-plugins.json" "$VAULT/.obsidian/core-plugins.json"
ln -sf "$DOTFILES/.obsidian/community-plugins.json" "$VAULT/.obsidian/community-plugins.json"
ln -sf "$DOTFILES/.obsidian/plugins" "$VAULT/.obsidian/plugins"
ln -sf "$DOTFILES/.obsidian/themes" "$VAULT/.obsidian/themes"
ln -sf "$DOTFILES/.obsidian/snippets" "$VAULT/.obsidian/snippets"
```

- Don't link Obsidian's `workspace.json` or `graph.json`. Each vault has its
  own.
- `.zshenv` is sourced by every zsh invocation, including non-interactive ones
  (`scp`, `rsync`, `ssh host cmd`, cron). Keep it silent: anything it prints
  breaks those. It holds PATH setup only.

### 5. Other AI agents

They all read the same `ai/AGENTS.md`:

```bash
# Codex CLI
mkdir -p ~/.codex && ln -sf ~/dotfiles/ai/AGENTS.md ~/.codex/AGENTS.md
# Gemini CLI
mkdir -p ~/.gemini && ln -sf ~/dotfiles/ai/AGENTS.md ~/.gemini/GEMINI.md
# opencode
mkdir -p ~/.config/opencode && ln -sf ~/dotfiles/ai/AGENTS.md ~/.config/opencode/AGENTS.md
# GitHub Copilot CLI
mkdir -p ~/.copilot && ln -sf ~/dotfiles/ai/AGENTS.md ~/.copilot/copilot-instructions.md
```

Cursor has no global rules file. Paste the contents into Cursor Settings →
Rules → User Rules instead.

### 6. tmux plugins

```bash
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
```

Then, inside tmux, press `prefix` + `I` to install the plugins.

### 7. iTerm2 (macOS)

In iTerm2 → Settings → General → Settings:

- Check "Load settings from a custom folder" and select `~/dotfiles/iterm2`
- Check "Save changes to folder when iTerm2 quits"

### 8. Window management (macOS)

AeroSpace, Sketchybar and JankyBorders:

```bash
brew install --cask nikitabobko/tap/aerospace
brew tap FelixKratz/formulae
brew install sketchybar borders
brew install --cask font-sketchybar-app-font

brew services start sketchybar
brew services start borders
```

- AeroSpace is an app. Open it from `/Applications`, or set
  `start-at-login = true` in `aerospace.toml`.
- Sketchybar also needs the Roboto Mono font. If workspace icons show empty,
  run `brew upgrade --cask font-sketchybar-app-font`.
- Turn off System Settings → Desktop & Dock → "Displays have separate Spaces"
  (then log out and back in). AeroSpace misbehaves with it on.

## Scripts

They run through aliases in `.zshrc` (`SCRIPTS_DIR=~/dotfiles/scripts`) and
bindings in `.tmux.conf`, not from PATH.

| Run with | Script | What it does |
|----------|--------|--------------|
| `mdread file.md` | `mdread/mdread --light` | Renders markdown like GitHub does and opens it in the browser. Needs `comrak`. `--help` lists options |
| `mdtohtml file.md` | `mdread/mdtohtml` | Writes a GitHub-styled `.html` file next to each markdown file |
| `mdprint file.md` | `mdprint.sh` | Runs the prebuilt `mdprint` binary for macOS (arm64) or Linux. `mdprint -` reads stdin |
| `runcaffeinate`, `killcaffeinate` | `run_caffeinate.sh` | Keeps the Mac awake with `caffeinate -d` in a background tmux session, and stops it |
| `prefix` + `y` | `tmux_copy_last_output.sh` | Copies the last command and its output in the pane |
| `prefix` + `w` | `tmux_fuzzy_switch.sh` | Fuzzy-finds a tmux session or window and switches to it |
| AeroSpace startup | `tmux_start.sh main\|secondary` | Builds a tmux session with a standard layout, then attaches. Its repo paths are placeholders |

The `cheat`, `traffic-report` and `tq` aliases in `.zshrc` point to scripts
that aren't in this repo.

## Git aliases

| Alias | Command |
|-------|---------|
| `git st` | `git status` |
| `git co` | `git checkout` |
| `git ci` | `git commit` |
| `git br` | `git branch` |
| `git cm` | `git commit -m` |
