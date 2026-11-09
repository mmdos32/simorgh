# Simorgh — zsh configuration
# Plugins are installed system-wide by the installer (pacman):
#   zsh-autosuggestions, zsh-syntax-highlighting

export PATH="$HOME/.local/bin:$PATH"
export EDITOR="nvim"
export VISUAL="code"
export LANG="${LANG:-en_US.UTF-8}"

# History
HISTFILE="$HOME/.zsh_history"
HISTSIZE=5000
SAVEHIST=5000
setopt HIST_IGNORE_DUPS SHARE_HISTORY APPEND_HISTORY

# Completion
autoload -Uz compinit && compinit
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'

# Plugins (guarded so a missing package never breaks the shell)
[[ -f /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh ]] \
  && source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
[[ -f /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]] \
  && source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# Prompt
if command -v starship >/dev/null; then
  eval "$(starship init zsh)"
fi

# Aliases
alias ls='ls --color=auto'
alias ll='ls -lah'
alias la='ls -A'
alias grep='grep --color=auto'
alias update='yay -Syu'
alias cleanup='yay -Yc --noconfirm'
alias simorgh='simorgh-menu'
alias theme='simorgh-theme'
alias ff='fastfetch'

# Modern CLI tools (installed by the installer; guarded if missing)
command -v zoxide >/dev/null && eval "$(zoxide init zsh)"
[[ -f /usr/share/fzf/key-bindings.zsh ]] && source /usr/share/fzf/key-bindings.zsh
if command -v eza >/dev/null; then
  alias ls='eza --icons'
  alias ll='eza -lh --icons'
  alias la='eza -A --icons'
fi
command -v bat >/dev/null && alias cat='bat --paging=never'

# Start Hyprland automatically on the first TTY (only if SDDM is not used)
if [[ -z "$DISPLAY" && "$XDG_VTNR" -eq 1 && -z "$WAYLAND_DISPLAY" ]]; then
  if command -v Hyprland >/dev/null && systemctl is-active --quiet sddm 2>/dev/null; then
    : # SDDM is active, do nothing — graphical login handles it
  elif command -v Hyprland >/dev/null; then
    exec Hyprland
  fi
fi
