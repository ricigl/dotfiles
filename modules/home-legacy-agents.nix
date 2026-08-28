{ config, pkgs, unstablePkgs, ... }:

let
  dotfiles = "${config.home.homeDirectory}/.dotfiles";
in
{
  home.packages = (with pkgs; [
    claude-code
    codex
    wezterm
  ]) ++ [
    unstablePkgs.pi-coding-agent
  ];

  home.file.".config/wezterm".source =
    config.lib.file.mkOutOfStoreSymlink
      "${dotfiles}/home/.config/wezterm";

  home.file.".claude/settings.json".source =
    config.lib.file.mkOutOfStoreSymlink
      "${dotfiles}/home/.claude/settings.json";

  # Pi authentication/runtime state stays local. Only authored config is linked.
  home.file.".pi/agent/themes".source =
    config.lib.file.mkOutOfStoreSymlink
      "${dotfiles}/home/.pi/agent/themes";

  home.file.".pi/agent/models.json".source =
    config.lib.file.mkOutOfStoreSymlink
      "${dotfiles}/home/.pi/agent/models.json";

  home.file.".pi/agent/settings.json".source =
    config.lib.file.mkOutOfStoreSymlink
      "${dotfiles}/home/.pi/agent/settings.json";
}
