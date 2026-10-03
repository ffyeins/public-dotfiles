# Dedupe PATH, keeping first occurrence, so the PATH edits below stay
# idempotent across nested login shells (each re-runs path_helper + .zshrc).
typeset -U path PATH

########################
### TERMINAL STYLING ###
########################

# Load version control information
autoload -Uz vcs_info
precmd() {
    vcs_info
}

# Format the vcs_info_msg_0_ variable
zstyle ':vcs_info:git:*' formats '%b'

# Check if we're in a git repository
is_git_repo() {
    [[ -n ${vcs_info_msg_0_} ]]
}

# Function to display git branch
git_prompt_info() {
    if is_git_repo; then
        echo "%F{3}⎇  ${vcs_info_msg_0_}%f"
    fi
}

PROMPT='┌─ %B%F{110}%n@%m %F{7}%~ $(git_prompt_info)%f%b'$'\n''└─ %# '

setopt promptsubst

### end of TERMINAL STYLING ###
# ===========================================================================

###############
### SCRIPTS ###
###############
export XDG_CONFIG_HOME="$HOME/.config"

# Go
export GOPATH=$HOME/go
export PATH="$PATH:$GOPATH/bin"

SCRIPTS_DIR=~/dotfiles/scripts

alias cheat="$SCRIPTS_DIR/fuzzy-cheatsheet/fuzzy_cheatsheet.sh"
alias mdprint="$SCRIPTS_DIR/mdprint.sh"
# alias md2html="$SCRIPTS_DIR/mdread/md2html/md2html.py" # DEPRECATED
export PATH="$HOME/dev/mdread:$PATH"

alias runcaffeinate="$SCRIPTS_DIR/run_caffeinate.sh"
alias killcaffeinate='tmux kill-session -t z_caffeinate 2>/dev/null'

export BAT_PAGING=never # Removes pagination for bat command
export BAT_STYLE=plain
alias batf='bat --paging=always --style=full'  # "bat full"

alias ls='eza --classify=auto --group-directories-first' # appends type indicators to filenames; a bare -F would eat the next argument
alias lst='eza --classify=auto -a --group-directories-first --git-ignore -T -L 3'

alias lg='lazygit'

alias traffic-report='~/dotfiles/scripts/commute-report'

alias tq='ask tmux' # quick tmux questions: ~/dev/helper-agent

### end of SCRIPTS ###
# ===========================================================================

# yazi wrapper
function y() {
	local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
	command yazi "$@" --cwd-file="$tmp"
	IFS= read -r -d '' cwd < "$tmp"
	[ "$cwd" != "$PWD" ] && [ -d "$cwd" ] && builtin cd -- "$cwd"
	command rm -f -- "$tmp"
}

# Load OS-specific configuration
if [[ "$(uname)" == "Linux" ]]; then
    [[ -f ~/dotfiles/.zshrc.linux ]] && source ~/dotfiles/.zshrc.linux
elif [[ "$(uname)" == "Darwin" ]]; then
    [[ -f ~/dotfiles/.zshrc.macos ]] && source ~/dotfiles/.zshrc.macos
fi

# Completion and syntax highlighting (must be after all plugins/widgets)
autoload -Uz compinit
compinit
if [[ "$(uname)" == "Darwin" ]]; then
    source /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
elif [[ -f /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]]; then
    source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
fi
