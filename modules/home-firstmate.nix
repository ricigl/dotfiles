{ pkgs, ... }:

let
  firstmate = pkgs.writeShellScriptBin "firstmate" ''
    set -euo pipefail
    root="''${FIRSTMATE_ROOT:-$HOME/firstmate}"

    if [ ! -x "$root/bin/fm-session-start.sh" ] || [ ! -f "$root/AGENTS.md" ]; then
      printf '%s\n' "Firstmate is not installed at $root." >&2
      printf '%s\n' "Run: $HOME/.dotfiles/scripts/install-firstmate.sh" >&2
      exit 1
    fi

    command -v pi >/dev/null 2>&1 || {
      printf '%s\n' "Pi is required to launch Firstmate. Run ./scripts/install-home-agents.sh first." >&2
      exit 1
    }

    command -v tmux >/dev/null 2>&1 || {
      printf '%s\n' "tmux is required for Firstmate's Linux backend." >&2
      exit 1
    }

    if [ "''${FM_BACKEND:-tmux}" = "orca" ]; then
      printf '%s\n' "Firstmate's orca backend is macOS-only; use the Linux tmux/Treehouse backend in WSL." >&2
      exit 1
    fi
    command -v treehouse >/dev/null 2>&1 || {
      printf '%s\n' "treehouse is required for Firstmate crew worktrees." >&2
      printf '%s\n' "Install the reviewed Treehouse pin before dispatching crew tasks." >&2
      exit 1
    }

    mkdir -p "$root/projects"
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
    pkgs.tmux
  ];
}
