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
    agentPackages.codebase-memory-mcp
    agentPackages.no-mistakes
    agentPackages.lavish-axi
    agentPackages.gh-axi
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
