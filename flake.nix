{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";

    flake-parts.url = "github:hercules-ci/flake-parts";

    flake-compat = {
      url = "github:NixOS/flake-compat";
      flake = false;
    };

    git-hooks-nix = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-compat.follows = "flake-compat";
    };
  };

  outputs =
    inputs@{
      self,
      flake-parts,
      ...
    }:
    let
      flakeModule = ./flake-module.nix;
    in

    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        inputs.git-hooks-nix.flakeModule
        flakeModule
      ];

      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      perSystem =
        {
          system,
          pkgs,
          config,
          inputs',
          lib,
          ...
        }:
        {
          _module.args.pkgs = import inputs.nixpkgs {
            localSystem = { inherit system; };

            overlays = [ self.overlays.default ];
          };

          # internal devShell for formatting check
          devShells.pre-commit = config.pre-commit.devShell;

          pre-commit.settings.hooks.nixfmt.enable = true;
        };

      flake = {
        overlays.default = import ./overlay.nix;

        flakeModule = flakeModule;
      };
    };
}
