# About this system

Context for AI coding agents, loaded in every session regardless of the
working directory. Source: `~/dotfiles/ai/AGENTS.md`.

## Key directories

### `~/dotfiles`: config files and scripts (private)

- Private GitHub repo `ffyeins/dotfiles` holding the tools and configurations
  the user shares between devices.
- Configs take effect through symlinks made by hand (see its README):
  `~/.zshrc`, `~/.zshenv`, `~/.gitconfig`, `~/.tmux.conf`, and
  `~/.config/<app>` for nvim, lazygit, yazi, ghostty, aerospace, sketchybar
  and borders. Edit files in `~/dotfiles`. A new config file has no effect
  until it is linked.
- `scripts/`: utility scripts, run through aliases in `.zshrc` rather than
  from PATH.
- `docs/`: the user's own notes. Don't add files there; put a note about a
  config next to that config.
- `ai/`: this file.
- `~/dev/public-dotfiles` is a public repo with the dotfiles items that can
  be made public. They're copied from `~/dotfiles` by the paths in its
  `file-list.txt`, which include all of `.config/`, `docs/`, `.zshrc`,
  `.gitconfig` and `.tmux.conf`, so anything added under those paths goes
  public on the next sync.

### `~/dev`: personal projects

- One directory per project, usually its own git repo. Most push to
  `github.com/ffyeins/<name>`; some are local only.
- Many projects have their own `CLAUDE.md` or `AGENTS.md`. Read it before
  working in that project.
- Languages: Go, Java (Maven and Gradle), Python, shell, Node.

## Shell

- `ls` is aliased to eza, whose flags differ from ls (`-t` takes a value,
  `-S` means blocksize). Use `command ls` for standard ls flags.
- `bat` is set to never page and to plain style.
- Git aliases: `git st` = status, `git co` = checkout, `git ci` = commit,
  `git br` = branch, `git cm "msg"` = commit -m.

## Git Commit Policy

Never commit in my repos. Never offer, suggest, or ask about committing — not
as a question, not as a closing "want me to commit?". Committing is mine alone.

When work is done and the tree is dirty, stop after reporting what changed.
Saying "uncommitted" as a plain status fact is fine; proposing to fix it is not.

Exception: throwaway repos you create under /tmp or $TMPDIR (e.g. your
scratchpad) to test or demonstrate something. Any git operation is fine there,
commit/push/pull included. A push must go to another throwaway repo, never a
network remote.
