{
  description = "Ubuntu WSL Home Manager environment for Orca and Prime";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    # Used only for packages that need a newer version than stable.
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager.url = "github:nix-community/home-manager/release-26.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    # Legacy fallback only; not loaded by the default Orca/Prime profile.
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

      specialArgs = {
        inherit user herdr unstablePkgs;
      };

      mkHome = modules:
        home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          extraSpecialArgs = specialArgs;
          inherit modules;
        };
    in
    {
      homeConfigurations."${user}@wsl" = mkHome [
        ./home.nix
        ./modules/home-base.nix
        ./modules/home-orca-prime.nix
      ];

      homeConfigurations."${user}@wsl-legacy" = mkHome [
        ./home.nix
        ./modules/home-base.nix
        ./modules/home-orca-prime.nix
        ./modules/home-legacy-agents.nix
      ];

      devShells.${system}.orca-prime = pkgs.mkShell {
        packages = with pkgs; [
          nodejs_22
          python3
          uv
          gh
          jq
          ripgrep
          gnumake
          gcc
          pkg-config
        ];

        PRIME_AGENT_TELEMETRY = "0";
        PI_SKIP_VERSION_CHECK = "1";
        LAVISH_AXI_TELEMETRY = "0";
        LAVISH_AXI_NO_OPEN = "1";
        LAVISH_AXI_HOST = "127.0.0.1";

        shellHook = ''
          export NPM_CONFIG_PREFIX="$HOME/.local/share/npm"
          export PATH="$NPM_CONFIG_PREFIX/bin:$PATH"
        '';
      };
    };
}
