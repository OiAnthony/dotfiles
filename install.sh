#!/bin/bash
set -e

# ==============================================================================
# dotfiles — 开发环境一键安装脚本
# 用法:
#   curl -fsSL https://raw.githubusercontent.com/OiAnthony/dotfiles/main/install.sh | bash         # 全量
#   curl -fsSL https://raw.githubusercontent.com/OiAnthony/dotfiles/main/install.sh | bash -s -- --tools   # 仅工具链
#   curl -fsSL https://raw.githubusercontent.com/OiAnthony/dotfiles/main/install.sh | bash -s -- --shell   # 仅 Shell
#   curl -fsSL https://raw.githubusercontent.com/OiAnthony/dotfiles/main/install.sh | bash -s -- --agents  # 仅 AI
#   ./install.sh --tools --shell   # 组合
# ==============================================================================

CURRENT_OS="$(uname -s)"
SCRIPT_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"

# ---- 模块标志解析 ----
INSTALL_TOOLS=false
INSTALL_SHELL=false
INSTALL_AGENTS=false

for arg in "$@"; do
  case "$arg" in
    --tools)  INSTALL_TOOLS=true ;;
    --shell)  INSTALL_SHELL=true ;;
    --agents) INSTALL_AGENTS=true ;;
    *) echo "Unknown option: $arg"; echo "Usage: install.sh [--tools] [--shell] [--agents]"; exit 1 ;;
  esac
done

# 无参数 = 全量安装
if ! $INSTALL_TOOLS && ! $INSTALL_SHELL && ! $INSTALL_AGENTS; then
  INSTALL_TOOLS=true
  INSTALL_SHELL=true
  INSTALL_AGENTS=true
fi

echo "🚀 开始安装开发环境..."
echo "   模块: tools=$INSTALL_TOOLS shell=$INSTALL_SHELL agents=$INSTALL_AGENTS"

