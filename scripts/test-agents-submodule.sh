#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

repo="$tmpdir/dotfiles"
home_dir="$tmpdir/home"
mkdir -p "$home_dir"

git clone --no-local "$PROJECT_ROOT" "$repo" >/dev/null

if [[ -e "$repo/.agents/AGENTS.md" ]]; then
    echo "FAIL: clone unexpectedly initialized .agents" >&2
    exit 1
fi

HOME="$home_dir" CI=true "$repo/install.sh" --agents >/dev/null

[[ -f "$repo/.agents/AGENTS.md" ]] || {
    echo "FAIL: --agents did not initialize the submodule" >&2
    exit 1
}
[[ -L "$home_dir/.agents" ]] || {
    echo "FAIL: --agents did not create ~/.agents symlink" >&2
    exit 1
}

printf '\n# dirty submodule test\n' >> "$repo/.agents/AGENTS.md"
if HOME="$home_dir" CI=true "$repo/install.sh" --agents >"$tmpdir/dirty.log" 2>&1; then
    echo "FAIL: dirty submodule was accepted" >&2
    exit 1
fi
if ! grep -qF 'agents submodule... FAILED (working tree has local changes)' "$tmpdir/dirty.log"; then
    echo "FAIL: dirty submodule failure was not explicit" >&2
    exit 1
fi

echo "Agents submodule test passed!"
