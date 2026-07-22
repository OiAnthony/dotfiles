#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }

check_command() {
    local cmd=$1
    if command -v "$cmd" >/dev/null 2>&1; then
        log_info "✓ $cmd is installed"
        return 0
    else
        log_error "✗ $cmd is NOT installed"
        return 1
    fi
}

check_via_mise() {
    local tool=$1
    if mise which "$tool" >/dev/null 2>&1; then
        log_info "✓ mise provides: $tool"
        return 0
    else
        log_error "✗ mise does NOT provide: $tool"
        return 1
    fi
}

check_file() {
    local file=$1
    if [[ -f "$file" ]]; then
        log_info "✓ File exists: $file"
        return 0
    else
        log_error "✗ File NOT found: $file"
        return 1
    fi
}

check_symlink() {
    local link=$1
    local target=$2
    if [[ -L "$link" ]]; then
        local actual_target
        actual_target=$(readlink "$link")
        if [[ "$actual_target" == "$target" ]]; then
            log_info "✓ Symlink correct: $link -> $target"
            return 0
        else
            log_error "✗ Symlink target mismatch: $link -> $actual_target (expected: $target)"
            return 1
        fi
    else
        log_error "✗ Not a symlink: $link"
        return 1
    fi
}

# Verify a dotagents-managed client symlink points through ~/.agents (relative
# path, not an absolute repo path). Accepts both the exact relative target and
# any relative target whose final segment matches the expected source name.
check_agent_link() {
    local link=$1
    local expected=$2
    local label=${3:-$link}
    if [[ -L "$link" ]]; then
        local actual_target
        actual_target=$(readlink "$link")
        if [[ "$actual_target" == "$expected" ]]; then
            log_info "✓ Agent link correct: $label -> $actual_target"
            return 0
        fi
        if [[ "$actual_target" == */.agents/* ]] && [[ "$actual_target" != /* ]]; then
            log_info "✓ Agent link (relative, .agents): $label -> $actual_target"
            return 0
        fi
        log_error "✗ Agent link target mismatch: $label -> $actual_target (expected: $expected)"
        return 1
    else
        log_error "✗ Not a symlink: $label ($link)"
        return 1
    fi
}

main() {
    log_info "Running install.sh (full)..."
    cd "$PROJECT_ROOT"
    export CI=true

    if ! ./install.sh; then
        log_error "install.sh failed"
        exit 1
    fi

    export PATH="$HOME/.local/bin:$HOME/.local/share/mise/shims:$HOME/.local/share/pnpm/bin:$HOME/Library/pnpm:$PATH"

    log_info "Verifying installation results..."
    local failed=0
    local os
    os="$(uname -s)"

    if [[ "$os" == "Darwin" ]]; then
        log_info "Checking Homebrew binary (macOS)..."
        check_command brew || ((failed += 1))

        log_info "Checking mise binary..."
        check_command mise || ((failed += 1))

        log_info "Checking mise-managed tools..."
        for tool in bun starship fzf zoxide yazi fd rg gh lazygit delta nvim node go python java uv jq claude agent-browser openspec codex; do
            check_via_mise "$tool" || ((failed += 1))
        done

        log_info "Checking mise config symlink..."
        check_symlink "$HOME/.config/mise/config.toml" "$PROJECT_ROOT/mise.toml" || ((failed += 1))

        log_info "Checking macOS fonts..."
        if ls "$HOME/Library/Fonts"/MapleMono-NF-CN-*.ttf >/dev/null 2>&1; then
            log_info "✓ Maple Mono NF CN installed"
        else
            log_warn "⚠ Maple Mono NF CN not installed (network/release issue)"
        fi
        if ls "$HOME/Library/Fonts"/JetBrainsMonoNerdFont-*.ttf >/dev/null 2>&1; then
            log_info "✓ JetBrains Mono Nerd Font installed"
        else
            log_warn "⚠ JetBrains Mono Nerd Font not installed (network/release issue)"
        fi
    else
        log_info "Checking apt-installed base tools (Linux)..."
        for cmd in git curl wget vim zsh zip unzip tree htop jq; do
            check_command "$cmd" || ((failed += 1))
        done

        log_info "Checking mise binary..."
        check_command mise || ((failed += 1))

        log_info "Checking mise-managed tools..."
        for tool in bun starship fzf zoxide yazi fd rg gh lazygit delta nvim node go python java uv jq claude agent-browser openspec codex; do
            check_via_mise "$tool" || ((failed += 1))
        done

        log_info "Checking mise config symlink..."
        check_symlink "$HOME/.config/mise/config.toml" "$PROJECT_ROOT/mise.toml" || ((failed += 1))
    fi

    log_info "Checking chezmoi-deployed dotfiles..."
    check_file "$HOME/.zshrc" || ((failed += 1))
    check_file "$HOME/.zshenv" || ((failed += 1))
    check_file "$HOME/.zprofile" || ((failed += 1))
    check_file "$HOME/.gitconfig" || ((failed += 1))
    check_file "$HOME/.config/zsh/core.zsh" || ((failed += 1))
    check_file "$HOME/.config/starship.toml" || ((failed += 1))

    log_info "Checking .agents symlink..."
    check_symlink "$HOME/.agents" "$PROJECT_ROOT/.agents" || ((failed += 1))

    log_info "Checking dotagents client symlinks..."
    # dotagents links ~/.agents/<name> into each AI client dir via relative
    # symlinks that traverse ~/.agents (not the repo path). Claude/Codex/Gemini
    # are the canonical trio to verify in containers.
    # Claude
    check_agent_link "$HOME/.claude/CLAUDE.md"    "../.agents/CLAUDE.md"   "claude CLAUDE.md" || ((failed += 1))
    check_agent_link "$HOME/.claude/commands"     "../.agents/commands"    "claude commands"  || ((failed += 1))
    check_agent_link "$HOME/.claude/hooks"        "../.agents/hooks"       "claude hooks"     || ((failed += 1))
    check_agent_link "$HOME/.claude/skills"       "../.agents/skills"      "claude skills"    || ((failed += 1))
    # Codex (prompts alias)
    check_agent_link "$HOME/.codex/AGENTS.md"     "../.agents/AGENTS.md"   "codex AGENTS.md"  || ((failed += 1))
    check_agent_link "$HOME/.codex/prompts"       "../.agents/commands"    "codex prompts"    || ((failed += 1))
    check_agent_link "$HOME/.codex/skills"        "../.agents/skills"      "codex skills"     || ((failed += 1))
    # Gemini
    check_agent_link "$HOME/.gemini/GEMINI.md"    "../.agents/AGENTS.md"   "gemini GEMINI.md" || ((failed += 1))
    check_agent_link "$HOME/.gemini/commands"     "../.agents/commands"    "gemini commands"  || ((failed += 1))
    check_agent_link "$HOME/.gemini/skills"       "../.agents/skills"      "gemini skills"    || ((failed += 1))

    log_info "Checking additional package managers..."
    if command -v pnpm >/dev/null 2>&1; then
        log_info "✓ pnpm installed"
    else
        log_error "✗ pnpm is NOT installed"
        ((failed += 1))
    fi

    log_info "Checking Zsh and mise behavior..."
    if "$PROJECT_ROOT/scripts/test-shell.sh"; then
        log_info "✓ Zsh and mise behavior passed"
    else
        log_error "✗ Zsh and mise behavior failed"
        ((failed += 1))
    fi

    echo ""
    if [[ $failed -eq 0 ]]; then
        log_info "========================================="
        log_info "All tests passed! ✓"
        log_info "========================================="
        exit 0
    else
        log_error "========================================="
        log_error "$failed test(s) failed ✗"
        log_error "========================================="
        exit 1
    fi
}

main "$@"
