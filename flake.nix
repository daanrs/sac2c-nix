{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";

    flake-parts.url = "github:hercules-ci/flake-parts";

    git-hooks-nix = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
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
        let
          sac2c = pkgs.callPackage ./sac2c { };

          sac2c-stdlib = pkgs.callPackage ./sac2c-stdlib {
            sac2c = sac2c;
          };

          wrap-sac2c =
            prevSac2c: package:
            pkgs.writeShellScriptBin "sac2c" ''
              exec ${prevSac2c}/bin/sac2c -L "${package}/lib" -T "${package}/lib" "$@"
            '';

          sac2c-with-stdlib = wrap-sac2c sac2c sac2c-stdlib;
        in

        {
          packages = {
            inherit
              sac2c
              sac2c-stdlib
              sac2c-with-stdlib
              ;
          };

          legacyPackages = {
            inherit
              # not a valid package, so we put it in legacy packages
              wrap-sac2c
              ;

          };

          devShells = {
            # internal devShell for formatting check
            pre-commit = config.pre-commit.devShell;

            sac2c = pkgs.mkShell (
              let
                sac2c-no-git = sac2c.override { mockGit = false; };
              in
              {
                inputsFrom = [ sac2c-no-git ];

                cmakeFlags = sac2c-no-git.cmakeFlags;
              }
            );

            sac2c-stdlib = pkgs.mkShell (
              let
                sac2c-stdlib-no-git = sac2c-stdlib.override { mockGit = false; };
              in
              {
                inputsFrom = [ sac2c-stdlib-no-git ];

                cmakeFlags = sac2c-stdlib-no-git.cmakeFlags;
              }
            );
          };

          pre-commit.settings.hooks.nixfmt.enable = true;
        };

      flake = {
        overlays.default = import ./overlay.nix;
      };
    };
}
