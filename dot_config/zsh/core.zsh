# Shell behavior
setopt interactive_comments
setopt auto_cd
setopt auto_pushd
setopt pushd_ignore_dups
setopt pushdminus

HISTFILE="${ZDOTDIR:-$HOME}/.zsh_history"
HISTSIZE=50000
SAVEHIST=50000
setopt append_history
setopt extended_history
setopt hist_find_no_dups
setopt hist_ignore_all_dups
setopt hist_ignore_space
setopt hist_reduce_blanks
setopt inc_append_history
setopt share_history

bindkey -e
autoload -Uz up-line-or-beginning-search down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
zmodload zsh/terminfo 2>/dev/null
[[ -n "${terminfo[kcuu1]:-}" ]] && bindkey "${terminfo[kcuu1]}" up-line-or-beginning-search
[[ -n "${terminfo[kcud1]:-}" ]] && bindkey "${terminfo[kcud1]}" down-line-or-beginning-search
bindkey '^[[A' up-line-or-beginning-search
bindkey '^[[B' down-line-or-beginning-search
bindkey '^[OA' up-line-or-beginning-search
bindkey '^[OB' down-line-or-beginning-search

export EDITOR=nvim
export VISUAL=nvim
export CLICOLOR=1
export LSCOLORS="gxfxcxdxbxegedabagacad"

# Personal tools
if command -v podman >/dev/null 2>&1 && ! command -v docker >/dev/null 2>&1; then
  alias docker='podman'
fi
alias python='python3'
alias pip='pip3'
alias lg='lazygit'
alias oc='opencode'
alias cc='claude --dangerously-skip-permissions'
alias cx='codex --dangerously-bypass-approvals-and-sandbox'
alias lc='lzc-cli'

# Files and navigation
alias l='ls -CF'
alias ll='ls -lhF'
alias la='ls -lAhF'
alias ...='../..'
alias ....='../../..'
alias .....='../../../..'
alias md='mkdir -p'
alias rd='rmdir'

# Git essentials retained from the previous Oh My Zsh setup.
alias g='git'
alias ga='git add'
alias gaa='git add --all'
alias gb='git branch'
alias gba='git branch --all'
alias gbd='git branch --delete'
alias gbD='git branch --delete --force'
alias gcb='git checkout -b'
alias gco='git checkout'
alias gc='git commit --verbose'
alias gca='git commit --verbose --all'
alias gcmsg='git commit --message'
alias gd='git diff'
alias gdca='git diff --cached'
alias gds='git diff --staged'
alias gf='git fetch'
alias gl='git pull'
alias glo='git log --oneline --decorate'
alias glog='git log --oneline --decorate --graph'
alias gp='git push'
alias gr='git remote'
alias grh='git reset'
alias grs='git restore'
alias grst='git restore --staged'
alias gst='git status'
alias gss='git status --short'
alias gsb='git status --short --branch'
alias gsw='git switch'
alias gswc='git switch --create'

# npm
alias npmg='npm install --global'
alias npmD='npm install --save-dev'
alias npmO='npm outdated'
alias npmU='npm update'
alias npmL='npm list'
alias npmL0='npm list --depth=0'
alias npmst='npm start'
alias npmt='npm test'
alias npmR='npm run'
alias npmrd='npm run dev'
alias npmrb='npm run build'

# Containers
alias dps='docker ps'
alias dpsa='docker ps -a'
alias dpu='docker pull'
alias dr='docker container run'
alias drit='docker container run -it'
alias drm='docker container rm'
alias dxc='docker container exec'
alias dxcit='docker container exec -it'

if command -v docker-compose >/dev/null 2>&1; then
  alias dco='docker-compose'
else
  alias dco='docker compose'
fi
alias dcb='dco build'
alias dcdn='dco down'
alias dcl='dco logs'
alias dclf='dco logs -f'
alias dcps='dco ps'
alias dcup='dco up'
alias dcupd='dco up -d'

# Functions
git_current_branch() {
  emulate -L zsh
  command git symbolic-ref --quiet --short HEAD 2>/dev/null ||
    command git rev-parse --short HEAD 2>/dev/null
}

y() {
  emulate -L zsh
  setopt local_options no_sh_word_split

  local yazi_cmd tmp cwd
  yazi_cmd="$(command -v yazi 2>/dev/null)" || {
    print -u2 "yazi not found"
    return 127
  }

  tmp="$(mktemp -t 'yazi-cwd.XXXXXX')" || return
  command "$yazi_cmd" "$@" --cwd-file="$tmp"
  if cwd="$(command cat -- "$tmp")" && [[ -n "$cwd" && "$cwd" != "$PWD" && -d "$cwd" ]]; then
    builtin cd -- "$cwd"
  fi
  command rm -f -- "$tmp"
}

fzf-cd() {
  emulate -L zsh
  local dir
  dir="$(fd --type directory "${1:-.}" | fzf --preview 'ls -la {} | head -20')" || return
  [[ -n "$dir" ]] && builtin cd -- "$dir"
}

fuck() {
  unfunction fuck
  eval "$(thefuck --alias)"
  fuck "$@"
}

# Completion
typeset -U fpath FPATH
fpath=("$ZSH_CONFIG_DIR/completions" $fpath)

autoload -Uz compinit
zmodload zsh/parameter

typeset -g ZSH_COMPDUMP="${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcompdump-${ZSH_VERSION}"
if [[ -r "$ZSH_COMPDUMP" ]]; then
  compinit -C -d "$ZSH_COMPDUMP"
else
  # First-shell fallback. Normal rebuilds happen during `chezmoi apply`.
  mkdir -p "${ZSH_COMPDUMP:h}"
  compinit -i -d "$ZSH_COMPDUMP"
fi

zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
zstyle ':completion:*' menu select
zstyle ':completion:*' use-cache true
zstyle ':completion:*' cache-path "${XDG_CACHE_HOME:-$HOME/.cache}/zsh/completion"

if (( ${+functions[_lzc-cli_yargs_completions]} == 0 )); then
  _lzc-cli_yargs_completions() {
    local reply
    local saved_ifs=$IFS
    IFS=$'\n' reply=($(COMP_CWORD="$((CURRENT - 1))" COMP_LINE="$BUFFER" COMP_POINT="$CURSOR" \
      lzc-cli --get-yargs-completions "${words[@]}"))
    IFS=$saved_ifs
    _describe 'values' reply
  }
  compdef _lzc-cli_yargs_completions lzc-cli
fi

# Environment and integrations
typeset -U path PATH

export PNPM_HOME="$HOME/Library/pnpm"
export BUN_INSTALL="$HOME/.bun"

# Android SDK - auto-detect from env, common locations, or adb on PATH
typeset -g _android_home="${ANDROID_HOME:-}"
if [[ -z "$_android_home" ]]; then
  local _candidates=(
    "$HOME/Library/Android/sdk"   # macOS default
    "$HOME/Android/Sdk"           # Linux default
  )
  for _dir in "$_candidates[@]"; do
    if [[ -d "$_dir/platform-tools" ]]; then
      _android_home="$_dir"
      break
    fi
  done
fi
if [[ -z "$_android_home" ]]; then
  local _adb="$(command -v adb 2>/dev/null)"
  if [[ -n "$_adb" ]]; then
    _android_home="${_adb:h:h}"   # adb lives in platform-tools/, one level up
  fi
fi

if [[ -n "$_android_home" && -d "$_android_home/platform-tools" ]]; then
  export ANDROID_HOME="$_android_home"
  local bt_dir="${_android_home}/build-tools"
  local bt_ver=""
  if [[ -d "$bt_dir" ]]; then
    bt_ver="$(command ls -1 "$bt_dir" 2>/dev/null | sort -V | tail -1)"
  fi
  local ct_dir="${_android_home}/cmdline-tools/latest/bin"
  local android_paths=("${_android_home}/platform-tools")
  [[ -d "$ct_dir" ]] && android_paths=("$ct_dir" $android_paths)
  [[ -n "$bt_ver" ]] && android_paths+=("$bt_dir/$bt_ver")
  path=(
    $android_paths
    $path
  )
fi
unset _android_home

path=(
  "$HOME/go/bin"
  $path
)
export PATH

# Coding Agent Experimental Flags
export OPENCODE_EXPERIMENTAL_PLAN_MODE=1
export OPENCODE_EXPERIMENTAL_MARKDOWN=1
export OPENCODE_EXPERIMENTAL_LSP_TOOL=1
export OPENCODE_EXPERIMENTAL_LSP_TY=1
export OPENCODE_ENABLE_QUESTION_TOOL=1
export CLAUDE_CODE_NEW_INIT=1

for integration in zoxide starship; do
  [[ -r "$ZSH_CONFIG_DIR/generated/$integration.zsh" ]] &&
    source "$ZSH_CONFIG_DIR/generated/$integration.zsh"
done

# Load fzf's 23 KB shell integration only when one of its widgets is used.
_fzf_lazy_load() {
  (( ${+widgets[fzf-completion]} )) && return 0
  [[ -r "$ZSH_CONFIG_DIR/generated/fzf.zsh" ]] || return 1
  # Pin the fallback widget so fzf does not capture our lazy ^I wrapper,
  # which would recurse on a no-trigger completion like `cd dir<TAB>`.
  : ${fzf_default_completion:=expand-or-complete}
  source "$ZSH_CONFIG_DIR/generated/fzf.zsh"
}

_fzf_lazy_file() {
  _fzf_lazy_load || return
  zle fzf-file-widget
}

_fzf_lazy_cd() {
  _fzf_lazy_load || return
  zle fzf-cd-widget
}

_fzf_lazy_history() {
  _fzf_lazy_load || return
  zle fzf-history-widget
}

_fzf_lazy_completion() {
  _fzf_lazy_load || return
  zle fzf-completion
}

zle -N _fzf_lazy_file
zle -N _fzf_lazy_cd
zle -N _fzf_lazy_history
zle -N _fzf_lazy_completion
bindkey '^T' _fzf_lazy_file
bindkey '\ec' _fzf_lazy_cd
bindkey '^R' _fzf_lazy_history
bindkey '^I' _fzf_lazy_completion

if [[ -r "$ZSH_CONFIG_DIR/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh" ]]; then
  source "$ZSH_CONFIG_DIR/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh"
fi

# Keep syntax highlighting last.
if [[ -r "$ZSH_CONFIG_DIR/plugins/fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh" ]]; then
  # Redirect fsh runtime scratch out of the chezmoi-managed plugin dir.
  export FAST_WORK_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/fsh"
  [[ -d "$FAST_WORK_DIR" ]] || mkdir -p "$FAST_WORK_DIR"
  # Seed the secondary theme so fsh never downloads it on first prompt.
  if [[ ! -e "$FAST_WORK_DIR/secondary_theme.zsh" ]]; then
    cp "$ZSH_CONFIG_DIR/plugins/fast-syntax-highlighting/share/free_theme.zsh" \
      "$FAST_WORK_DIR/secondary_theme.zsh" 2>/dev/null ||
      : >"$FAST_WORK_DIR/secondary_theme.zsh"
  fi
  source "$ZSH_CONFIG_DIR/plugins/fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh"
  # Default comment color is near-invisible on dark backgrounds.
  FAST_HIGHLIGHT_STYLES[comment]='fg=244'
fi
