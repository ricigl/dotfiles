#!/usr/bin/env bash
# Runtime smoke checks for Ubuntu WSL after Home Manager/tool activation.
set -euo pipefail

if ! grep -qi microsoft /proc/sys/kernel/osrelease 2>/dev/null; then
  printf '%s\n' "This smoke test must run inside Ubuntu WSL." >&2
  exit 1
fi

for command_name in git make g++ python3 node npm nvim zsh starship; do
  command -v "$command_name" >/dev/null 2>&1 || {
    printf 'Missing command: %s\n' "$command_name" >&2
    exit 1
  }
done

case "$(pwd -P)" in
  /home/*) ;;
  *)
    printf '%s\n' "Run from a Linux-owned path under /home, never /mnt/c." >&2
    exit 1
    ;;
esac

if [ "${IN_NIX_SHELL:-}" ]; then
  node --version | grep -Eq '^v22\.' || {
    printf '%s\n' "orca-prime shell must resolve Node 22." >&2
    exit 1
  }
  [ "${PRIME_AGENT_TELEMETRY:-}" = "0" ]
  [ "${LAVISH_AXI_TELEMETRY:-}" = "0" ]
  [ "${LAVISH_AXI_NO_OPEN:-}" = "1" ]
  [ "${LAVISH_AXI_HOST:-}" = "127.0.0.1" ]
else
  node --version | grep -Eq '^v24\.' || {
    printf '%s\n' "Default Home Manager profile must resolve global Node 24." >&2
    exit 1
  }
fi

if command -v prime-agent >/dev/null 2>&1; then
  prime-agent --version
fi
if command -v lavish-axi >/dev/null 2>&1; then
  lavish-axi --version
fi
if command -v gh-axi >/dev/null 2>&1; then
  gh-axi --version
fi

settings="$HOME/.prime/agent/settings.json"
policy="$HOME/.prime/agent/AGENTS.md"
skill="$HOME/.prime/agent/skills/i-have-adhd/SKILL.md"
for required_file in "$settings" "$policy" "$skill"; do
  test -r "$required_file" || {
    printf 'Missing Home Manager file: %s\n' "$required_file" >&2
    exit 1
  }
done

printf '%s\n' \
  "Ubuntu WSL runtime smoke passed." \
  "Repository: $(git rev-parse --show-toplevel 2>/dev/null || printf 'not inside Git')" \
  "Node: $(node --version)" \
  "Python: $(python3 --version)"
