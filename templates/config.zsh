# Set the directory we want to store zinit and plugins
ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"

# Download zinit, if it's not there yet
if [ ! -d "$ZINIT_HOME" ]; then
	mkdir -p "$(dirname $ZINIT_HOME)"
	git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
fi

# Source/Load zinit
source "${ZINIT_HOME}/zinit.zsh"

PATH="$PATH:$HOME/.local/bin"

eval "$(oh-my-posh init zsh --config $HOME/.config/ohmyposh/zen.toml)"

# Plugins
# zinit light zsh-users/zsh-completions
zinit light zsh-users/zsh-autosuggestions
zinit light zsh-users/zsh-syntax-highlighting
zinit light Aloxaf/fzf-tab

zinit light MichaelAquilina/zsh-you-should-use
zinit light wfxr/forgit
# zinit light unixorn/git-extra-commands
if command -v python &>/dev/null || command -v python3 &>/dev/null; then
	zinit light djui/alias-tips
fi
zinit light hlissner/zsh-autopair

# Add in snippets
zinit snippet OMZP::sudo
zinit snippet OMZP::command-not-found

# Load completions
autoload -U compinit && compinit

zinit cdreplay -q

# Keybinding
bindkey -e
bindkey '^p' history-search-backward
bindkey '^n' history-search-forward

bindkey '^[[1;5C' forward-word
bindkey '^[[1;5D' backward-word

bindkey '^[[1;3C' forward-word
bindkey '^[[1;3D' backward-word

bindkey '^H' backward-kill-word

# History
HISTSIZE=5000
HISTFILE=~/.zsh_history
SAVEHIST=$HISTSIZE
HISTDUP=erase
setopt appendhistory
setopt sharehistory
setopt hist_ignore_space
setopt hist_ignore_all_dups
setopt hist_save_no_dups
setopt hist_ignore_dups
setopt hist_find_no_dups

# Options
setopt autocd

# Completion styling
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' menu no
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'ls --color $realpath'

# Syntax highlighting customization
ZSH_HIGHLIGHT_STYLES[suffix-alias]=fg=white,underline
ZSH_HIGHLIGHT_STYLES[precommand]=fg=standout
ZSH_HIGHLIGHT_STYLES[arg0]=fg=standout
ZSH_HIGHLIGHT_STYLES[path]=none
ZSH_HIGHLIGHT_STYLES[path_prefix]=none
ZSH_HIGHLIGHT_STYLES[autodirectory]=fg=blue
ZSH_HIGHLIGHT_STYLES[cursor-matchingbracket]=fg=green

# Aliases
alias help=run-help

alias ls='ls -G --color=auto'
alias l='ls -lah'
alias la='ls -lAh'
alias ll='ls -lh'
alias lsa='ls -lah'

# Fzf shell integration
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# Import local config
if [[ -f ~/.zshrc.local ]]; then
	source ~/.zshrc.local
fi
