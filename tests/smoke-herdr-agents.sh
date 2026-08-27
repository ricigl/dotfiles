#!/usr/bin/env bash
# Runtime smoke checks for Ubuntu WSL after Home Manager/tool activation.
set -euo pipefail

if ! grep -qi microsoft /proc/sys/kernel/osrelease 2>/dev/null; then
  printf '%s\n' "This smoke test must run inside Ubuntu WSL." >&2
  exit 1
fi

for command_name in git make g++ python3 node npm nvim zsh starship jq herdr prime prime-agent prime-maintenance no-mistakes agy pi firstmate treehouse fm-session-start.sh lavish-axi gh-axi codebase-memory-mcp; do
  command -v "$command_name" >/dev/null 2>&1 || {
    printf 'Missing command: %s\n' "$command_name" >&2
    exit 1
  }
done

prime-maintenance --help >/dev/null
herdr --version
prime --version
prime-agent --version
no-mistakes --version
agy --version
pi --version
treehouse --version
lavish-axi --version
gh-axi --version

[ "${NO_MISTAKES_TELEMETRY:-}" = "0" ]
[ "${NO_MISTAKES_NO_UPDATE_CHECK:-}" = "1" ]

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
  [ "${NPM_CONFIG_PREFIX:-}" = "$HOME/.local/share/npm" ]
  case ":${PATH}:" in *":$HOME/.local/share/npm/bin:"*) ;; *) exit 1 ;; esac
  [ "${CBM_ALLOWED_ROOT:-}" = "/home/ricardo" ]
  [ "${CBM_CACHE_DIR:-}" = "/home/ricardo/.cache/codebase-memory-mcp" ]
  [ "${CBM_DIAGNOSTICS:-}" = "0" ]
  codebase-memory-mcp --version | grep -Eq '0\.10\.8'
else
  node --version | grep -Eq '^v24\.' || {
    printf '%s\n' "Default Home Manager profile must resolve global Node 24." >&2
    exit 1
  }
  [ "${PRIME_AGENT_TELEMETRY:-}" = "0" ]
  [ "${LAVISH_AXI_TELEMETRY:-}" = "0" ]
  [ "${LAVISH_AXI_NO_OPEN:-}" = "1" ]
  [ "${LAVISH_AXI_HOST:-}" = "127.0.0.1" ]
  [ "${NPM_CONFIG_PREFIX:-}" = "$HOME/.local/share/npm" ]
  case ":${PATH}:" in *":$HOME/.local/share/npm/bin:"*) ;; *) exit 1 ;; esac
  [ "${CBM_ALLOWED_ROOT:-}" = "/home/ricardo" ]
  [ "${CBM_CACHE_DIR:-}" = "/home/ricardo/.cache/codebase-memory-mcp" ]
  [ "${CBM_DIAGNOSTICS:-}" = "0" ]
  codebase-memory-mcp --version | grep -Eq '0\.10\.8'
fi

settings="$HOME/.prime/agent/settings.json"
policy="$HOME/.prime/agent/AGENTS.md"
skill="$HOME/.prime/agent/skills/i-have-adhd/SKILL.md"
shared_policy="$HOME/.pi/agent/AGENTS.md"
agy_policy="$HOME/.gemini/GEMINI.md"
pi_mcp="$HOME/.config/mcp/mcp.json"
agy_mcp="$HOME/.gemini/config/mcp_config.json"
shared_skill="$HOME/.agents/skills/caveman/SKILL.md"
shared_no_mistakes_skill="$HOME/.agents/skills/no-mistakes/SKILL.md"
agy_skill="$HOME/.gemini/antigravity-cli/skills/caveman/SKILL.md"
no_mistakes_skill="$HOME/.gemini/antigravity-cli/skills/no-mistakes/SKILL.md"
prime_no_mistakes_skill="$HOME/.prime/agent/skills/no-mistakes/SKILL.md"
firstmate_root="${FIRSTMATE_ROOT:-$HOME/firstmate}"
for required_file in "$settings" "$policy" "$skill" "$shared_policy" "$agy_policy" "$pi_mcp" "$agy_mcp" "$shared_skill" "$shared_no_mistakes_skill" "$agy_skill" "$no_mistakes_skill" "$prime_no_mistakes_skill"; do
  test -r "$required_file" || {
    printf 'Missing Home Manager file: %s\n' "$required_file" >&2
    exit 1
  }
done

if [ -d "$firstmate_root" ]; then
  for firstmate_path in AGENTS.md projects; do
    test -e "$firstmate_root/$firstmate_path" || {
      printf 'Missing Firstmate runtime path: %s/%s\n' "$firstmate_root" "$firstmate_path" >&2
      exit 1
    }
  done
fi

cmp -s "$shared_policy" "$agy_policy"
cmp -s "$shared_policy" "$policy"
pi list | grep -F 'pi-mcp-adapter' >/dev/null

jq -e '
  .mcpServers.codebase_memory.command == "codebase-memory-mcp" and
  .mcpServers.codebase_memory.cwd == "/home/ricardo/src" and
  .mcpServers.codebase_memory.env.CBM_ALLOWED_ROOT == "/home/ricardo" and
  (.mcpServers.codebase_memory.excludeTools | index("delete_project")) != null and
  (.mcpServers.codebase_memory.excludeTools | index("manage_adr")) != null and
  (.mcpServers.codebase_memory.excludeTools | index("ingest_traces")) != null
' "$pi_mcp" >/dev/null

jq -e '
  .mcpServers.codebase_memory.command == "codebase-memory-mcp" and
  .mcpServers.codebase_memory.cwd == "/home/ricardo/src" and
  .mcpServers.codebase_memory.env.CBM_ALLOWED_ROOT == "/home/ricardo" and
  (.mcpServers.codebase_memory.disabledTools | index("delete_project")) != null and
  (.mcpServers.codebase_memory.disabledTools | index("manage_adr")) != null and
  (.mcpServers.codebase_memory.disabledTools | index("ingest_traces")) != null
' "$agy_mcp" >/dev/null

jq -e '
  .mcpServers.codebase_memory.type == "stdio" and
  .mcpServers.codebase_memory.command == "codebase-memory-mcp" and
  .mcpServers.codebase_memory.cwd == "/home/ricardo/src" and
  .mcpServers.codebase_memory.env.CBM_ALLOWED_ROOT.env == "CBM_ALLOWED_ROOT" and
  .mcpServers.codebase_memory.env.CBM_CACHE_DIR.env == "CBM_CACHE_DIR" and
  .mcpServers.codebase_memory.env.CBM_DIAGNOSTICS.env == "CBM_DIAGNOSTICS" and
  (.mcpServers.codebase_memory.disabledTools | index("delete_project")) != null and
  (.mcpServers.codebase_memory.disabledTools | index("manage_adr")) != null and
  (.mcpServers.codebase_memory.disabledTools | index("ingest_traces")) != null
' "$settings" >/dev/null

printf '%s\n' \
  "Ubuntu WSL Herdr runtime smoke passed." \
  "Repository: $(git rev-parse --show-toplevel 2>/dev/null || printf 'not inside Git')" \
  "Node: $(node --version)" \
  "Python: $(python3 --version)"
