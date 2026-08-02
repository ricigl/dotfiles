{
  description = "Ubuntu WSL development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    home-manager.url = "github:nix-community/home-manager/release-26.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    herdr.url = "github:herdrdev/herdr/v0.7.5";
  };

  outputs = { nixpkgs, home-manager, herdr, ... }:
    let
      # bootstrap.sh rewrites this to your actual WSL username.
      user = "ricardo";
      system = "x86_64-linux";

      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
    in
    {
      homeConfigurations."${user}@wsl" =
        home-manager.lib.homeManagerConfiguration {
          inherit pkgs;

          extraSpecialArgs = {
            inherit user herdr;
          };

          modules = [
            ./home.nix
          ];
        };
    };
}

