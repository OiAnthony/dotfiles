# dotfiles

<p align="center">
  <strong>一行命令，任何机器复现你的开发环境 + AI 编码配置</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/macOS-支持-success?style=flat-square&logo=apple" alt="macOS" />
  <img src="https://img.shields.io/badge/Linux-支持-success?style=flat-square&logo=linux" alt="Linux" />
  <img src="https://img.shields.io/badge/Apple%20Silicon-支持-success?style=flat-square" alt="Apple Silicon" />
  <img src="https://img.shields.io/badge/root-支持-success?style=flat-square" alt="root" />
</p>

---

在一台全新的 macOS 或 Linux 机器上还原整套开发环境，包括工具链、Shell 配置和 AI 编码规则。跑一次搞定，跑两次也没副作用。

工具链交给 [mise](https://mise.jdx.dev) 管理，Shell 配置由 [chezmoi](https://chezmoi.io) 部署，AI 编码规则和技能模块集成在 `.agents/` 中。Linux 上不依赖 Homebrew，root 也能用。

## 快速开始

```bash
curl -fsSL https://raw.githubusercontent.com/OiAnthony/dotfiles/main/install.sh | bash
```

## 模块安装

| 命令 | 安装内容 | 适用场景 |
|------|---------|---------|
| `./install.sh` | 工具链 + Shell + AI（全量） | 新机器 |
| `./install.sh --tools` | mise 工具链、Bun、pnpm | 有自己的 dotfiles |
| `./install.sh --shell` | chezmoi Shell 配置 | 已有工具，想用这套配置 |
| `./install.sh --agents` | AI 规则 + 技能模块 | 已有环境，需要 AI 配置 |

可组合：`./install.sh --tools --shell`（工具 + Shell，不含 AI）。

## 装了什么

### 工具链（mise 管理）

| 分类 | 工具 |
|------|------|
| Shell 体验 | starship, fzf, zoxide, fd, ripgrep, jq, neovim, yazi |
| Git 工具 | gh, lazygit, git-delta |
| 运行时 | Node.js (LTS), Go, Python 3.14, Java 21, uv |
| AI | Claude Code, agent-browser, RTK |
| 开发框架 | OpenSpec |

### 通过官方脚本安装

| 工具 | 说明 |
|------|------|
| Bun | JavaScript 运行时 & 包管理器 |
| pnpm | Node.js 包管理器 |

### Shell 配置（chezmoi 部署）

手写的 Zsh 配置，不依赖 Oh My Zsh 等框架：

- `~/.zshrc`、`~/.zshenv`、`~/.zprofile` — Shell 入口
- `~/.config/zsh/core.zsh` — 共享 Shell 配置（别名、fzf 懒加载、补全、插件）
- `~/.gitconfig` — Git 配置（delta diff、别名）
- `~/.config/starship.toml` — Prompt 主题
- zsh-autosuggestions + fast-syntax-highlighting（chezmoi external 托管）

### AI 配置（`.agents/`）

- `AGENTS.md` — AI 编码行为指南
- `skills/` — 20+ 技能模块（代码审查、调试、写作、设计、OpenSpec 工作流）
- `mcp.json` — MCP 服务器配置
- `RTK.md` — Rust Token Killer 使用说明

部署后通过 `~/.agents` 软链接生效，AI 工具自动发现。

## 自定义

**加新工具**：编辑 `mise.toml`，优先用 `aqua:` 或 `ubi:` backend：

```toml
"aqua:sharkdp/bat" = "latest"
```

然后运行 `mise install`。

**改 Shell 配置**：

- **用户自定义**：直接编辑 `~/.zshrc`，添加自己的配置、环境变量或第三方工具初始化代码。这个文件不受 chezmoi 管理，不会被覆盖。
- **修改核心配置**：用 chezmoi 工作流编辑 `~/.config/zsh/core.zsh`：

```bash
chezmoi edit ~/.config/zsh/core.zsh
chezmoi diff --exclude scripts
chezmoi apply
```

**加新 skill**：

```bash
bunx skills add <owner/repo>
```

更多可用 skills：[skills.sh](https://skills.sh/)。

## 日常使用

```bash
chezmoi diff --exclude scripts
chezmoi apply
chezmoi cd    # 进入仓库目录
```

`chezmoi apply` 会重新生成 Shell 集成脚本和 Zsh 补全缓存。

## 性能

Shell 启动路径中没有 Oh My Zsh 框架。fzf 在首次使用时才加载。目标：

- 热启动 P50 不超过 60 ms
- 热启动 P95 不超过 100 ms

在真实终端中运行 `benchmark-zsh` 检查。

## 密钥

不要把密钥放进仓库。把机器本地的导出项放在 `~/.config/zsh/private/env.zsh`（权限 `600`）。

## 测试

```bash
make lint            # shellcheck
make test            # 集成测试
make test-idempotent # 幂等性测试
make test-root       # root 路径
make test-all        # 全部
```

## 目录结构

```
dotfiles/
├── install.sh                   # 安装入口（支持 --tools/--shell/--agents）
├── mise.toml                    # 工具清单
├── .agents/                     # AI 配置（skills、MCP、RTK）
│   ├── skills/
│   ├── mcp.json
│   └── RTK.md
├── .chezmoi.toml.tmpl           # chezmoi 配置
├── .chezmoiexternal.toml        # chezmoi 外部依赖
├── .chezmoiscripts/             # 生成脚本（Shell 集成 + Zsh 补全缓存）
├── dot_zshrc / dot_zshenv / dot_zprofile  # Zsh 入口
├── dot_gitconfig                # Git 配置
├── dot_config/                  # ~/.config/ 映射
│   ├── starship.toml
│   └── zsh/
│       ├── core.zsh
│       └── completions/
├── dot_local/                   # ~/.local/ 映射
├── Makefile / Dockerfile        # 测试基础设施
├── scripts/                     # 测试脚本
└── docs/                        # 文档
```

## 致谢

- [mise](https://github.com/jdx/mise) — 工具链管理
- [chezmoi](https://github.com/twpayne/chezmoi) — dotfiles 管理
- [starship](https://github.com/starship/starship) — Shell prompt
- [Waza](https://github.com/tw93/Waza) — AI skill 系列

## License

MIT
