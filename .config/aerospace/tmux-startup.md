# Tmux startup sessions

When AeroSpace starts, `startup.sh` (in this directory) runs
`~/dotfiles/scripts/tmux_start.sh main` in the iTerm window on workspace T and
`~/dotfiles/scripts/tmux_start.sh secondary` in the one on Y.

`tmux_start.sh` builds a session only if it doesn't exist yet, then attaches.
An existing session is never changed, so edits apply to the next fresh session.

## Adding behavior

Edit `build_main` in `~/dotfiles/scripts/tmux_start.sh`. Panes are addressed as
`main:<window>.<pane>`, numbered from 0, left to right, then top to bottom.

```bash
# Run a command in a pane (C-m = Enter; omit it to type without running)
tmux send-keys -t main:0.0 'git status' C-m

# Split a pane (-d keeps focus on the original pane)
tmux split-window -d -h -t main:2.0 -c ~          # left | right
tmux split-window -d -v -t main:2.0 -c ~ -l 30%   # top / bottom, new pane 30%

# Add a window
tmux new-window -d -t main:3 -n logs -c ~
```

Keep paths in variables at the top of the script, next to `repo_dir_1`–`3`.

To give `secondary` a layout, add a `build_secondary` function and a
`secondary) build_secondary ;;` line to the `case`.

## Testing

Build on a throwaway tmux server so your live sessions aren't touched:

```bash
env -u TMUX TMUX_TMPDIR="$(mktemp -d)" ~/dotfiles/scripts/tmux_start.sh main
```

Look around, then run `tmux kill-server` **inside** that test session.
