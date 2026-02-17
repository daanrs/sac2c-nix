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
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        inputs.git-hooks-nix.flakeModule
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

          packages = {
            inherit (pkgs)
              sac2c
              sac2c-stdlib
              sac2c-with-stdlib
              ;
          };

          legacyPackages = {
            inherit (pkgs)
              # not a valid package, so we put it in legacy packages
              wrap-sac2c
              ;

          };

          # internal devShell for formatting check
          devShells.pre-commit = config.pre-commit.devShell;

          pre-commit.settings.hooks.nixfmt.enable = true;
        };

      flake = {
        overlays.default = import ./overlay.nix;
      };
    };
}
