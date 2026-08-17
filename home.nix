{ user, ... }:
{
  home.username = user;
  home.homeDirectory = "/home/${user}";

  # Do not routinely update this value. It controls Home Manager compatibility.
  home.stateVersion = "24.11";

  targets.genericLinux.enable = true;
  programs.home-manager.enable = true;
}
