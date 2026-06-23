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
    echo "✅ 已有 sudo 权限"
    return 0
  fi
  if [[ -t 0 ]]; then
    echo "🔐 需要 sudo 权限以安装依赖并配置默认 Shell..."
    sudo -v
    return 0
  fi
  echo "⚠️  检测到非交互式环境，尝试通过终端获取 sudo 权限..."
  if exec 3</dev/tty 2>/dev/null; then
    # shellcheck disable=SC2024
    sudo -v < /dev/tty
    exec 3<&-
    return 0
  fi
  echo "❌ 无法获取 sudo 权限（无终端且无免密 sudo）"
  echo "请先运行: sudo -v && curl -fsSL https://raw.githubusercontent.com/OiAnthony/dotfiles/main/install.sh | bash"
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
data['$key'] = $value
with open('$file', 'w') as f:
    json.dump(data, f, indent=2)
"
}

_install_mise() {
  if ! command -v mise &>/dev/null; then
    echo "📦 安装 mise..."
    curl -fsSL https://mise.run | sh
  else
    echo "✅ mise 已安装"
  fi

  export PATH="$HOME/.local/bin:$HOME/.local/share/mise/shims:$PATH"

  if ! command -v mise &>/dev/null; then
    echo "❌ mise 安装失败或不在 PATH ($HOME/.local/bin) 中，无法继续。"
    exit 1
  fi

  echo "🔄 更新 mise 到最新版本..."
  mise self-update || echo "⚠️  mise self-update 失败，继续使用当前版本"

  echo "📦 通过 mise 安装 Bun..."
  (cd "$HOME" && mise use -g bun@latest) || {
    echo "❌ Bun 安装失败，无法继续安装 mise npm 工具。"
    exit 1
  }

  mkdir -p "$HOME/.config/mise"
  ln -sf "$REPO_DIR/mise.toml" "$HOME/.config/mise/config.toml"

  echo "📦 通过 mise 安装工具链（首次需下载，可能耗时较久）..."
  mise install || {
    echo "⚠️  mise install 部分失败，常见原因：网络受限、GitHub release 限流。"
    echo "   可设置 https_proxy 或 GITHUB_TOKEN 后重新运行。"
  }
}

_install_fonts_macos() {
  local font_dir="$HOME/Library/Fonts"
  mkdir -p "$font_dir"

  if ! ls "$font_dir"/MapleMono-NF-CN-*.ttf >/dev/null 2>&1; then
    echo "📦 下载 Maple Mono NF CN..."
    local tmp; tmp=$(mktemp -d)
    if curl -fsSL -o "$tmp/maple.zip" \
        "https://github.com/subframe7536/maple-font/releases/latest/download/MapleMono-NF-CN.zip"; then
      unzip -q -o "$tmp/maple.zip" -d "$font_dir"
      echo "✅ Maple Mono NF CN 已安装"
    else
      echo "⚠️  Maple Mono 下载失败，跳过"
    fi
    rm -rf "$tmp"
  else
    echo "✅ Maple Mono NF CN 已存在"
  fi

  if ! ls "$font_dir"/JetBrainsMonoNerdFont-*.ttf >/dev/null 2>&1; then
    echo "📦 下载 JetBrains Mono Nerd Font..."
    local tmp; tmp=$(mktemp -d)
    if curl -fsSL -o "$tmp/jb.zip" \
        "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip"; then
      unzip -q -o "$tmp/jb.zip" -d "$font_dir"
      echo "✅ JetBrains Mono Nerd Font 已安装"
    else
      echo "⚠️  JetBrains Mono 下载失败，跳过"
    fi
    rm -rf "$tmp"
  else
    echo "✅ JetBrains Mono Nerd Font 已存在"
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
    echo "✅ Linux 基础工具已安装"
    return 0
  fi

  if command -v apt-get &>/dev/null; then
    echo "📦 使用 apt-get 安装基础工具..."
    $sudo_cmd apt-get update -y
    $sudo_cmd apt-get install -y "${pkgs[@]}"
  elif command -v dnf &>/dev/null; then
    echo "📦 使用 dnf 安装基础工具..."
    $sudo_cmd dnf install -y git curl wget vim zsh zip unzip tree htop jq ca-certificates
    $sudo_cmd dnf groupinstall -y "Development Tools" || true
  elif command -v yum &>/dev/null; then
    echo "📦 使用 yum 安装基础工具..."
    $sudo_cmd yum install -y git curl wget vim zsh zip unzip tree htop jq ca-certificates
    $sudo_cmd yum groupinstall -y "Development Tools" || true
  elif command -v pacman &>/dev/null; then
    echo "📦 使用 pacman 安装基础工具..."
    $sudo_cmd pacman -Sy --noconfirm git curl wget vim zsh zip unzip tree htop jq base-devel ca-certificates
  elif command -v apk &>/dev/null; then
    echo "📦 使用 apk 安装基础工具..."
    $sudo_cmd apk add --no-cache git curl wget vim zsh zip unzip tree htop jq build-base ca-certificates
  else
    echo "❌ 未识别的 Linux 发行版包管理器。"
    echo "   请手动安装: ${pkgs[*]}，然后重新运行此脚本。"
    return 1
  fi
}

