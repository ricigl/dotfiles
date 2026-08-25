#!/usr/bin/env bash
# Static and Nix validation for this repository. Does not modify host services.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$ROOT"

FLAKE_USER="$(sed -nE 's/^[[:space:]]*user = "([^"]+)";.*/\1/p' flake.nix | head -n1)"
if [ -z "$FLAKE_USER" ]; then
  printf '%s\n' "Could not determine the configured user from flake.nix." >&2
  exit 1
fi

for script in \
  bootstrap.sh \
  rebuild.sh \
  scripts/install-home-agents.sh \
  scripts/install-prime-tools.sh \
  scripts/ubuntu-bootstrap.sh \
  scripts/validate.sh \
  tests/smoke-orca-prime.sh \
  tests/test-prime-maintenance.sh; do
  bash -n "$script"
done
python3 -c 'import ast, pathlib; path = pathlib.Path("scripts/prime-maintenance.py"); ast.parse(path.read_text(encoding="utf-8"), filename=str(path))'

json_files=(
  home/.prime/agent/settings.json
  home/.pi/agent/settings.json
  home/.config/mcp/mcp.json
  home/.gemini/config/mcp_config.json
)
if command -v jq >/dev/null 2>&1; then
  for json_file in "${json_files[@]}"; do
    jq empty "$json_file"
  done
elif command -v node >/dev/null 2>&1; then
  node -e 'for (const path of process.argv.slice(1)) JSON.parse(require("fs").readFileSync(path, "utf8"))' "${json_files[@]}"
else
  printf '%s\n' "Neither jq nor node is available to validate settings.json." >&2
  exit 1
fi

tracked_agent_files="$(git ls-files -- '*AGENTS.md' | while IFS= read -r agent_file; do
  if test -e "$agent_file"; then
    printf '%s\n' "$agent_file"
  fi
done | sort)"
test "${tracked_agent_files}" = 'AGENTS.md'
grep -F './modules/home-firstmate.nix' flake.nix >/dev/null
grep -F 'agentPackages = import ./packages' flake.nix >/dev/null
grep -F 'version = "2.0.1"' packages/default.nix >/dev/null
grep -F 'version = "0.10.8"' packages/default.nix >/dev/null
grep -F 'version = "1.57.0"' packages/default.nix >/dev/null
grep -F 'agentPackages.no-mistakes-skill' modules/home-common-agents.nix >/dev/null
grep -F 'pkgs.tmux' modules/home-firstmate.nix >/dev/null
grep -F 'export FM_BACKEND=' modules/home-firstmate.nix >/dev/null
grep -F 'FM_BACKEND:-tmux' modules/home-firstmate.nix >/dev/null
grep -F 'exec pi "$@"' modules/home-firstmate.nix >/dev/null
grep -F 'pi-mcp-adapter@2.27.0' home/.pi/agent/settings.json >/dev/null
if command -v jq >/dev/null 2>&1; then
  jq -e '
    .mcpServers.codebase_memory.command == "codebase-memory-mcp" and
    .mcpServers.codebase_memory.cwd == "/home/ricardo/src" and
    (.mcpServers.codebase_memory.excludeTools | index("delete_project")) != null and
    (.mcpServers.codebase_memory.excludeTools | index("manage_adr")) != null and
    (.mcpServers.codebase_memory.excludeTools | index("ingest_traces")) != null
  ' home/.config/mcp/mcp.json >/dev/null
  jq -e '
    .mcpServers.codebase_memory.command == "codebase-memory-mcp" and
    .mcpServers.codebase_memory.cwd == "/home/ricardo/src" and
    (.mcpServers.codebase_memory.disabledTools | index("delete_project")) != null and
    (.mcpServers.codebase_memory.disabledTools | index("manage_adr")) != null and
    (.mcpServers.codebase_memory.disabledTools | index("ingest_traces")) != null
  ' home/.gemini/config/mcp_config.json >/dev/null
else
  node -e '
    const fs = require("fs");
    const required = ["delete_project", "manage_adr", "ingest_traces"];
    const check = (path, field) => {
      const server = JSON.parse(fs.readFileSync(path, "utf8")).mcpServers.codebase_memory;
      if (server.command !== "codebase-memory-mcp" || server.cwd !== "/home/ricardo/src" || !required.every((name) => server[field].includes(name))) process.exit(1);
    };
    check("home/.config/mcp/mcp.json", "excludeTools");
    check("home/.gemini/config/mcp_config.json", "disabledTools");
  '
fi

git diff --check

secret_pattern='BEGIN (OPENSSH|RSA|EC|DSA) PRIVATE KEY|OPENAI_API_KEY|ANTHROPIC_API_KEY|GITHUB_TOKEN|ghp_[A-Za-z0-9_]+|sk-[A-Za-z0-9_-]+'
if git grep -nE "$secret_pattern" -- . \
  ':!PLAN.md' \
  ':!SPRINT_PLAN.md' \
  ':!scripts/validate.sh'; then
  printf '%s\n' "Potential secret material found in tracked files." >&2
  exit 1
fi

for forbidden_pattern in \
  '.no-mistakes/**' \
  'home/.prime/agent/auth*' \
  'home/.prime/agent/sessions/**' \
  'home/.prime/agent/cache/**' \
  'home/.prime/agent/downloads/**' \
  'home/.prime/agent/telemetry.json' \
  '.codebase-memory/**' \
  'home/.cache/codebase-memory-mcp/**' \
  '**/authorized_keys' \
  '*.private-key' \
  'orca-windows-setup*.exe'; do
  if [ -n "$(git ls-files -- "$forbidden_pattern")" ]; then
    printf 'Forbidden runtime/secret artifact is tracked: %s\n' "$forbidden_pattern" >&2
    exit 1
  fi
done

run_nix_checks() {
  nix --extra-experimental-features 'nix-command flakes' flake check \
    --no-build --no-update-lock-file
  nix --extra-experimental-features 'nix-command flakes' build \
    --no-link --no-update-lock-file \
    ".#homeConfigurations.\"${FLAKE_USER}@wsl\".activationPackage"
  nix --extra-experimental-features 'nix-command flakes' build \
    --no-link --no-update-lock-file \
    ".#homeConfigurations.\"${FLAKE_USER}@wsl-legacy\".activationPackage"
  # Expansion occurs in the shell launched by nix develop, not in this script.
  # shellcheck disable=SC2016
  nix --extra-experimental-features 'nix-command flakes' develop \
    --no-update-lock-file .#orca-prime \
    --command sh -c '
      node --version | grep -Eq "^v22\."
      python3 --version
      uv --version
      gh --version
      test "$PRIME_AGENT_TELEMETRY" = 0
      test "$LAVISH_AXI_HOST" = 127.0.0.1
      test "$NPM_CONFIG_PREFIX" = "$HOME/.local/share/npm"
      case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) exit 1 ;; esac
      test "$CBM_ALLOWED_ROOT" = /home/ricardo/src
      test "$CBM_CACHE_DIR" = /home/ricardo/.cache/codebase-memory-mcp
      test "$CBM_DIAGNOSTICS" = 0
    '
}

if command -v nix >/dev/null 2>&1; then
  run_nix_checks
else
  printf '%s\n' \
    "Nix is unavailable on this host." \
    "Run ./scripts/validate.sh inside the target Ubuntu WSL before activation."
  exit 2
fi

printf '%s\n' "Repository validation passed."
