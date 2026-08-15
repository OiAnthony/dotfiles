# 工具链管理

`tools` 模块使用 [mise](https://mise.jdx.dev/) 管理语言运行时和大部分 CLI。[`mise.toml`](../mise.toml) 是 mise 工具清单，安装脚本会将它链接到 `~/.config/mise/config.toml`。OpenCode 2 beta 是例外，由安装脚本通过 Bun 全局安装。

## 工具清单

| 类别 | 工具 |
| --- | --- |
| 语言与包管理 | Node.js LTS、Bun、Go、Python 3.14、Java 21、uv、pnpm |
| Shell 与终端 | Starship、zoxide、yazi、fzf、fd、ripgrep、jq、Neovim |
| Git | GitHub CLI、git-delta、lazygit |
| AI 开发 | Claude Code、Codex、OpenCode 2、pi、oh-my-pi、Herdr、agent-browser |
| 规范与协作 | OpenSpec、Lark CLI |

工具默认安装 `latest` 或指定的主版本。mise 配置设置了 `minimum_release_age = "24h"`，避免刚发布的版本立即进入日常环境。

OpenCode 2 仍处于 beta。官方尚不支持 mise，因此安装脚本执行 `bun install -g --trust @opencode-ai/cli@next`，以允许选择平台原生二进制的 postinstall。可执行文件名为 `opencode2`，Shell 快捷命令 `oc` 指向该命令。OpenCode 1 的 `opencode` 安装和实验性环境变量已移除。

## 安装与升级

```bash
mise doctor  # 检查 mise、配置和环境状态
mise install # 安装清单中缺失的工具
mise upgrade # 升级允许更新的工具
```

需要对单个工具临时忽略 24 小时发布等待期时执行：

```bash
mise upgrade <tool> --minimum-release-age 0
```

OpenCode 2 独立升级：

```bash
bun install -g --trust @opencode-ai/cli@next
```

## 添加工具

优先使用 mise 的 `aqua:` 或 `ubi:` backend：

```bash
mise use -g aqua:sharkdp/bat
mise use -g ubi:BurntSushi/ripgrep
```

由于全局 mise 配置链接到仓库的 `mise.toml`，这些命令会直接更新仓库清单。也可以编辑 `mise.toml`，再运行 `mise install`。

## mise 已安装但找不到工具

先检查配置和指定工具的实际路径：

```bash
mise doctor
mise install
mise which node
```

安装脚本会把以下目录加入 `PATH`：

```text
~/.local/bin
~/.local/share/mise/shims
```

如果下载受到 GitHub API 限流影响，可以设置 `GITHUB_TOKEN` 或网络代理后重试。

## 相关文件

```text
mise.toml                 # 工具清单和 mise 设置
install.sh                # mise、pnpm 和系统依赖安装逻辑
dot_zshenv                # mise shims 的基础 PATH
```
