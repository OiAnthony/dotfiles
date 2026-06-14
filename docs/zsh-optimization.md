# Shell 配置说明

## 设计理念

本配置不依赖 Oh My Zsh 等框架，使用 chezmoi 声明式管理所有 shell 配置。

- Zsh 配置手写，保持精简：`~/.zshrc`（入口）→ `~/.config/zsh/core.zsh`（共享配置）
- 插件由 chezmoi external（`.chezmoiexternal.toml`）托管，跟随上游 latest
- fzf 懒加载：首次按 `^T` / `^R` 时才加载 fzf shell integration
- Starship / zoxide 集成缓存由 `.chezmoiscripts/` 在 `chezmoi apply` 时预生成

## 启动路径

```
~/.zshenv    → PATH 设置（mise shims、bun、pnpm 等）
~/.zprofile  → Homebrew 环境 + 中国镜像检测
~/.zshrc     → source ~/.config/zsh/core.zsh
```

## 性能

启动时不执行任何子进程生成（fzf / zoxide / starship 均为预生成缓存）。目标：

- 热启动 P50 不超过 60 ms
- 热启动 P95 不超过 100 ms

```bash
benchmark-zsh
```

## 配置位置

```
~/.zshrc                          → chezmoi: dot_zshrc
~/.zshenv                         → chezmoi: dot_zshenv
~/.zprofile                       → chezmoi: dot_zprofile
~/.gitconfig                      → chezmoi: dot_gitconfig
~/.config/zsh/core.zsh            → chezmoi: dot_config/zsh/core.zsh
~/.config/starship.toml           → chezmoi: dot_config/starship.toml
~/.config/zsh/plugins/            → chezmoi external 管理
~/.config/zsh/generated/          → chezmoi 脚本生成
```

## 自定义

```bash
chezmoi edit ~/.zshrc    # 编辑源文件
chezmoi diff             # 预览变更
chezmoi apply            # 应用到 home 目录
```
