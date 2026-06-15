# 测试架构说明

## 概述

dotfiles 使用 Docker 容器提供隔离的测试环境，验证 `install.sh` 在干净系统上的安装结果。

## 测试类型

### 1. 静态检查（ShellCheck）

**目的**：在运行前捕获 Shell 脚本语法错误和常见问题

**覆盖文件**：

- `install.sh`

**运行方式**：

```bash
make lint
```

### 2. 集成测试

**目的**：验证完整安装流程

**测试内容**：

- mise 工具链安装（starship, fzf, fd, rg, gh, lazygit, delta, nvim, node, go, python, java, uv, jq）
- chezmoi 部署的 dotfiles（.zshrc, .zshenv, .zprofile, .gitconfig, core.zsh, starship.toml）
- 软链接验证（mise/config.toml, .agents）
- mise 管理的 Bun、Bun 驱动的 npm backend、pnpm 与 Zsh PATH
- 完整交互式 Zsh 初始化、fzf 懒加载和 mise runtime 执行
- 20 次热启动性能门禁：P95 不超过 100 ms
- macOS 额外验证：字体安装、Homebrew

**运行方式**：

```bash
make test
```

### 3. 幂等性测试

**目的**：验证重复运行安全性

**测试内容**：

- 运行 install.sh 两次
- 验证软链接未改变（md5sum）
- 验证 .zshrc 中 source 行只出现一次（未重复追加）

**运行方式**：

```bash
make test-idempotent
```

## Docker 架构

### 基础镜像

**FROM**: ubuntu:24.04

**预装组件**：

- 系统依赖：build-essential, curl, git, zsh, sudo
- 非 root 用户 testuser（用于 testuser 路径，root 路径通过 `-u 0` 覆盖）

### 缓存优化

**分层策略**：

1. 系统依赖安装（很少变化）
2. 项目文件复制（频繁变化）

**效果**：

- 冷缓存：~10 分钟
- 热缓存：~4 分钟（仅重新复制项目文件）

## 本地测试命令

通过 Makefile 在本地运行测试：

```bash
make lint            # ShellCheck 静态检查
make test            # 集成测试（testuser）
make test-idempotent # 幂等性测试
make test-root       # root 用户测试
make test-piped      # 管道安装测试
make test-all        # 全部测试
```

测试会优先使用当前 `GITHUB_TOKEN`；未设置时尝试读取 `gh auth token`，避免连续安装触发 GitHub 匿名 API 限流。token 仅作为容器环境变量传递，不会出现在命令行中。

## 不覆盖的范围

### macOS 特定路径

Docker 无法运行 macOS，以下路径不会被测试：

- Apple Silicon Homebrew 路径：`/opt/homebrew`
- Intel Mac Homebrew 路径：`/usr/local`

**缓解措施**：开发者在本地 macOS 环境手动测试

### Shell 启动性能

容器测试使用伪终端运行完整交互式初始化，避免命中 GUI/no-TTY 快速返回分支。容器结果用于防止明显回退，真实机器仍使用 `benchmark-zsh` 验收。

## 本地调试

### 进入容器

```bash
# 构建镜像
make build

# 进入容器
docker run -it dotfiles-test bash

# 手动运行安装
./install.sh

# 检查结果
command -v git
ls -la ~/.gitconfig
cat ~/.zshrc
```

### 查看测试日志

测试脚本使用颜色输出：

- 🟢 绿色：成功
- 🔴 红色：失败
- 🟡 黄色：警告（可选工具未安装）

## 维护指南

### 添加新工具验证

编辑 `scripts/test-install.sh`，在 "验证 mise 工具" 部分添加新工具：

```bash
for tool in starship fzf zoxide fd rg gh lazygit delta nvim node go python uv jq NEW_TOOL; do
    check_via_mise "$tool" || ((failed++))
done
```

### 修改安装检测逻辑

同时更新：

1. `install.sh` - 安装时检测
2. `scripts/test-install.sh` - 测试验证

### 更新 Docker 缓存

修改 `Dockerfile` 后会自动失效构建缓存，首次构建会较慢。

## 故障排查

### 测试失败：mise 工具未装

**原因**：GitHub release 拉取受限或网络问题

**解决**：

- 设置 `https_proxy` 或 `GITHUB_TOKEN`
- 检查 `mise.toml` 中的后端是否可用：`mise registry | grep <tool>`
- 单独运行 `mise install` 查看详细错误

### 测试失败：软链接验证

**原因**：路径不匹配

**解决**：

- 检查 `install.sh` 中的软链接创建逻辑
- 验证 `PROJECT_ROOT` 变量正确

### CI 超时

**原因**：首次安装下载量大

**解决**：

- 设置 `GITHUB_TOKEN` 提高 GitHub release 限流
- 在 mise.toml 中 pin 具体版本，提高缓存命中

## 参考

- [ShellCheck Wiki](https://www.shellcheck.net/wiki/)
- [Docker Best Practices](https://docs.docker.com/develop/dev-best-practices/)
- [GitHub Actions Caching](https://docs.github.com/en/actions/using-workflows/caching-dependencies-to-speed-up-workflows)
