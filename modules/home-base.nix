{ config, lib, pkgs, user, herdr, agentPackages, ... }:

let
  dotfiles = "${config.home.homeDirectory}/.dotfiles";
  setxkbmapPkg = pkgs.setxkbmap or pkgs.xorg.setxkbmap;
  primeLauncher = pkgs.writeShellScriptBin "prime" ''
    if ! command -v prime-agent >/dev/null 2>&1; then
      printf '%s\n' "prime-agent is not installed in the regular Home Manager shell." >&2
      printf '%s\n' "Run: $HOME/.dotfiles/scripts/install-prime-tools.sh" >&2
      exit 1
    fi

    runtime_parent="''${XDG_RUNTIME_DIR:-/tmp}"
    runtime_dir="$runtime_parent/prime-agent-$(id -u)"
    mkdir -p "$runtime_dir"
    chmod 700 "$runtime_dir"

    # Keep the Prime daemon socket stable across fresh shell invocations while
    # preserving the exact argv passed to prime-agent.
    exec env TMPDIR="$runtime_parent" prime-agent "$@"
  '';
  primeMaintenance = pkgs.writeShellScriptBin "prime-maintenance" ''
    exec "${dotfiles}/scripts/prime-maintenance.py" "$@"
  '';
  wslgHook = ''
    # WSLg GUI and audio socket discovery for SSH and noninteractive sessions.
    if [ -z "''${DISPLAY:-}" ] && [ -e /tmp/.X11-unix/X0 ]; then
      export DISPLAY=:0
    fi

    if [ -e /mnt/wslg/runtime-dir/wayland-0 ]; then
      if [ -z "''${WAYLAND_DISPLAY:-}" ]; then
        export WAYLAND_DISPLAY=wayland-0
      fi
      if [ -z "''${XDG_RUNTIME_DIR:-}" ]; then
        export XDG_RUNTIME_DIR=/mnt/wslg/runtime-dir
      fi
    fi

    if [ -z "''${PULSE_SERVER:-}" ] && [ -e /mnt/wslg/PulseServer ]; then
      export PULSE_SERVER=unix:/mnt/wslg/PulseServer
    fi
  '';
  bashHandoff = ''
    # Guard: interactive shell only, not already in Zsh.
    if [[ $- == *i* ]] && [ -z "''${ZSH_VERSION:-}" ] && [ -z "''${ZSH_NAME:-}" ]; then
      if [ -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' ]; then
        . '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh'
      elif [ -e '/nix/var/nix/profiles/default/etc/profile.d/nix.sh' ]; then
        . '/nix/var/nix/profiles/default/etc/profile.d/nix.sh'
      fi

      if [ -z "''${__HM_SESS_VARS_SOURCED:-}" ]; then
        if [ -f "${config.home.profileDirectory}/etc/profile.d/hm-session-vars.sh" ]; then
          . "${config.home.profileDirectory}/etc/profile.d/hm-session-vars.sh"
        elif [ -f "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh" ]; then
          . "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh"
        fi
      fi

      if command -v zsh >/dev/null 2>&1; then
        exec zsh -l
      elif [ -x "${config.home.profileDirectory}/bin/zsh" ]; then
        exec "${config.home.profileDirectory}/bin/zsh" -l
      elif [ -x "$HOME/.nix-profile/bin/zsh" ]; then
        exec "$HOME/.nix-profile/bin/zsh" -l
      fi
    fi
  '';
in
{
  home.packages = (with pkgs; [
    ripgrep
    fd
    fzf
    jq
    curl
    gh
    lazygit
    nodejs_24
    setxkbmapPkg
    neovim
    nerd-fonts.hack
    google-chrome
    agentPackages.codebase-memory-mcp
    agentPackages.no-mistakes
    agentPackages.lavish-axi
    agentPackages.gh-axi
    agentPackages.quota-axi
    agentPackages.tasks-axi
    agentPackages.chrome-devtools-axi
    primeLauncher
    primeMaintenance
  ]) ++ [
    herdr.packages.${pkgs.system}.default
  ];

  fonts.fontconfig.enable = true;

  home.sessionPath = [
    "${config.home.homeDirectory}/.local/bin"
    "${config.home.homeDirectory}/.local/share/npm/bin"
  ];

  home.sessionVariables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
    NPM_CONFIG_PREFIX = "${config.home.homeDirectory}/.local/share/npm";
    NO_MISTAKES_TELEMETRY = "0";
    NO_MISTAKES_NO_UPDATE_CHECK = "1";
    CHROME_DEVTOOLS_AXI_USER_DATA_DIR = "${config.home.homeDirectory}/.local/share/chrome-devtools-axi/dev-profile";
    CHROME_DEVTOOLS_AXI_HEADED = "1";
  };

  home.activation.createChromeDevtoolsProfileDir = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD mkdir -p "${config.home.homeDirectory}/.local/share/chrome-devtools-axi/dev-profile"
    $DRY_RUN_CMD chmod 0700 "${config.home.homeDirectory}/.local/share/chrome-devtools-axi/dev-profile"
  '';

  programs.bash = {
    enable = true;
    bashrcExtra = wslgHook;
    profileExtra = bashHandoff;
    initExtra = bashHandoff;
  };

  programs.git = {
    enable = true;
    settings = {
      init.defaultBranch = "main";
      pull.rebase = false;
    };
  };

  programs.zsh = {
    enable = true;
    envExtra = wslgHook;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    initContent = lib.mkBefore ''
      # Keep Herdr relay and other noninteractive SSH sessions quiet.
      [[ -o interactive ]] || return

      # Configure the WSLg X server for a Brazilian ABNT2 keyboard.
      if [[ -n "$DISPLAY" ]]; then
        ${setxkbmapPkg}/bin/setxkbmap -layout br -variant abnt2 >/dev/null 2>&1 || true
      fi
    '';

    shellAliases = {
      ".." = "cd ..";
      agy = "command agy --dangerously-skip-permissions";
      add = "git add .";
      push = "git push";
      pull = "git pull";
      m = "git switch main";
      rebuild = "${dotfiles}/rebuild.sh";
    };
  };

  programs.starship = {
    enable = true;
    settings = {
      add_newline = false;
      format = "$directory$git_branch$git_status$cmd_duration$line_break$character";
      character = {
        success_symbol = "[❯](purple)";
        error_symbol = "[❯](red)";
      };
      cmd_duration.format = "[$duration]($style) ";
    };
  };

  # Editable Neovim configuration remains linked from this repository.
  home.file.".config/nvim".source =
    config.lib.file.mkOutOfStoreSymlink
      "${dotfiles}/home/.config/nvim";

  home.file.".config/herdr".source =
    config.lib.file.mkOutOfStoreSymlink
      "${dotfiles}/home/.config/herdr";
}
