{
  lib,
  flake-parts-lib,
  ...
}:
let
  inherit (lib)
    mkOption
    types
    ;
in
{
  options = {
    perSystem = flake-parts-lib.mkPerSystemOption (
      {
        config,
        options,
        pkgs,
        ...
      }@inputs:
      let
        cfg = config.sac2c;
        pkgs = cfg.pkgs;
      in
      {
        options.sac2c = {
          pkgs = mkOption {
            type = types.uniq (types.lazyAttrsOf (types.raw or types.unspecified));
            description = ''
              Nixpkgs to use
            '';
            default = inputs.pkgs;
            defaultText = lib.literalExpression "`pkgs` (module argument)";
          };

          packages.sac2c = mkOption {
            type = types.package;
            description = ''
              Nixpkgs to use
            '';
            default = pkgs.sac2c;
          };

          packages.sac2c-stdlib = mkOption {
            type = types.package;
            description = ''
              Nixpkgs to use
            '';
            default = pkgs.sac2c-stdlib;
          };

          packages.sac2c-with-stdlib = mkOption {
            type = types.package;
            description = ''
              Nixpkgs to use
            '';
            default = pkgs.sac2c-with-stdlib;
          };

          checks.sac2c = mkOption {
            type = types.package;
            description = ''
              sac2c to check
            '';
            default = cfg.packages.sac2c;
          };

          checks.sac2c-stdlib = mkOption {
            type = types.package;
            description = ''
              sac2c-stdlib to check
            '';
            default = cfg.packages.sac2c-stdlib.override { doCheck = true; };
          };

          devShells.sac2c = mkOption {
            type = types.package;
            description = ''
              sac2c to check
            '';
            default = pkgs.mkShell {
              inputsFrom = [ cfg.packages.sac2c ];
            };
          };

          devShells.sac2c-stdlib = mkOption {
            type = types.package;
            description = ''
              sac2c-stdlib to check
            '';
            default = pkgs.mkShell {
              inputsFrom = [ cfg.packages.sac2c-stdlib ];
            };
          };

          autoWire =
            let
              outputTypes = [
                "checks"
                "packages"
                "devShells"
              ];
            in
            mkOption {
              type = types.listOf (types.enum outputTypes);
              description = ''
                List of flake output types to automatically export top-level in the flake.
              '';
              default = outputTypes;
            };

        };
        config =
          let
            contains = k: lib.any (x: x == k);
          in
          {
            checks = lib.optionalAttrs (contains "checks" cfg.autoWire) cfg.checks;
            devShells = lib.optionalAttrs (contains "devShells" cfg.autoWire) cfg.devShells;
            packages = lib.optionalAttrs (contains "packages" cfg.autoWire) cfg.packages;
          };
      }
    );
  };
}
