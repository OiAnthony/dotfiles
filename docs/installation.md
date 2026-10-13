# 安装与模块说明

根目录 README 只保留全量安装和 Agents 模块的快速入口。本文说明安装脚本的完整行为、模块组合方式和已有配置的处理策略。

## 支持范围

- macOS：支持 Apple Silicon 和 Intel，必须使用普通用户；缺少 Homebrew 时会自动安装。
- Linux：支持普通用户和 `root`，可使用 `apt-get`、`dnf`、`yum`、`pacman` 或 `apk` 补齐基础工具。
- 其他操作系统：安装脚本会停止并报告不受支持。

通过管道运行时，如果当前目录不是本仓库，脚本会把仓库克隆到 `~/.dotfiles`。如果该目录已经是目标仓库，脚本会先更新 `main` 分支再继续安装。只有选择 `agents` 模块时，脚本才初始化仓库固定的 `.agents` submodule。

## 安装全部模块

```bash
curl -fsSL https://raw.githubusercontent.com/OiAnthony/dotfiles/main/install.sh | bash
```

无参数时，脚本按以下顺序执行：

1. 清理由旧 RTK 全局安装留下的集成。
2. 安装 `tools` 模块。
3. 安装 `agents` 模块。
4. 安装 `shell` 模块。
5. 在交互式终端中切换到新的 Zsh 登录 Shell。

Agents 必须先于 Shell 安装，因为 `chezmoi apply` 的后置脚本会同步 Agent 客户端链接。

## 组合安装模块

在 `bash -s --` 后传入一个或多个参数：

```bash
# 只安装工具链
curl -fsSL https://raw.githubusercontent.com/OiAnthony/dotfiles/main/install.sh | bash -s -- --tools

# 只安装 Shell
curl -fsSL https://raw.githubusercontent.com/OiAnthony/dotfiles/main/install.sh | bash -s -- --shell

# 只安装 Coding Agent 配置
curl -fsSL https://raw.githubusercontent.com/OiAnthony/dotfiles/main/install.sh | bash -s -- --agents

# 组合安装工具链和 Shell
curl -fsSL https://raw.githubusercontent.com/OiAnthony/dotfiles/main/install.sh | bash -s -- --tools --shell
```

| 参数 | 安装内容 | 关键行为 |
| --- | --- | --- |
| `--tools` | mise、`mise.toml` 中的工具和 pnpm | macOS 还会安装字体；Linux 会补齐基础系统包 |
| `--shell` | chezmoi、Zsh、Git、Starship、Neovim 配置、插件和生成脚本 | 可以独立安装，不初始化 `.agents` submodule |
| `--agents` | 固定版本的 `.agents` submodule、`~/.agents` 软链接和客户端配置 | submodule 获取失败或工作树有本地修改时停止；客户端同步需要 `bunx` |

在仓库目录中也可以直接执行：

```bash
./install.sh --agents
./install.sh --tools --shell
```

## 已有配置如何处理

安装脚本不会静默覆盖主要的手写配置：

- mise：已有全局配置会先备份到 `~/.dotfiles-backup/<timestamp>/config.toml`，再将 `~/.config/mise/config.toml` 链接到仓库的 `mise.toml`。
- Zsh：已有 `~/.zshrc` 时，只在缺少入口的情况下追加 `~/.config/zsh/core.zsh` 加载代码。
- Git：已有 `~/.gitconfig` 但没有共享配置入口时，脚本会提示手工合并，不会覆盖。
- Agents：已有且不是软链接的 `~/.agents` 目录会被保留，软链接步骤会跳过；安装器不会清理 dirty submodule。

安装前仍建议备份重要的机器配置，并阅读 [`install.sh`](../install.sh) 确认当前行为。

## 非交互安装

CI 或自动化环境可以阻止脚本在安装结束后切换 Shell：

```bash
CI=true ./install.sh
DOTFILES_NO_EXEC=1 ./install.sh
```

`DOTFILES_NO_EXEC=1` 只跳过最终的 `exec zsh -l`，不会把安装变成 dry run。

## 安装后的检查

全量安装完成后建议执行：

```bash
exec zsh
mise doctor
benchmark-zsh
```

如果脚本新建了 `~/.gitconfig`，还需要替换其中的 `YOUR_NAME` 和 `YOUR_EMAIL`。工具链和 Shell 的后续维护分别参见[工具链管理](toolchain.md)与[Shell 配置与性能](zsh-optimization.md)。
