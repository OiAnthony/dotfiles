#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

log_info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

main() {
    cd "$PROJECT_ROOT"
    export CI=true

    log_info "Running install.sh first time..."
    if ! ./install.sh; then
        log_error "First run failed"
        exit 1
    fi
    export PATH="$HOME/.local/bin:$PATH"

    log_info "Recording state after first run..."
    local zshrc_md5
    local zshenv_md5
    local zprofile_md5
    local core_md5
    local gitconfig_md5
    local starship_md5

    zshrc_md5=$(md5sum "$HOME/.zshrc" | awk '{print $1}')
    zshenv_md5=$(md5sum "$HOME/.zshenv" | awk '{print $1}')
    zprofile_md5=$(md5sum "$HOME/.zprofile" | awk '{print $1}')
    core_md5=$(md5sum "$HOME/.config/zsh/core.zsh" | awk '{print $1}')
    gitconfig_md5=$(md5sum "$HOME/.gitconfig" | awk '{print $1}')
    starship_md5=$(md5sum "$HOME/.config/starship.toml" | awk '{print $1}')

    log_info "State recorded:"
    log_info "  .zshrc md5: $zshrc_md5"
    log_info "  .zshenv md5: $zshenv_md5"
    log_info "  .zprofile md5: $zprofile_md5"
    log_info "  core.zsh md5: $core_md5"
    log_info "  .gitconfig md5: $gitconfig_md5"
    log_info "  starship.toml md5: $starship_md5"

    log_info "Running install.sh second time..."
    if ! ./install.sh; then
        log_error "Second run failed"
        exit 1
    fi

    log_info "Verifying state after second run..."
    local failed=0

    local zshrc_md5_after
    local zshenv_md5_after
    local zprofile_md5_after
    local core_md5_after
    local gitconfig_md5_after
    local starship_md5_after

    zshrc_md5_after=$(md5sum "$HOME/.zshrc" | awk '{print $1}')
    zshenv_md5_after=$(md5sum "$HOME/.zshenv" | awk '{print $1}')
    zprofile_md5_after=$(md5sum "$HOME/.zprofile" | awk '{print $1}')
    core_md5_after=$(md5sum "$HOME/.config/zsh/core.zsh" | awk '{print $1}')
    gitconfig_md5_after=$(md5sum "$HOME/.gitconfig" | awk '{print $1}')
    starship_md5_after=$(md5sum "$HOME/.config/starship.toml" | awk '{print $1}')

    if [[ "$zshrc_md5" == "$zshrc_md5_after" ]]; then
        log_info "✓ .zshrc unchanged"
    else
        log_error "✗ .zshrc changed"
        ((failed += 1))
    fi

    if [[ "$zshenv_md5" == "$zshenv_md5_after" ]]; then
        log_info "✓ .zshenv unchanged"
    else
        log_error "✗ .zshenv changed"
        ((failed += 1))
    fi

    if [[ "$zprofile_md5" == "$zprofile_md5_after" ]]; then
        log_info "✓ .zprofile unchanged"
    else
        log_error "✗ .zprofile changed"
        ((failed += 1))
    fi

    if [[ "$core_md5" == "$core_md5_after" ]]; then
        log_info "✓ core.zsh unchanged"
    else
        log_error "✗ core.zsh changed"
        ((failed += 1))
    fi

    if [[ "$gitconfig_md5" == "$gitconfig_md5_after" ]]; then
        log_info "✓ .gitconfig unchanged"
    else
        log_error "✗ .gitconfig changed"
        ((failed += 1))
    fi

    if [[ "$starship_md5" == "$starship_md5_after" ]]; then
        log_info "✓ starship.toml unchanged"
    else
        log_error "✗ starship.toml changed"
        ((failed += 1))
    fi

    echo ""
    if [[ $failed -eq 0 ]]; then
        log_info "========================================="
        log_info "Idempotent test passed! ✓"
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
