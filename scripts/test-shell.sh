#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

log_info()  { printf '[INFO] %s\n' "$*"; }
log_error() { printf '[ERROR] %s\n' "$*" >&2; }

run_in_pty() {
    if [[ "$(uname -s)" == "Darwin" ]]; then
        script -q /dev/null "$@"
        return
    fi

    local command
    printf -v command '%q ' "$@"
    script -qec "$command" /dev/null
}

if ! command -v mise >/dev/null 2>&1; then
    log_info "Installing tools and shell configuration..."
    CI=true "$PROJECT_ROOT/install.sh" --tools --shell
fi

export PATH="$HOME/.local/bin:$HOME/.local/share/mise/shims:$HOME/.local/share/pnpm/bin:$PATH"

log_info "Checking Zsh syntax..."
zsh -n "$HOME/.zshenv" "$HOME/.zprofile" "$HOME/.zshrc" "$HOME/.config/zsh/core.zsh"

log_info "Checking complete interactive initialization..."
shell_state="$(
    run_in_pty env TERM=xterm-256color zsh -lic \
        '_fzf_lazy_load; print -r -- shell-ok:$ZSH_CONFIG_DIR node:$(node --version) bun:$(bun --version) pnpm:$(pnpm --version) fzf:$fzf_default_completion tab:$(bindkey "^I")'
)"
shell_state="${shell_state//$'\r'/}"
printf '%s\n' "$shell_state"

grep -q 'shell-ok:.*/.config/zsh' <<<"$shell_state"
grep -q 'node:v' <<<"$shell_state"
grep -q 'bun:' <<<"$shell_state"
grep -q 'pnpm:' <<<"$shell_state"
grep -q 'fzf:expand-or-complete' <<<"$shell_state"
grep -q 'fzf-completion' <<<"$shell_state"
env TERM=xterm-256color zsh -lic '[[ "$(alias oc)" == "oc=opencode2" ]]'

log_info "Checking Starship scan timeout..."
scan_timeout="$(starship print-config | awk '$1 == "scan_timeout" { print $3; exit }')"
if [[ "$scan_timeout" != "50" ]]; then
    log_error "Expected Starship scan_timeout=50, got ${scan_timeout:-missing}"
    exit 1
fi

log_info "Checking mise runtime resolution..."
mise which node >/dev/null
mise which bun >/dev/null
mise which python >/dev/null
mise which codex >/dev/null
mise exec -- node -e 'process.exit(process.version.startsWith("v") ? 0 : 1)'
mise exec -- bun --version >/dev/null
mise exec -- python -c 'import sys; raise SystemExit(sys.version_info < (3, 14))'
command -v opencode2 >/dev/null
opencode2 --version | grep -q '^opencode2 v'

log_info "Measuring full interactive startup..."
timings="$(mktemp)"
trap 'rm -f "$timings"' EXIT
for _ in $(seq 1 20); do
    run_in_pty /usr/bin/time -p env TERM=xterm-256color zsh -lic exit
done | sed -n 's/.*real[[:space:]]\{1,\}\([0-9.]*\).*/\1/p' >"$timings"

result="$(
    sort -n "$timings" | awk '
        { values[++n] = $1 }
        END {
            if (n != 20) exit 1
            p50 = values[int((n - 1) * 0.50) + 1]
            p95 = values[int((n - 1) * 0.95) + 1]
            printf "runs=%d p50=%.3fs p95=%.3fs\n", n, p50, p95
            if (p95 > 0.100) exit 2
        }
    '
)" || {
    status=$?
    [[ -n "$result" ]] && log_info "$result"
    [[ $status -eq 2 ]] && log_error "Zsh startup P95 exceeds 100 ms"
    exit "$status"
}
log_info "$result"
log_info "Zsh and mise integration passed"
