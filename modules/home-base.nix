{ config, lib, pkgs, user, ... }:

let
  dotfiles = "${config.home.homeDirectory}/.dotfiles";
  setxkbmapPkg = pkgs.setxkbmap or pkgs.xorg.setxkbmap;
  primeLauncher = pkgs.writeShellScriptBin "prime" ''
    if ! command -v nix >/dev/null 2>&1; then
      printf '%s\n' "Nix is required to launch the pinned Orca/Prime environment." >&2
      exit 1
    fi

    runtime_parent="''${XDG_RUNTIME_DIR:-/tmp}"
    runtime_dir="$runtime_parent/prime-agent-$(id -u)"
    mkdir -p "$runtime_dir"
    chmod 700 "$runtime_dir"

    # Nix gives every development-shell invocation a new TMPDIR. Prime derives
    # its daemon socket from TMPDIR, so override it only for the Prime process.
    # This keeps argv untouched because some subcommands reject global options.
    exec nix develop "$HOME/.dotfiles#orca-prime" \
      --command env TMPDIR="$runtime_parent" prime-agent "$@"
  '';
in
{
  home.packages = with pkgs; [
    ripgrep
    fd
    fzf
    jq
    gh
    lazygit
    nodejs_24
    setxkbmapPkg
    neovim
    nerd-fonts.hack
    primeLauncher
  ];

  fonts.fontconfig.enable = true;

  home.sessionVariables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
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
      # Keep Orca relay and other noninteractive SSH sessions quiet.
      [[ -o interactive ]] || return

      bindkey '^f' autosuggest-accept

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
      rebuild = "home-manager switch --flake ~/.dotfiles#${user}@wsl";
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
}
