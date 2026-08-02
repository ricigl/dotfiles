{ config, pkgs, user, herdr, ... }:

let
  dotfiles = "${config.home.homeDirectory}/.dotfiles";
in
{
  home.username = user;
  home.homeDirectory = "/home/${user}";

  # Do not routinely update this value.
  home.stateVersion = "24.11";
  
  targets.genericLinux.enable = true;  

  home.packages = (with pkgs; [
    # Command-line utilities
    ripgrep
    fd
    fzf
    jq
    gh
    lazygit

    # Editor
    neovim

    # Terminal and coding agents
    claude-code
    codex
    wezterm

    # Font used by WezTerm and Neovim
    nerd-fonts.hack
  ]) ++ [
    # Herdr comes from its official pinned flake.
    herdr.packages.${pkgs.system}.default
  ];

  fonts.fontconfig.enable = true;

  home.sessionVariables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
  };

  # Installs the home-manager command into the user profile.
  programs.home-manager.enable = true;

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

    initContent = ''
      bindkey '^f' autosuggest-accept
    '';

    shellAliases = {
      ".." = "cd ..";

      add = "git add .";
      push = "git push";
      pull = "git pull";
      m = "git switch main";

      cc = "claude --dangerously-skip-permissions";
      co = "codex --ask-for-approval never --sandbox workspace-write";

      rebuild = "home-manager switch --flake ~/.dotfiles#${user}@wsl";
    };
  };

  programs.starship = {
    enable = true;

    settings = {
      add_newline = false;

      format =
        "$directory$git_branch$git_status$cmd_duration$line_break$character";

      character = {
        success_symbol = "[❯](purple)";
        error_symbol = "[❯](red)";
      };

      cmd_duration.format = "[$duration]($style) ";
    };
  };

  # These are out-of-store links. Editing the files in the repository
  # immediately changes the live configurations.

  home.file.".config/wezterm".source =
    config.lib.file.mkOutOfStoreSymlink
      "${dotfiles}/home/.config/wezterm";

  home.file.".config/nvim".source =
    config.lib.file.mkOutOfStoreSymlink
      "${dotfiles}/home/.config/nvim";

  home.file.".config/herdr".source =
    config.lib.file.mkOutOfStoreSymlink
      "${dotfiles}/home/.config/herdr";

  home.file.".claude/settings.json".source =
    config.lib.file.mkOutOfStoreSymlink
      "${dotfiles}/home/.claude/settings.json";

  # Pi authentication and runtime state remain local. Only authored
  # configuration files, themes, and extensions are linked.

  home.file.".pi/agent/themes".source =
    config.lib.file.mkOutOfStoreSymlink
      "${dotfiles}/home/.pi/agent/themes";

  home.file.".pi/agent/extensions".source =
    config.lib.file.mkOutOfStoreSymlink
      "${dotfiles}/home/.pi/agent/extensions";

  home.file.".pi/agent/models.json".source =
    config.lib.file.mkOutOfStoreSymlink
      "${dotfiles}/home/.pi/agent/models.json";

  home.file.".pi/agent/settings.json".source =
    config.lib.file.mkOutOfStoreSymlink
      "${dotfiles}/home/.pi/agent/settings.json";
}
