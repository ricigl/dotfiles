{ pkgs, agentPackages, ... }:

let
  firstmate = pkgs.writeShellScriptBin "firstmate" ''
    set -euo pipefail
    root="''${FIRSTMATE_ROOT:-$HOME/firstmate}"

    command -v pi >/dev/null 2>&1 || {
      printf '%s\n' "Pi is required to launch Firstmate. Run ./scripts/install-home-agents.sh first." >&2
      exit 1
    }
    command -v tmux >/dev/null 2>&1 || {
      printf '%s\n' "tmux is required for Firstmate's Linux backend." >&2
      exit 1
    }
    command -v treehouse >/dev/null 2>&1 || {
      printf '%s\n' "treehouse is required for Firstmate crew worktrees." >&2
      exit 1
    }
    command -v fm-session-start.sh >/dev/null 2>&1 || {
      printf '%s\n' "The Nix Firstmate package is missing its session-start command." >&2
      exit 1
    }
    if [ "''${FM_BACKEND:-tmux}" = "orca" ]; then
      printf '%s\n' "Firstmate's orca backend is macOS-only; use the Linux tmux/Treehouse backend in WSL." >&2
      exit 1
    fi

    mkdir -p "$root/projects"
    if [ ! -f "$root/AGENTS.md" ]; then
      install -Dm0644 "${agentPackages.firstmate}/share/firstmate/AGENTS.md" "$root/AGENTS.md"
    fi
    cd "$root"
    export FM_ROOT_OVERRIDE="$root"
    export FM_HOME="$root"
    export FM_BACKEND="''${FM_BACKEND:-tmux}"
    exec pi "$@"
  '';
in
{
  home.packages = [
    firstmate
    agentPackages.firstmate
    agentPackages.treehouse
    pkgs.tmux
  ];
}