# ---- 仓库检测与克隆 ----
if [[ ! -f "$SCRIPT_DIR/mise.toml" ]] || [[ ! -d "$SCRIPT_DIR/.agents" ]]; then
  echo "📥 检测到脚本不在仓库目录中，正在克隆仓库..."
  REPO_URL="https://github.com/OiAnthony/dotfiles.git"
  INSTALL_DIR="$HOME/.dotfiles"

  if [[ -d "$INSTALL_DIR/.git" ]]; then
    echo "✅ 仓库已存在，更新到最新版本..."
    cd "$INSTALL_DIR"
    REMOTE_URL=$(git remote get-url origin 2>/dev/null || echo "")
    if [[ "$REMOTE_URL" =~ (https://github\.com/|git@github\.com:)OiAnthony/dotfiles(\.git)?$ ]]; then
      git pull origin main
    else
      echo "⚠️  $INSTALL_DIR 不是目标仓库，跳过更新"
      echo "   当前 remote: $REMOTE_URL"
      echo "   预期 remote: https://github.com/OiAnthony/dotfiles.git"
      exit 1
    fi
  else
    git clone "$REPO_URL" "$INSTALL_DIR"
    cd "$INSTALL_DIR"
  fi

  exec bash "$INSTALL_DIR/install.sh" "$@"
fi

REPO_DIR="$SCRIPT_DIR"

# ---- macOS root 检查 ----
if [[ "$CURRENT_OS" == "Darwin" ]] && [[ "$EUID" -eq 0 ]]; then
  echo "❌ macOS 下检测到 root 用户。Homebrew 要求在非 root 用户下安装。"
  echo ""
  echo "请先创建一个普通用户，再切换到该用户后重新运行此脚本："
  echo "  sudo sysadminctl -addUser <username> -fullName \"<Full Name>\" -password -"
  echo "  cd \"$(printf '%s' "$SCRIPT_DIR")\" && ./install.sh"
  exit 1
fi

# ---- 辅助函数 ----

_ensure_sudo() {
  if [[ "$EUID" -eq 0 ]]; then
    return 0
  fi
  if sudo -n true 2>/dev/null; then
    return 0
  fi
  if [[ -t 0 ]]; then
    echo "  sudo..."
    sudo -v
    return 0
  fi
  if exec 3</dev/tty 2>/dev/null; then
    # shellcheck disable=SC2024
    sudo -v < /dev/tty
    exec 3<&-
    return 0
  fi
  echo "  sudo... FAILED (no tty, run: sudo -v first)"
  exit 1
}

_ensure_json_key() {
  local file="$1" key="$2" value="$3"
  if [[ ! -f "$file" ]]; then
    mkdir -p "$(dirname "$file")"
    printf '{"%s": %s}\n' "$key" "$value" > "$file"
    return 0
  fi
  if grep -q "\"$key\"" "$file" 2>/dev/null; then
    return 0
  fi
  local py
  if command -v python3 &>/dev/null; then
    py="python3"
  elif command -v mise &>/dev/null; then
    py="mise exec python3 -- python3"
  else
    echo "⚠️  python3 不可用，无法更新 $file"
    return 1
  fi
  $py -c "
import json
with open('$file') as f:
    data = json.load(f)
data['$key'] = json.loads('$value')
with open('$file', 'w') as f:
    json.dump(data, f, indent=2)
"
}

_rtk_global_installation_exists() {
  local claude_dir="$HOME/.claude"

  [[ -f "$claude_dir/hooks/rtk-rewrite.sh" ]] && return 0
  [[ -f "$claude_dir/RTK.md" ]] && return 0
  if [[ -f "$claude_dir/settings.json" ]] && \
     grep -Eq '"command"[[:space:]]*:[[:space:]]*"rtk hook claude"' "$claude_dir/settings.json"; then
    return 0
  fi
  if [[ -f "$claude_dir/CLAUDE.md" ]] && grep -qF '@RTK.md' "$claude_dir/CLAUDE.md"; then
    return 0
  fi

  return 1
}

_migrate_rtk() {
  $INSTALL_AGENTS || return 0
  _rtk_global_installation_exists || return 0

  echo ""
  echo "── RTK migration"
  if ! command -v rtk &>/dev/null; then
    echo "  RTK uninstall... FAILED (rtk not found; run: rtk init -g --uninstall)"
    return 1
  fi

  if rtk init -g --uninstall >/dev/null 2>&1; then
    echo "  RTK uninstall... ok"
  else
    echo "  RTK uninstall... FAILED (run: rtk init -g --uninstall)"
    return 1
  fi
}

_install_mise() {
  if ! command -v mise &>/dev/null; then
    curl -fsSL https://mise.run | sh >/dev/null 2>&1
  fi

  export PATH="$HOME/.local/bin:$HOME/.local/share/mise/shims:$PATH"

  if ! command -v mise &>/dev/null; then
    echo "  mise... FAILED (not in PATH: $HOME/.local/bin)"
    exit 1
  fi

  mise self-update -q 2>/dev/null || true

  mkdir -p "$HOME/.config/mise"
  local mise_cfg="$HOME/.config/mise/config.toml"
  # Never silently destroy a hand-written mise config. If a config already
  # exists and is not a symlink to this repo's mise.toml, back it up first.
  if [[ -e "$mise_cfg" || -L "$mise_cfg" ]] && \
     [[ "$(readlink "$mise_cfg" 2>/dev/null)" != "$REPO_DIR/mise.toml" ]]; then
    local bkp_dir
    bkp_dir="$HOME/.dotfiles-backup/$(date -u +%Y%m%dT%H%M%SZ)"
    mkdir -p "$bkp_dir"
    mv "$mise_cfg" "$bkp_dir/config.toml"
    echo "  mise config backed up → $bkp_dir/config.toml"
  fi
  ln -sf "$REPO_DIR/mise.toml" "$mise_cfg"

  (cd "$HOME" && mise use -g bun@latest) >/dev/null 2>&1 || {
    echo "  bun... FAILED"
    exit 1
  }
  mise install -q 2>/dev/null || {
    echo "  mise install... partial (网络受限或限流，可设 https_proxy / GITHUB_TOKEN 重试)"
  }
  echo "  mise + Bun + 工具链... ok"
}

_install_fonts_macos() {
  local font_dir="$HOME/Library/Fonts"
  mkdir -p "$font_dir"

  if ! ls "$font_dir"/MapleMono-NF-CN-*.ttf >/dev/null 2>&1; then
    local tmp; tmp=$(mktemp -d)
    if curl -fsSL -o "$tmp/maple.zip" \
        "https://github.com/subframe7536/maple-font/releases/latest/download/MapleMono-NF-CN.zip"; then
      unzip -q -o "$tmp/maple.zip" -d "$font_dir"
      echo "  Maple Mono NF... ok"
    else
      echo "  Maple Mono NF... FAILED (download error)"
    fi
    rm -rf "$tmp"
  fi

  if ! ls "$font_dir"/JetBrainsMonoNerdFont-*.ttf >/dev/null 2>&1; then
    local tmp; tmp=$(mktemp -d)
    if curl -fsSL -o "$tmp/jb.zip" \
        "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip"; then
      unzip -q -o "$tmp/jb.zip" -d "$font_dir"
      echo "  JetBrains Mono NF... ok"
    else
      echo "  JetBrains Mono NF... FAILED (download error)"
    fi
    rm -rf "$tmp"
  fi
}

_install_base_linux() {
  local pkgs=(git curl wget vim zsh zip unzip tree htop jq build-essential ca-certificates)
  local sudo_cmd=""
  [[ "$EUID" -ne 0 ]] && sudo_cmd="sudo"

  local cmd
  for cmd in git curl wget vim zsh zip unzip tree htop jq make gcc; do
    command -v "$cmd" &>/dev/null || break
  done
  if [[ "$cmd" == "gcc" ]] && command -v gcc &>/dev/null; then
    return 0
  fi

  echo "  Linux 基础工具..."
  if command -v apt-get &>/dev/null; then
    $sudo_cmd apt-get update -y >/dev/null 2>&1
    $sudo_cmd apt-get install -y "${pkgs[@]}" >/dev/null 2>&1
  elif command -v dnf &>/dev/null; then
    $sudo_cmd dnf install -y git curl wget vim zsh zip unzip tree htop jq ca-certificates >/dev/null 2>&1
    $sudo_cmd dnf groupinstall -y "Development Tools" >/dev/null 2>&1 || true
  elif command -v yum &>/dev/null; then
    $sudo_cmd yum install -y git curl wget vim zsh zip unzip tree htop jq ca-certificates >/dev/null 2>&1
    $sudo_cmd yum groupinstall -y "Development Tools" >/dev/null 2>&1 || true
  elif command -v pacman &>/dev/null; then
    $sudo_cmd pacman -Sy --noconfirm git curl wget vim zsh zip unzip tree htop jq base-devel ca-certificates >/dev/null 2>&1
  elif command -v apk &>/dev/null; then
    $sudo_cmd apk add --no-cache git curl wget vim zsh zip unzip tree htop jq build-base ca-certificates >/dev/null 2>&1
  else
    echo "  Linux 基础工具... FAILED (unknown distro)"
    return 1
  fi
  echo "  Linux 基础工具... ok"
}

_configure_default_shell() {
  local current_shell
  current_shell="$(basename "$SHELL")"
  if [[ "$current_shell" == "zsh" ]]; then
    return 0
  fi

  local zsh_path
  zsh_path="$(command -v zsh)"
  if [[ -z "$zsh_path" ]]; then
    echo "  Zsh 默认 Shell... skip (zsh not found)"
    return 0
  fi

  local sudo_cmd=""
  [[ "$EUID" -ne 0 ]] && sudo_cmd="sudo"

  if [[ -n "$sudo_cmd" ]]; then
    _ensure_sudo
  fi

  if [[ -f /etc/shells ]] && ! grep -qxF "$zsh_path" /etc/shells; then
    echo "$zsh_path" | $sudo_cmd tee -a /etc/shells >/dev/null
  fi

  if [[ -n "$sudo_cmd" ]] && $sudo_cmd chsh -s "$zsh_path" "$(id -un)" 2>/dev/null; then
    echo "  Zsh 默认 Shell... ok"
  elif chsh -s "$zsh_path" 2>/dev/null; then
    echo "  Zsh 默认 Shell... ok"
  elif command -v usermod &>/dev/null; then
    $sudo_cmd usermod -s "$zsh_path" "$(id -un)" && \
      echo "  Zsh 默认 Shell... ok"
  else
    echo "  Zsh 默认 Shell... FAILED (run: chsh -s $zsh_path)"
  fi
}

# ==============================================================================
# 模块: tools — 工具链安装
# ==============================================================================
_install_tools() {
  $INSTALL_TOOLS || return 0
  echo ""
  echo "── 工具链"

  if [[ "$CURRENT_OS" == "Darwin" ]]; then
    _configure_default_shell

    if ! command -v brew &> /dev/null; then
      echo "  Homebrew..."
      _ensure_sudo
      NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" >/dev/null 2>&1
      if [[ -f "/opt/homebrew/bin/brew" ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
      fi
      echo "  Homebrew... ok"
    fi

    _install_mise
    _install_fonts_macos

  elif [[ "$CURRENT_OS" == "Linux" ]]; then
    _install_base_linux
    _configure_default_shell
    _install_mise

  else
    echo "  OS... skip: $CURRENT_OS 不受支持"
    exit 1
  fi

  if [[ "$CURRENT_OS" == "Darwin" ]]; then
    export PNPM_HOME="$HOME/Library/pnpm"
    export PATH="$PNPM_HOME:$PATH"
  else
    export PNPM_HOME="$HOME/.local/share/pnpm"
    export PATH="$PNPM_HOME/bin:$PATH"
  fi

  if ! command -v pnpm &> /dev/null; then
    PNPM_INSTALL_SHELL="${SHELL:-$(command -v zsh || command -v bash || echo /bin/sh)}"
    curl -fsSL https://get.pnpm.io/install.sh | env SHELL="$PNPM_INSTALL_SHELL" sh - >/dev/null 2>&1
    echo "  pnpm... ok"
  fi

  echo "  Claude Code 配置..."
  _ensure_json_key "$HOME/.claude.json" "hasCompletedOnboarding" "true"
  _ensure_json_key "$HOME/.claude/config.json" "primaryApiKey" '"any"'
  echo "  Claude Code 配置... ok"
}

# ==============================================================================
# 模块: shell — chezmoi dotfiles 部署
# ==============================================================================
_install_shell() {
  $INSTALL_SHELL || return 0
  echo ""
  echo "── Shell"

  if ! command -v chezmoi &>/dev/null; then
    sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$HOME/.local/bin" >/dev/null 2>&1
    export PATH="$HOME/.local/bin:$PATH"
    echo "  chezmoi... ok"
  fi

  if ! command -v chezmoi &>/dev/null; then
    echo "  chezmoi... FAILED"
    return 1
  fi

  echo "  dotfiles 部署..."
  chezmoi init --apply --source "$REPO_DIR" >/dev/null 2>&1
  echo "  dotfiles 部署... ok"

  ZSHRC="$HOME/.zshrc"

  # shellcheck disable=SC2016
  if [[ ! -f "$ZSHRC" ]]; then
    echo "  ~/.zshrc..."
    cat > "$ZSHRC" <<'EOF'
# GUI environment loaders may start an interactive shell without a usable TTY.
if [[ "${TERM:-}" == "dumb" ]] || [[ ! -t 0 && ! -t 1 ]]; then
  return 0
fi

typeset -U path PATH fpath FPATH
export ZSH_CONFIG_DIR="$HOME/.config/zsh"

source "$ZSH_CONFIG_DIR/core.zsh"

[[ -r "$ZSH_CONFIG_DIR/private/env.zsh" ]] && source "$ZSH_CONFIG_DIR/private/env.zsh"
EOF
    echo "  ~/.zshrc... ok"
  elif ! grep -qF 'source "$HOME/.config/zsh/core.zsh"' "$ZSHRC" && \
       ! grep -qF 'source "$ZSH_CONFIG_DIR/core.zsh"' "$ZSHRC"; then
    echo "  ~/.zshrc (追加)..."
    cat >> "$ZSHRC" <<'EOF'

# dotfiles core config
typeset -U path PATH fpath FPATH
export ZSH_CONFIG_DIR="$HOME/.config/zsh"
source "$ZSH_CONFIG_DIR/core.zsh"
[[ -r "$ZSH_CONFIG_DIR/private/env.zsh" ]] && source "$ZSH_CONFIG_DIR/private/env.zsh"
EOF
    echo "  ~/.zshrc (追加)... ok"
  fi

  GITCONFIG="$HOME/.gitconfig"

  if [[ ! -f "$GITCONFIG" ]]; then
    echo "  ~/.gitconfig..."
    cat > "$GITCONFIG" <<'EOF'
[include]
	path = ~/.config/git/config-shared

[user]
	name = YOUR_NAME
	email = YOUR_EMAIL
EOF
    echo "  ~/.gitconfig... ok"
  elif ! grep -qF '[include]' "$GITCONFIG" || ! grep -qF 'path = ~/.config/git/config-shared' "$GITCONFIG"; then
    echo "  ~/.gitconfig... skip (已存在但无 shared include, 请手动添加)"
  fi
}

# ==============================================================================
# 模块: agents — AI 配置
# ==============================================================================
_install_agents() {
  $INSTALL_AGENTS || return 0
  echo ""
  echo "── AI 配置"

  if [[ -L "$HOME/.agents" ]] || [[ ! -e "$HOME/.agents" ]]; then
    ln -sfn "$REPO_DIR/.agents" "$HOME/.agents"
    echo "  ~/.agents symlink... ok"
  else
    echo "  ~/.agents symlink... skip (已存在且非 symlink)"
  fi

  if command -v bunx &>/dev/null; then
    echo "  dotagents: 9 个 AI Agent symlink..."
    if bunx @oipsanthony/dotagents@latest --scope global --clients all --yes --force >/dev/null 2>&1; then
      echo "  dotagents: 9 个 AI Agent symlink... ok"
    else
      echo "  dotagents: 9 个 AI Agent symlink... FAILED"
    fi
  else
    echo "  dotagents: 9 个 AI Agent symlink... skip (bunx not available)"
  fi
}

# ==============================================================================
# 执行
# ==============================================================================

# Remove integrations owned by tools being retired before mise hides the old binary.
_migrate_rtk
_install_tools
# Agents must run before shell: _install_agents creates the ~/.agents → repo
# symlink that dotagents uses as its source, and _install_shell's chezmoi apply
# triggers run_after_30-link-agents (which calls dotagents). If chezmoi apply
# runs first, dotagents finds no ~/.agents and creates an empty real directory,
# breaking both the top-level symlink and every client link.
_install_agents
_install_shell

echo ""
echo "✨ 安装完成！"
echo ""
echo "📝 后续步骤："
echo "1. 修改 ~/.gitconfig 中的用户名和邮箱"
if [[ "$CURRENT_OS" == "Linux" ]]; then
  echo "2. 通过 mise 管理工具版本: mise ls / mise use node@22"
fi
echo ""

# 自动激活新环境（CI 环境下跳过）
if [[ "${CI:-}" == "true" ]] || [[ "${DOTFILES_NO_EXEC:-}" == "1" ]]; then
  echo "ℹ️  CI/non-interactive mode detected, skipping shell exec."
  exit 0
fi

echo "🔄 正在激活新环境..."
echo "   (如需返回原 shell，请运行 'exit')"
echo ""
sleep 1

if [[ -t 0 ]]; then
  exec zsh -l
elif exec 3</dev/tty 2>/dev/null; then
  exec 3<&-
  exec zsh -l < /dev/tty
else
  echo "ℹ️  当前环境没有可用终端，跳过自动激活。"
  echo "   请手动运行: zsh -l"
fi
