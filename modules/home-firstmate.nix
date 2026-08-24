{ pkgs, ... }:

let
  firstmate = pkgs.writeShellScriptBin "firstmate" ''
    set -euo pipefail
    root="''${FIRSTMATE_ROOT:-''${XDG_DATA_HOME:-$HOME/.local/share}/firstmate}"

    if [ ! -x "$root/bin/fm-session-start.sh" ] || [ ! -f "$root/AGENTS.md" ]; then
      printf '%s\n' "Firstmate is not installed at $root." >&2
      printf '%s\n' "Run: $HOME/.dotfiles/scripts/install-firstmate.sh" >&2
      exit 1
    fi

    command -v pi >/dev/null 2>&1 || {
      printf '%s\n' "Pi is required to launch Firstmate. Run ./scripts/install-home-agents.sh first." >&2
      exit 1
    }

    cd "$root"
    export FM_ROOT_OVERRIDE="$root"
    export FM_HOME="$root"
    exec pi "$@"
  '';
in
{
  home.packages = [
    firstmate
    pkgs.tmux
  ];
}