_configure_default_shell() {
  local current_shell
  current_shell="$(basename "$SHELL")"
  if [[ "$current_shell" == "zsh" ]]; then
    echo "✅ Zsh 已是默认 Shell"
    return 0
  fi

  local zsh_path
  zsh_path="$(command -v zsh)"
  if [[ -z "$zsh_path" ]]; then
    echo "⚠️  未找到 zsh，跳过默认 shell 切换"
    return 0
  fi

  local sudo_cmd=""
  [[ "$EUID" -ne 0 ]] && sudo_cmd="sudo"

  if [[ -n "$sudo_cmd" ]]; then
    _ensure_sudo
  fi

  if [[ -f /etc/shells ]] && ! grep -qxF "$zsh_path" /etc/shells; then
    echo "📝 将 $zsh_path 添加到 /etc/shells..."
    echo "$zsh_path" | $sudo_cmd tee -a /etc/shells >/dev/null
  fi

  if [[ -n "$sudo_cmd" ]] && $sudo_cmd chsh -s "$zsh_path" "$(id -un)" 2>/dev/null; then
    echo "✅ 默认 Shell 已切换为 $zsh_path（下次登录生效）"
  elif chsh -s "$zsh_path" 2>/dev/null; then
    echo "✅ 默认 Shell 已切换为 $zsh_path（下次登录生效）"
  elif command -v usermod &>/dev/null; then
    $sudo_cmd usermod -s "$zsh_path" "$(id -un)" && \
      echo "✅ 默认 Shell 已切换为 $zsh_path（通过 usermod，下次登录生效）"
  else
    echo "⚠️  无法切换默认 Shell，请手动执行: chsh -s $zsh_path"
  fi
}

