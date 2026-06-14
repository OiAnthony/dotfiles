# AGENTS.md

Behavioral guidelines to reduce common LLM coding mistakes. Merge with project-specific instructions as needed.

**Tradeoff:** These guidelines bias toward caution over speed. For trivial tasks, use judgment.

## Core Principles

- Employ first principles reasoning to distill core needs, eliminate pseudo-requirements, identify genuine value, simplify complexity, and prevent over-engineering.
- Based on the YAGNI principle (You Aren't Gonna Need It) and the KISS principle (Keep It Simple, Stupid).
- Hold positions based on evidence. Maintain them until new information appears.
- State uncertainty explicitly. Say "I don't know" when needed.
- Treat all encountered problems as yours. Fix broken states instead of bypassing them.
- Focus on the most impactful point. Do not dump multiple directions at once.

## Learn from Corrections

**When the user corrects you, record it in the project's AGENTS.md or CLAUDE.md.**

- If the user says "no", "don't", "stop doing X", or otherwise corrects your approach, and the mistake is likely to recur in the project, add a rule to the project's `AGENTS.md` or `CLAUDE.md`.
- Only record when the lesson is project-relevant and reusable — not one-off misunderstandings.
- Keep rules concise: what to avoid and what to do instead.

## 1. Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:

- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, describe each path and its trade-off. Stop and ask one direct question when a decision depends on user constraints.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.
- When explaining changes, describe current state → then new state.
- When explaining systems, follow execution from outer boundary to inner execution.

## 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.
- Avoid inventing extra entities/components/abstractions without necessity.
- Use modern best practices by default.
- Add backward compatibility / legacy workarounds only when requested.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

## 2.5. Communication Style

**Be concise. Be direct. No filler.**

- Write in continuous, flowing prose by default. Use bullet lists only for multi-step tasks, plans, or when explicitly requested.
- Use brief, concrete sentences. State exactly what things are and what to do.
- Use affirmative, direct statements. Avoid jargon, metaphors, and filler.
- More than 1–2 paragraphs is almost always too much. Let answer length grow with the user's request and the real complexity of the problem — give longer responses only when the user asks for depth or the context clearly requires it.
- Do not turn simple agreement or straightforward questions into long recaps.
- Use imperative language. Give direct instructions. End without justification or summary.
- When style and completeness conflict, prefer directness and brevity.
- Do not shift stance due to agreement or disagreement. Change only when new information appears.

## 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:

- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it - don't delete it.
- Don't ignore lint errors, unless you are explicitly asked to do so.

When your changes create orphans:

- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: Every changed line should trace directly to the user's request.

## 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:

- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:

```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.

## Language

- Use Chinese for conversations, include the code review result and plan file content of plan mode.
- Use English for all code-related content (code comments, UI strings, commit messages, PR descriptions) to ensure better internationalization and collaboration in open-source projects.
- OpenSpec Propose artifacts (design docs, specs, task lists) must be written in Simplified Chinese.

## Documentation Standards

- Include: assumptions, setup, usage, verification steps when relevant.
- When writing or editing a document file: Include Mermaid diagrams if they help clarify complex workflows or system architecture.
- Avoid using double quotes and parentheses inside square brackets in Mermaid diagrams, as this can cause parsing errors.
- **CRITICAL: Never provide level of effort time estimates (e.g., hours, days, weeks) for tasks. Focus solely on breaking down the work into clear, actionable steps without estimating how long they will take.**

## Development Environment

### Package Management

- When no package manager is specified in the front-end repo, `bun` is preferred.

## Browser Automation

- Use `agent-browser` for browser automation tasks.
- Run `agent-browser --help` for command reference.
- Core workflow:
  1. `agent-browser open <url>`
  2. `agent-browser snapshot -i`
  3. `agent-browser click @e1` or `agent-browser fill @e2 "text"`
  4. Re-run snapshot after page state changes.

## GitHub CLI (gh)

- Use `gh` for GitHub-related operations (issues, PRs, repos, workflows, API requests).

## Git: nowledge-mem Skills 不提交

`.agents/skills/` 目录中，受 [nowledge-mem](https://github.com/nowledge) 管理的 skill 以软链接形式存在（指向 `ai-now/skills-active/`）。真实目录 skill 是本地直接安装的。

- 软链接 skill = nowledge-mem 管理 → **不提交**
- 真实目录 skill = 本地安装 → 按需提交
- `.agents/.skill-lock.json` 和 `.agents/skills/.nowledge-mem` 本身也不应提交
- 提交前用 `find . -type l` 检查软链接，排除它们及其关联的 git 删除记录

## RTK - Rust Token Killer

@./.agents/RTK.md

---

**These guidelines are working if:** fewer unnecessary changes in diffs, fewer rewrites due to overcomplication, and clarifying questions come before implementation rather than after mistakes.

## Project Conventions

### Repo Shape

- `install.sh` is the installer entrypoint. Supports modular modes: default (full), `--tools`, `--shell`, `--agents`. Handles platform split, clones/updates the repo, installs mise + tools, applies chezmoi dotfiles, links AI agent config, and configures Claude Code.
- `mise.toml` is symlinked to `~/.config/mise/config.toml`. Editing it changes the user's global mise config.
- `.agents/` contains AI coding guidelines (`AGENTS.md`), skill modules (`skills/`), MCP server config (`mcp.json`), and RTK config. Symlinked from `~/.agents`.
- `dot_zshrc`, `dot_zshenv`, `dot_zprofile`, `dot_gitconfig`, `dot_config/`, `dot_local/` are chezmoi-managed dotfiles deployed to `~/` via `chezmoi apply`.
- `.chezmoiscripts/` generates tool integration caches (fzf, zoxide, starship, zcompdump) on `chezmoi apply`.
- `scripts/test-install.sh` and `scripts/test-idempotent.sh` are the executable spec for install behavior. If installer behavior changes, update tests in the same change.

### Verified Commands

- `make lint` runs `shellcheck install.sh`.
- `make test`, `make test-idempotent`, and `make test-root` all depend on `make build` and require `docker` or `podman`.
- `make test-all` runs `lint -> test -> test-idempotent -> test-root`.
- For non-interactive verification of `install.sh`, set `CI=true` or `DOTFILES_NO_EXEC=1`.

### Chezmoi Conventions

- Zsh configuration is hand-written and deliberately minimal. Prefer one shared `core.zsh` over splitting by category.
- Do not make the dotfiles runtime depend on app-managed or generated shell configuration (e.g. Oh My Zsh, Kaku integration files).
- chezmoi externals (`.chezmoiexternal.toml`) manage zsh plugins. Other tools should be managed by mise, not chezmoi externals.
- `chezmoi apply` regenerates shell integration scripts and Zsh completion cache. Shell startup reads pre-generated files only.

### Platform Gotchas

- macOS blocks `root` and installs Homebrew itself plus `mise` and fonts. Linux explicitly supports `root` and installs base packages via the system package manager before `mise`.
- In tests, mise-managed tools may not be on bare `PATH`; verify them with `mise which <tool>` like `scripts/test-install.sh` does, not only `command -v`.
- Prefer `aqua:` or `ubi:` entries in `mise.toml`. After editing `mise.toml`, run `mise install`.
- Pinned runtimes in `mise.toml`: Node lts, Go latest, Python 3.14, Java 21, uv latest. Bun and pnpm are installed by `install.sh` via their official scripts, not mise.

### Network Notes

- China mirror detection can be forced with `DOTFILES_CHINA_MIRROR=1` or disabled with `DOTFILES_CHINA_MIRROR=0`. The detected result is cached in `~/.cache/dotfiles-china-mirror`.
- Even in China mode, `mise` still pulls from GitHub releases. Network-related install failures are often resolved by `https_proxy` or `GITHUB_TOKEN`.

### Writing Conventions

- User-facing docs use Simplified Chinese.
- Code comments use Simplified Chinese.
- Git commit messages use English Conventional Commits.
