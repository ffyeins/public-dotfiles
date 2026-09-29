# Public dotfiles

## How to use

Add file/directory to the list in `file-list.txt`.

Then, run:

```bash
rsync -arL --files-from=/Users/fran/dev/public-dotfiles/file-list.txt ~/dotfiles/ ~/dev/public-dotfiles/
```

## Symlinks

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
ln -sf "$DOTFILES/.config/sketchybar" ~/.config/sketchybar
ln -sf "$DOTFILES/.config/borders" ~/.config/borders
ln -sf "$DOTFILES/.config/aerospace" ~/.config/aerospace
# Work machine: use this instead of the aerospace line above
# ln -sf "$DOTFILES/.config/aerospace-work" ~/.config/aerospace

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