# ==============================================================================
# 模块: tools — 工具链安装
# ==============================================================================
_install_tools() {
  $INSTALL_TOOLS || return 0
  echo ""
  echo "━━━ 工具链安装 ━━━"

  if [[ "$CURRENT_OS" == "Darwin" ]]; then
    _configure_default_shell

    if ! command -v brew &> /dev/null; then
      echo "📦 安装 Homebrew（仅本体，工具链由 mise 管理）..."
      _ensure_sudo
      NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
      if [[ -f "/opt/homebrew/bin/brew" ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
      fi
    else
      echo "✅ Homebrew 已安装"
    fi

    _install_mise
    _install_fonts_macos

  elif [[ "$CURRENT_OS" == "Linux" ]]; then
    _install_base_linux
    _configure_default_shell

    _install_mise

  else
    echo "❌ 不支持的操作系统: $CURRENT_OS"
    exit 1
  fi

  if [[ "$CURRENT_OS" == "Darwin" ]]; then
    export PNPM_HOME="$HOME/Library/pnpm"
    export PATH="$PNPM_HOME:$PATH"
  else
    export PNPM_HOME="$HOME/.local/share/pnpm"
    export PATH="$PNPM_HOME/bin:$PATH"
  fi

  # pnpm（双平台）
  if ! command -v pnpm &> /dev/null; then
    echo "📦 安装 pnpm..."
    PNPM_INSTALL_SHELL="${SHELL:-$(command -v zsh || command -v bash || echo /bin/sh)}"
    curl -fsSL https://get.pnpm.io/install.sh | env SHELL="$PNPM_INSTALL_SHELL" sh -
  else
    echo "✅ pnpm 已安装"
  fi

  # Claude Code 配置
  echo "🔧 配置 Claude Code..."
  _ensure_json_key "$HOME/.claude.json" "hasCompletedOnboarding" "true" && \
    echo "✅ ~/.claude.json 已就绪"
  _ensure_json_key "$HOME/.claude/config.json" "primaryApiKey" '"any"' && \
    echo "✅ ~/.claude/config.json 已就绪"
}

# ==============================================================================
# 模块: shell — chezmoi dotfiles 部署
# ==============================================================================
_install_shell() {
  $INSTALL_SHELL || return 0
  echo ""
  echo "━━━ Shell 配置 ━━━"

  # 安装 chezmoi
  if ! command -v chezmoi &>/dev/null; then
    echo "📦 安装 chezmoi..."
    sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$HOME/.local/bin"
    export PATH="$HOME/.local/bin:$PATH"
  else
    echo "✅ chezmoi 已安装"
  fi

  if ! command -v chezmoi &>/dev/null; then
    echo "❌ chezmoi 安装失败，跳过 Shell 配置。"
    return 1
  fi

  # 部署 dotfiles
  echo "🔗 部署 dotfiles..."
  chezmoi init --apply --source "$REPO_DIR"
  echo "✅ dotfiles 已部署"

  # Bootstrap ~/.zshrc（允许用户和第三方软件修改）
  ZSHRC="$HOME/.zshrc"
  
  # shellcheck disable=SC2016
  if [[ ! -f "$ZSHRC" ]]; then
    echo "📝 创建 ~/.zshrc bootstrap..."
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
  elif ! grep -qF 'source "$HOME/.config/zsh/core.zsh"' "$ZSHRC" && \
       ! grep -qF 'source "$ZSH_CONFIG_DIR/core.zsh"' "$ZSHRC"; then
    echo "📝 追加 core.zsh source 到 ~/.zshrc..."
    cat >> "$ZSHRC" <<'EOF'

# dotfiles core config
typeset -U path PATH fpath FPATH
export ZSH_CONFIG_DIR="$HOME/.config/zsh"
source "$ZSH_CONFIG_DIR/core.zsh"
[[ -r "$ZSH_CONFIG_DIR/private/env.zsh" ]] && source "$ZSH_CONFIG_DIR/private/env.zsh"
EOF
  else
    echo "✅ ~/.zshrc 已包含 core.zsh source"
  fi

  # Bootstrap ~/.gitconfig（允许用户修改）
  GITCONFIG="$HOME/.gitconfig"
  
  if [[ ! -f "$GITCONFIG" ]]; then
    echo "📝 创建 ~/.gitconfig bootstrap..."
    cat > "$GITCONFIG" <<'EOF'
[include]
	path = ~/.config/git/config-shared

[user]
	name = YOUR_NAME
	email = YOUR_EMAIL
EOF
  elif ! grep -qF '[include]' "$GITCONFIG" || ! grep -qF 'path = ~/.config/git/config-shared' "$GITCONFIG"; then
    echo "⚠️  ~/.gitconfig 已存在但未包含 shared config include"
    echo "   请手动添加到文件头部："
    echo "   [include]"
    echo "       path = ~/.config/git/config-shared"
  else
    echo "✅ ~/.gitconfig 已包含 shared config include"
  fi
}

# ==============================================================================
# 模块: agents — AI 配置
# ==============================================================================
_install_agents() {
  $INSTALL_AGENTS || return 0
  echo ""
  echo "━━━ AI 配置 ━━━"

  # symlink ~/.agents → repo/.agents
  if [[ -L "$HOME/.agents" ]] || [[ ! -e "$HOME/.agents" ]]; then
    ln -sfn "$REPO_DIR/.agents" "$HOME/.agents"
    echo "✅ ~/.agents → $REPO_DIR/.agents"
  else
    echo "⚠️  ~/.agents 已存在且不是软链接，跳过。"
  fi

  # RTK global hook
  if command -v rtk &>/dev/null; then
    rtk init --global --hook-only --auto-patch && echo "✅ RTK global hook 已初始化" || true
  else
    echo "⚠️  rtk 未安装（可用 --tools 安装），跳过 RTK hook。"
    echo "   安装后请运行: rtk init --global --hook-only --auto-patch"
  fi

  # Delegate per-client symlink topology to @oipsanthony/dotagents.
  # Requires bunx (provided by mise's bun); missing bunx degrades gracefully.
  if command -v bunx &>/dev/null; then
    echo "🔗 委托 dotagents 建立 9 个客户端 symlink..."
    if bunx @oipsanthony/dotagents@latest --scope global --clients all --yes --force; then
      echo "✅ dotagents 客户端 symlink 已就绪"
    else
      echo "⚠️  dotagents 执行失败，客户端 symlink 保持未托管状态。"
      echo "   可稍后手动运行: bunx @oipsanthony/dotagents"
    fi
  else
    echo "⚠️  bunx 不可用（需 mise 安装 bun），跳过 dotagents 客户端 symlink。"
    echo "   安装后请运行: bunx @oipsanthony/dotagents --scope global --clients all --yes --force"
  fi
}

# ==============================================================================
# 执行
# ==============================================================================

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
