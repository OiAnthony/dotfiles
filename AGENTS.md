# AGENTS.md

Repo-specific operational guidance. For general AI coding behavior, see `.agents/AGENTS.md` (deployed to `~/.agents` — applies globally, not just here).

## Two-file structure

- `.agents/AGENTS.md` is deployed to `~/.agents` and applies to all projects on the machine. Do not add dotfiles-specific build/test/shell instructions there.
- This file is the repo-level guide for contributors working in the dotfiles repo itself.

## Commands

```
make lint              # shellcheck only, no Docker needed
make test              # requires Docker/podman + make build
make test-idempotent   # requires Docker/podman + make build
make test-piped        # requires Docker/podman + make build
make test-root         # requires Docker/podman + make build
make test-rtk-migration # RTK upgrade migration
make test-all          # lint → test → test-idempotent → test-piped → test-root → test-rtk-migration
```

Non-interactive local verification: `CI=true ./install.sh` or `DOTFILES_NO_EXEC=1 ./install.sh`.

## Architecture

- `mise.toml` symlinks to `~/.config/mise/config.toml`. Editing it changes the user's global mise config. After editing, run `mise install`.
- `install.sh` migrates retired global tool integrations before `_install_mise` changes the active tool config; keep this ordering when removing a mise-managed tool with external hooks.
- `.agents/` symlinks to `~/.agents`; all files under `.agents/` are intentionally synchronized by that directory symlink, not by chezmoi per-file deployment.
- `.chezmoiignore` lists files excluded from `chezmoi apply` (README, install.sh, mise.toml, Makefile, Dockerfile, scripts/, docs/, .agents/). These are repo-only — not deployed to `~/`.
- `.chezmoiscripts/run_after_*.sh.tmpl` regenerates fzf/zoxide/starship integration files and Zsh completion cache on every `chezmoi apply`. Shell startup reads these pre-generated files only.

## Chezmoi conventions

- Zsh config is hand-written, deliberately minimal. Prefer one `core.zsh` over splitting by category. No Oh My Zsh or framework-managed shell config.
- chezmoi externals (`.chezmoiexternal.toml`) manage zsh plugins only (autosuggestions, fast-syntax-highlighting). All other tools go through mise.
- `chezmoi apply` regenerates shell integration scripts and Zsh completion cache. Shell startup reads pre-generated files only — never calls tool init commands inline.

## Platform

- macOS: blocks `root`, installs Homebrew + mise + fonts.
- Linux: explicitly supports `root`, installs base packages via system package manager before mise.

## Mise

- Bun is mise's npm package manager (`mise.toml` sets `npm.package_manager = "bun"`). pnpm is installed separately by `install.sh`.
- In tests, verify mise tools with `mise which <tool>` — not `command -v` (mise shims may not be on bare PATH in containers).
- Prefer `aqua:` or `ubi:` backends for new tools in `mise.toml`.
- Pinned runtimes: Node lts, Bun latest, Go latest, Python 3.14, Java 21, uv latest.

## Tests are the spec

Container tests may auto-forward `GITHUB_TOKEN` from the environment or `gh auth token`; the target audience is software developers and this keeps repeated tool installs from hitting anonymous GitHub rate limits.

`scripts/test-install.sh` and `scripts/test-idempotent.sh` are the executable spec for install behavior. If installer behavior changes, update tests in the same change.

`scripts/test-shell.sh` enforces Zsh startup P50 ≤ 60ms, P95 ≤ 100ms. Do not add heavyweight inline init calls to shell startup.

## Git

- Commit messages: English Conventional Commits.

## Repository Safety

- **No machine-specific absolute paths.** Do not commit symlinks, configs, or scripts that embed absolute paths tied to a specific machine (e.g. `/Users/anthony/...`, `/home/anthony/...`). This applies to all forms of absolute path references, not only symlinks and real directories. Use portable references such as `$HOME`, `~`, or chezmoi template variables (`{{ .chezmoi.homeDir }}`).
- **No secrets in version control.** Never commit passwords, API keys, tokens, private keys, or other sensitive credentials. Use environment variables, external secret managers, or chezmoi's secret management instead.
