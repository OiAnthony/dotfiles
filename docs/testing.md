# 测试架构说明

仓库使用 ShellCheck 和 Ubuntu 24.04 Docker 容器验证 `install.sh`。

## 测试入口

```bash
make lint               # ShellCheck 静态检查
make test               # 普通用户完整安装
make test-shell         # Zsh 与 mise 集成
make test-idempotent    # 重复安装
make test-piped         # curl 管道安装路径
make test-root          # Linux root 安装
make test-rtk-migration # 旧 RTK 集成迁移
make test-agents-submodule # fresh clone 初始化和 dirty submodule 拒绝
make test-all           # 聚合检查，不包含 test-shell
```

`make lint` 检查以下 Shell 文件：

```text
install.sh
scripts/*.sh
dot_local/bin/executable_benchmark-zsh
```

`make test-all` 当前包含 `lint`、`test-agents-submodule`、`test`、`test-idempotent`、`test-piped`、`test-root` 和 `test-rtk-migration`。需要验证完整交互式 Zsh 初始化时，应另外运行 `make test-shell`。

## 容器测试覆盖什么

Dockerfile 基于 Ubuntu 24.04，并创建普通用户 `testuser`。不同入口覆盖：

- mise 工具和 runtime 安装；
- chezmoi 部署的 Zsh、Git 与 Starship 配置；
- `~/.config/mise/config.toml` 和 `~/.agents` 软链接；
- 打包工作树中的 Agent 配置和 shell-only 同步保护；
- Bun、pnpm、mise shims 与 Zsh `PATH`；
- fzf 延迟加载和 Shell completion；
- 普通用户、Linux `root`、重复安装和管道安装路径；
- 旧 RTK 全局集成的清理。

容器无法验证 macOS 的 Homebrew 和字体路径。真实机器的 Shell 启动性能仍需使用 `benchmark-zsh` 验收。

## GitHub API 限流

Makefile 会优先使用环境中的 `GITHUB_TOKEN`；未设置时尝试读取 `gh auth token`。token 只作为容器环境变量传入，用于降低连续下载 GitHub release 时触发匿名 API 限流的概率。

## 本地调试

先构建镜像：

```bash
make build
```

进入普通用户容器：

```bash
docker run --rm -it dotfiles-test bash
```

仓库位于 `/opt/dotfiles`，可以直接运行单个测试脚本：

```bash
/opt/dotfiles/scripts/test-install.sh
/opt/dotfiles/scripts/test-shell.sh
```

## 维护测试

修改安装行为时，应同步更新对应测试：

| 改动 | 主要验证入口 |
| --- | --- |
| 工具清单或 mise 安装 | `scripts/test-install.sh` |
| Zsh、PATH、completion | `scripts/test-shell.sh` |
| 重复执行行为 | `scripts/test-idempotent.sh` |
| 管道安装和仓库克隆 | `scripts/test-piped-install.sh` |
| RTK 清理逻辑 | `scripts/test-rtk-migration.sh` |
| `.agents` submodule 初始化与 dirty 状态 | `scripts/test-agents-submodule.sh` |

修改 Dockerfile 会使镜像构建缓存失效。下载失败时先设置 `GITHUB_TOKEN` 或网络代理，再单独运行失败的测试入口查看完整日志。
