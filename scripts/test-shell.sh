#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

log_info()  { printf '[INFO] %s\n' "$*"; }
log_error() { printf '[ERROR] %s\n' "$*" >&2; }

if ! command -v mise >/dev/null 2>&1; then
    log_info "Installing tools and shell configuration..."
    CI=true "$PROJECT_ROOT/install.sh" --tools --shell
fi

export PATH="$HOME/.local/bin:$HOME/.local/share/mise/shims:$HOME/.local/share/pnpm/bin:$PATH"

log_info "Checking Zsh syntax..."
zsh -n "$HOME/.zshenv" "$HOME/.zprofile" "$HOME/.zshrc" "$HOME/.config/zsh/core.zsh"

log_info "Checking complete interactive initialization..."
shell_state="$(
    script -qec \
        "env TERM=xterm-256color zsh -lic '_fzf_lazy_load; print -r -- shell-ok:\$ZSH_CONFIG_DIR node:\$(node --version) bun:\$(bun --version) pnpm:\$(pnpm --version) fzf:\$fzf_default_completion tab:\$(bindkey \"^I\")'" \
        /dev/null
)"
shell_state="${shell_state//$'\r'/}"
printf '%s\n' "$shell_state"

grep -q 'shell-ok:.*/.config/zsh' <<<"$shell_state"
grep -q 'node:v' <<<"$shell_state"
grep -q 'bun:' <<<"$shell_state"
grep -q 'pnpm:' <<<"$shell_state"
grep -q 'fzf:expand-or-complete' <<<"$shell_state"
grep -q 'fzf-completion' <<<"$shell_state"

log_info "Checking mise runtime resolution..."
mise which node >/dev/null
mise which bun >/dev/null
mise which python >/dev/null
mise which codex >/dev/null
mise exec -- node -e 'process.exit(process.version.startsWith("v") ? 0 : 1)'
mise exec -- bun --version >/dev/null
mise exec -- python -c 'import sys; raise SystemExit(sys.version_info < (3, 14))'

log_info "Measuring full interactive startup..."
timings="$(mktemp)"
trap 'rm -f "$timings"' EXIT
for _ in $(seq 1 20); do
    script -qec \
        "/usr/bin/time -f 'startup=%e' env TERM=xterm-256color zsh -lic exit" \
        /dev/null
done | sed -n 's/.*startup=\([0-9.]*\).*/\1/p' >"$timings"

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
