{
  description = "Ubuntu WSL development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    # Used only for packages that need a newer version than stable.
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager.url = "github:nix-community/home-manager/release-26.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    herdr.url = "github:herdrdev/herdr/v0.7.5";
  };

  outputs = {
    nixpkgs,
    nixpkgs-unstable,
    home-manager,
    herdr,
    ...
  }:
    let
      user = "ricardo";
      system = "x86_64-linux";

      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };

      unstablePkgs = import nixpkgs-unstable {
        inherit system;
        config.allowUnfree = true;
      };
    in
    {
      homeConfigurations."${user}@wsl" =
        home-manager.lib.homeManagerConfiguration {
          inherit pkgs;

          extraSpecialArgs = {
            inherit user herdr unstablePkgs;
          };

          modules = [
            ./home.nix
          ];
        };
    };
}
