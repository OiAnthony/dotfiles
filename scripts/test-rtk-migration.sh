#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

log_info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

write_rtk_fixture() {
    local home_dir=$1
    mkdir -p "$home_dir/.claude"
    cat > "$home_dir/.claude/settings.json" <<'EOF'
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {"type": "command", "command": "rtk hook claude"}
        ]
      },
      {
        "matcher": "Write",
        "hooks": [
          {"type": "command", "command": "keep-this-hook"}
        ]
      }
    ]
  }
}
EOF
}

tmpdir=""

main() {
    tmpdir=$(mktemp -d)
    trap 'rm -rf "$tmpdir"' EXIT

    local fake_bin="$tmpdir/bin"
    mkdir -p "$fake_bin"
    local rtk_log="$tmpdir/rtk.log"
    cat > "$fake_bin/rtk" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" > "${RTK_TEST_LOG:?}"
EOF
    chmod +x "$fake_bin/rtk"

    local success_home="$tmpdir/success-home"
    write_rtk_fixture "$success_home"
    log_info "Checking official RTK uninstall invocation..."
    if ! HOME="$success_home" PATH="$fake_bin:/usr/bin:/bin" RTK_TEST_LOG="$rtk_log" CI=true \
        "$PROJECT_ROOT/install.sh" --agents >/dev/null 2>&1; then
        log_error "migration failed when rtk was available"
        exit 1
    fi
    if [[ "$(cat "$rtk_log")" == "init -g --uninstall" ]]; then
        log_info "OK: official uninstall command invoked"
    else
        log_error "official uninstall command was not invoked"
        exit 1
    fi

    local missing_home="$tmpdir/missing-home"
    write_rtk_fixture "$missing_home"
    local missing_log="$tmpdir/missing.log"
    log_info "Checking missing-rtk failure path..."
    if HOME="$missing_home" PATH="/usr/bin:/bin" CI=true \
        "$PROJECT_ROOT/install.sh" --agents >"$missing_log" 2>&1; then
        log_error "migration succeeded without the rtk binary"
        exit 1
    fi
    if grep -qF 'rtk not found; run: rtk init -g --uninstall' "$missing_log"; then
        log_info "OK: missing binary produces an actionable failure"
    else
        log_error "missing binary failure message is incomplete"
        cat "$missing_log"
        exit 1
    fi

    local clean_home="$tmpdir/clean-home"
    mkdir -p "$clean_home"
    log_info "Checking no-op path without an RTK installation..."
    if ! HOME="$clean_home" PATH="/usr/bin:/bin" CI=true \
        "$PROJECT_ROOT/install.sh" --agents >/dev/null 2>&1; then
        log_error "migration failed without an RTK installation"
        exit 1
    fi

    log_info "RTK migration checks passed!"
}

main "$@"
