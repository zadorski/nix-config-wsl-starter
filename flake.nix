{
  description = "NixOS WSL configuration";

  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-24.05";
  inputs.nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";

  inputs.home-manager.url = "github:nix-community/home-manager/release-24.05";
  inputs.home-manager.inputs.nixpkgs.follows = "nixpkgs";

  inputs.nur.url = "github:nix-community/NUR";

  inputs.nixos-wsl.url = "github:nix-community/NixOS-WSL";
  inputs.nixos-wsl.inputs.nixpkgs.follows = "nixpkgs";

  inputs.nix-index-database.url = "github:Mic92/nix-index-database";
  inputs.nix-index-database.inputs.nixpkgs.follows = "nixpkgs";

  inputs.jeezyvim.url = "github:LGUG2Z/JeezyVim";

  # https://unmovedcentre.com/posts/secrets-management/
  inputs.sops-nix.url = "github:mic92/sops-nix";
  inputs.sops-nix.inputs.nixpkgs.follows = "nixpkgs";

  outputs = inputs:
    with inputs; let
      secrets = builtins.fromJSON (builtins.readFile "${self}/secrets.json");

      nixpkgsWithOverlays = system: (import nixpkgs rec {
        inherit system;

        config = {
          allowUnfree = true;
          permittedInsecurePackages = []; # add any insecure packages you absolutely need here
        };

        overlays = [
          nur.overlay
          jeezyvim.overlays.default

          (_final: prev: {
            unstable = import nixpkgs-unstable {
              inherit (prev) system;
              inherit config;
            };
          })
        ];
      });

      configurationDefaults = args: {
        home-manager.useGlobalPkgs = true;
        home-manager.useUserPackages = true;
        home-manager.backupFileExtension = "hm-backup";
        home-manager.extraSpecialArgs = args;
      };

      argDefaults = {
        inherit secrets inputs self nix-index-database;
        channels = {
          inherit nixpkgs nixpkgs-unstable;
        };
      };

      mkNixosConfiguration = {
        system ? "x86_64-linux",
        hostname,
        username,
        args ? {},
        modules,
      }: let
        specialArgs = argDefaults // {inherit hostname username;} // args;
      in
        nixpkgs.lib.nixosSystem {
          inherit system specialArgs;
          pkgs = nixpkgsWithOverlays system;
          modules =
            [
              (configurationDefaults specialArgs)
              home-manager.nixosModules.home-manager
              {
                home-manager.sharedModules = [
                  sops-nix.homeManagerModules.sops
                ];
              }
            ]
            ++ modules;
        };
    in {
      formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.alejandra;

      nixosConfigurations.crobex = mkNixosConfiguration {
        hostname = "crobex";
        username = "paz";
        modules = [
          nixos-wsl.nixosModules.wsl
          sops-nix.nixosModules.sops # check home-manager.sharedModules for sops-nix in HM (ref:: https://github.com/nyxkrage/sanctureplicum/blob/main/flake.nix)
          ./wsl.nix
        ];
      };

      nixosConfigurations.crodax = mkNixosConfiguration {
        hostname = "crodax";
        username = "paz";
        modules = [
          nixos-wsl.nixosModules.wsl
          sops-nix.nixosModules.sops
          ./wsl.nix
        ];
      };
    };
}
