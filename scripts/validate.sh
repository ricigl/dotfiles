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
  scripts/install-codebase-memory.sh \
  scripts/install-home-agents.sh \
  scripts/install-no-mistakes.sh \
  scripts/install-prime-tools.sh \
  scripts/ubuntu-bootstrap.sh \
  scripts/validate.sh \
  tests/smoke-orca-prime.sh \
  tests/test-prime-maintenance.sh; do
  bash -n "$script"
done
python3 -c 'import ast, pathlib; path = pathlib.Path("scripts/prime-maintenance.py"); ast.parse(path.read_text(encoding="utf-8"), filename=str(path))'

if command -v jq >/dev/null 2>&1; then
  jq empty home/.prime/agent/settings.json
elif command -v node >/dev/null 2>&1; then
  node -e 'JSON.parse(require("fs").readFileSync("home/.prime/agent/settings.json", "utf8"))'
else
  printf '%s\n' "Neither jq nor node is available to validate settings.json." >&2
  exit 1
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
