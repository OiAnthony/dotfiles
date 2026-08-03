# Shell 配置与性能

`shell` 模块不依赖 Oh My Zsh。chezmoi 负责部署共享配置和外部插件，`~/.zshrc` 与 `~/.gitconfig` 保留为用户拥有的入口文件。

## 启动路径

```text
~/.zshenv    → 设置 mise、pnpm、Cargo 等基础 PATH
~/.zprofile  → 设置 macOS Homebrew 登录环境
~/.zshrc     → 加载 ~/.config/zsh/core.zsh 和可选的私有环境变量
```

共享配置包括：

- Zsh history、按键和常用 Git / npm / Docker alias；
- Starship 与 zoxide 的预生成初始化脚本；
- fzf 按键功能的延迟加载；
- zsh-autosuggestions 与 fast-syntax-highlighting；
- chezmoi 管理的 completion cache 和外部插件。

## 配置归属

```text
~/.zshrc                          # 用户文件；安装脚本按需追加共享配置入口
~/.gitconfig                      # 用户文件；按需 include Git 共享配置
~/.zshenv                         # chezmoi: dot_zshenv
~/.zprofile                       # chezmoi: dot_zprofile
~/.config/git/config-shared       # chezmoi: dot_config/git/config-shared
~/.config/zsh/core.zsh            # chezmoi: dot_config/zsh/core.zsh
~/.config/starship.toml           # chezmoi: dot_config/starship.toml
~/.config/zsh/plugins/            # chezmoi external 管理
~/.config/zsh/generated/          # chezmoi 后置脚本生成
```

机器专属环境变量和 secret 放在：

```bash
~/.config/zsh/private/env.zsh
```

该文件会由 `~/.zshrc` 自动加载，但不会进入版本控制。建议设置权限：

```bash
chmod 600 ~/.config/zsh/private/env.zsh
```

## 修改和应用共享配置

```bash
chezmoi edit ~/.config/zsh/core.zsh
chezmoi diff --exclude scripts
chezmoi apply
```

`chezmoi apply` 会部署共享文件、更新外部插件，并重新生成 fzf、zoxide、Starship 初始化脚本和 completion cache。

机器专属配置可以直接写入 `~/.zshrc` 或 `~/.config/zsh/private/env.zsh`，不需要纳入 chezmoi。

## 性能设计

Shell 启动时不执行 fzf、zoxide 或 Starship 的初始化子进程：这些脚本由 `.chezmoiscripts/` 在 `chezmoi apply` 时预生成。fzf 的 Shell integration 只在首次使用相关按键时加载。

当前热启动目标：

- P50 不超过 60 ms；
- P95 不超过 100 ms。

运行基准：

```bash
benchmark-zsh
```

超标时，先检查 `~/.zshrc` 是否加入了同步网络请求或重量级初始化命令，再确认生成脚本存在：

```bash
chezmoi apply
benchmark-zsh
```

## chezmoi 配置冲突

先检查差异并手工合并：

```bash
chezmoi diff
chezmoi merge ~/.config/zsh/core.zsh
```

只有确认本地改动可以丢弃时，才使用：

```bash
chezmoi apply --force
```
