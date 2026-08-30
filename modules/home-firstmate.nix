{ pkgs, agentPackages, ... }:

{
  # Firstmate is installed as an upstream git checkout in ~/firstmate by scripts/install-home-agents.sh.
  # Home Manager manages only the host dependencies (Treehouse worktree provider and tmux)
  # required by Firstmate's Linux backend.
  home.packages = [
    agentPackages.treehouse
    pkgs.tmux
  ];
}
