# Variabili XDG e dei tool: environment.sessionVariables in ~/.nixos (modules/base.nix)
typeset -U path # niente doppioni in PATH nelle shell annidate
path=($HOME/.local/bin $path)

autoload -U colors && colors

bindkey -a '^[[3~' delete-char
bindkey "^[[3~" delete-char
bindkey "^H" backward-delete-char
bindkey "^?" backward-delete-char

# # Keybindings
bindkey "^a" beginning-of-line
bindkey "^e" end-of-line
bindkey '^I' expand-or-complete-prefix

# Fix home and end binding
bindkey "^[[H" beginning-of-line
bindkey "^[[F" end-of-line

# Ctrl+freccia: parola per parola
bindkey "^[[1;5C" forward-word
bindkey "^[[1;5D" backward-word

# #############
# #  Aliases  #
# #############

alias a="cd"
alias v="nvim"
alias emacs="emacs --init-directory=~/.dotfiles/.config/emacs"
alias ,,="fc -ln -1 | wl-copy"
alias e='emacsclient --alternate-editor=""'
alias ls="ls --color"
alias -g V="sudoedit"
alias -s {yml,yaml,lua,c,tex}=nvim #Auto open file with nvim based on extension
alias lg="lazygit"
alias ppttopdf="libreoffice --headless --invisible --convert-to pdf"

# # Variables
export EDITOR='emacsclient -c'
export VISUAL='emacsclient -c'
# export BROWSER='chromium'
export PAGER='moor -colors "auto" -no-statusbar'
export HISTFILE="${XDG_STATE_HOME:-$HOME/.local/state}"/zsh/history
[[ -d ${HISTFILE:h} ]] || mkdir -p ${HISTFILE:h} # su una macchina nuova la cartella non c'è e la history non si salva
HISTSIZE=100000000
SAVEHIST=100000000

setopt autocd autopushd
setopt SHARE_HISTORY      # include già l'append incrementale
setopt EXTENDED_HISTORY   # Write the history file in the ':start:elapsed;command' format.

function yazi-wrapper() {
    local tmp="$(mktemp -t "yazi-cwd.XXXXX")"
    yazi "$@" --cwd-file="$tmp"
    if cwd="$(cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
        cd -- "$cwd"
    fi
    rm -f -- "$tmp"
}

bindkey -s '^f' 'yazi-wrapper\n'


##FZF config
export FZF_DEFAULT_OPTS='--height 40% --layout=reverse --select-1'
export FZF_DEFAULT_COMMAND='rg --files --hidden --glob '"'"'!.git/'"'"

# Edit in the command in vim
autoload edit-command-line
zle -N edit-command-line
bindkey '^v' edit-command-line

PROMPT=' %(?.%F{blue}%B𝝍%b.%F{red}?%?)%f%F{white} • '
RPROMPT='%B%F{blue}%~%f%b'

# Completion: zsh-completions va in fpath prima di compinit, che gira una volta sola.
# Dump in cache, ricontrollato solo se ha più di 24h.
source ~/.local/lib/zpico/zpico.zsh
zpico add zsh-users/zsh-completions
_zcompdump=${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcompdump
[[ -d ${_zcompdump:h} ]] || mkdir -p ${_zcompdump:h}
autoload -Uz compinit
_stale=($_zcompdump(N.mh+24))
if [[ ! -f $_zcompdump || -n $_stale ]]; then compinit -d $_zcompdump; else compinit -C -d $_zcompdump; fi
unset _zcompdump _stale
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
zstyle ':completion:*' format $'\e[2;37mCompleting %d\e[m'
export CARAPACE_BRIDGES='zsh,fish,bash,inshellisense' # optional
source <(carapace _carapace)

# fzf-tab subito dopo compinit, syntax-highlighting per ultimo
zpico add Aloxaf/fzf-tab
zpico add zsh-users/zsh-autosuggestions
zpico add hlissner/zsh-autopair

eval "$(zoxide init zsh)"

zpico add zsh-users/zsh-syntax-highlighting
