#!/usr/bin/env bash
# Static and Nix validation for this repository. Does not modify host services.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$ROOT"

for script in \
  bootstrap.sh \
  rebuild.sh \
  scripts/install-prime-tools.sh \
  scripts/ubuntu-bootstrap.sh \
  scripts/validate.sh \
  tests/smoke-orca-prime.sh; do
  bash -n "$script"
done

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
if git grep -nE "$secret_pattern" -- . ':!PLAN.md' ':!SPRINT_PLAN.md'; then
  printf '%s\n' "Potential secret material found in tracked files." >&2
  exit 1
fi

for forbidden in \
  .no-mistakes \
  home/.prime/agent/auth.json \
  home/.prime/agent/telemetry.json \
  authorized_keys; do
  if git ls-files --error-unmatch "$forbidden" >/dev/null 2>&1; then
    printf 'Forbidden runtime/secret artifact is tracked: %s\n' "$forbidden" >&2
    exit 1
  fi
done

run_nix_checks() {
  nix --extra-experimental-features 'nix-command flakes' flake check --no-build
  nix --extra-experimental-features 'nix-command flakes' build \
    '.#homeConfigurations."ricardo@wsl".activationPackage' --dry-run
  nix --extra-experimental-features 'nix-command flakes' build \
    '.#homeConfigurations."ricardo@wsl-legacy".activationPackage' --dry-run
  # Expansion occurs in the shell launched by nix develop, not in this script.
  # shellcheck disable=SC2016
  nix --extra-experimental-features 'nix-command flakes' develop .#orca-prime \
    --command sh -c '
      node --version | grep -Eq "^v22\."
      python3 --version
      uv --version
      gh --version
      test "$PRIME_AGENT_TELEMETRY" = 0
      test "$LAVISH_AXI_HOST" = 127.0.0.1
      test "$NPM_CONFIG_PREFIX" = "$HOME/.local/share/npm"
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
