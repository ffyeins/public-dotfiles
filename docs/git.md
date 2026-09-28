# Git

## Git Worktrees

```bash
# Create a worktree with a new branch
git worktree add -b new-branch ../new-branch-dir

git worktree list    # See all worktrees
git worktree remove <path>   # Remove a worktree when done
```

## Nvim diff tool

To start run `git mergetool`

- `]c` - Jump to next conflict
- `[c` - Jump to previous conflict

```bash
:diffget LO     # accept your changes
:diffget BA     # accept base version
:diffget RE     # accept their changes

:wqa            # save and quit
```

## Ignore local changes to that file

```bash
git update-index --skip-worktree path/to/your/file
# to undo:
git update-index --no-skip-worktree path/to/your/file
```

## Sort git branches

```bash
git branch --sort=-committerdate
```

## Generate git patch

```bash
# Generate patch
git diff > ~/local-setup.patch

# Apply it
git apply ~/local-setup.patch
```
