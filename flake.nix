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

  #inputs.jeezyvim.url = "github:LGUG2Z/JeezyVim";

  # https://unmovedcentre.com/posts/secrets-management/
  inputs.sops-nix.url = "github:mic92/sops-nix";
  inputs.sops-nix.inputs.nixpkgs.follows = "nixpkgs";

  # https://github.com/ruslanguns/nixos-wsl-starter/blob/master/flake.nix
  outputs = {
    self,
    nixpkgs,
    nixpkgs-unstable,
    nix-index-database,
    home-manager,
    nur,
    ...
  }@inputs: let
  
    config = {
      allowUnfree = true;
      permittedInsecurePackages = []; # add any insecure packages you absolutely need here
    };
      
    systems = [
      "x86_64-linux"
      #"x86_64-darwin"
      #"aarch64-linux"
    ];

    forAllSystems = nixpkgs.lib.getAttr systems;

    nixpkgsWithOverlays = system: import nixpkgs {
      inherit system config;

      overlays = [
        nur.overlay
        #jeezyvim.overlays.default

        (_final: prev: {
          unstable = import nixpkgs-unstable {
            inherit system config;
          };
        })
      ];
    };

    configurationDefaults = args: {
      home-manager.useGlobalPkgs = true;
      home-manager.useUserPackages = true;
      home-manager.backupFileExtension = "hm-backup";
      home-manager.extraSpecialArgs = args;
    };

    argDefaults = {
      inherit 
        #secrets
        inputs 
        self 
        nix-index-database; 
      channels = {
        inherit nixpkgs nixpkgs-unstable;
      };
    };

    mkNixosConfiguration = {
      system ? "x86_64-linux",
      hostname,
      username,
      winname,
      args ? {},
      modules,
    }: let
      specialArgs = argDefaults // { inherit hostname username winname; } // args;
    in
      nixpkgs.lib.nixosSystem {
        inherit system specialArgs;
        pkgs = nixpkgsWithOverlays system;
        modules =
          [
            (configurationDefaults specialArgs)
            home-manager.nixosModules.home-manager
          ]
          ++ modules;
      };
  in {
    formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.alejandra);

    nixosConfigurations.cradix = mkNixosConfiguration {
      hostname = "cradix";
      username = "paz";
      winname = "paz";
      modules = [
        inputs.nixos-wsl.nixosModules.wsl
        inputs.sops-nix.nixosModules.sops
        ./wsl.nix
      ];
    };
  };
}
