# 工具链管理

`tools` 模块使用 [mise](https://mise.jdx.dev/) 管理语言运行时和 CLI。[`mise.toml`](../mise.toml) 是 mise 工具清单，安装脚本会将它链接到 `~/.config/mise/config.toml`。

## 工具清单

| 类别 | 工具 |
| --- | --- |
| 语言与包管理 | Node.js LTS、Bun、Go、Python 3.14、Java 21、uv、pnpm |
| Shell 与终端 | Starship、zoxide、yazi、fzf、fd、ripgrep、jq、Neovim |
| Git | GitHub CLI、git-open、git-delta、lazygit |
| AI 开发 | Codex、pi、oh-my-pi、Herdr、agent-browser、agent-desktop |
| 规范与协作 | OpenSpec、Lark CLI |

mise 管理的工具默认安装 `latest` 或指定的主版本。mise 配置设置了 `minimum_release_age = "24h"`，避免刚发布的版本立即进入日常环境。

`git-open` 根据当前仓库的 remote 在默认浏览器中打开对应页面，支持 GitHub、GitLab、Bitbucket 和自建 GitLab。在仓库任意子目录运行：

```bash
git open          # 打开当前分支
git open --commit # 打开当前 commit
git open --print  # 只输出 URL
```

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

### 浏览器与桌面自动化

`agent-browser` 和 `agent-desktop` 的 CLI 由 mise 管理，不再单独执行 `npm install -g`。`agent-desktop` 的 `bun_args = "--trust"` 允许该工具安装时执行 postinstall，链接原生启动器；不改变其他工具的脚本策略。

首次使用浏览器时下载 Chrome，再检查桌面端版本与权限：

```bash
agent-browser install
agent-desktop version
agent-desktop status
```

`agent-desktop status` 应返回 `ok: true`。macOS 的辅助功能权限用于读取和操作界面；录屏权限只在截图时需要。权限由用户在系统设置中授予，不随工具安装自动开启。

两个官方 skill 通过 `npx skills` 管理，位于 `~/.agents/skills/`，来源记录在 `~/.agents/.skill-lock.json`。安装时指定客户端，避免尝试不支持全局安装的客户端：

```bash
npx skills add vercel-labs/agent-browser --skill agent-browser --global --agent codex --agent claude-code --yes
npx skills add vercel-labs/agent-desktop --skill agent-desktop --global --agent codex --agent claude-code --yes
npx skills update agent-browser agent-desktop --global --yes
```

当前 `~/.agents` 链接到本仓库的 `.agents` submodule，因此 skill 文件和锁文件变更属于该子仓库。

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
install.sh                # mise、pnpm 和系统依赖
dot_zshenv / dot_zprofile  # mise shims 的 PATH 和优先级
```
