# Idk how I really feel about this file.
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
              sac2c compiler
            '';
            default = pkgs.sac2c;
          };

          packages.sac2c-stdlib = mkOption {
            type = types.package;
            description = ''
              sac2c standard library
            '';
            default = pkgs.sac2c-stdlib;
          };

          packages.sac2c-with-stdlib = mkOption {
            type = types.package;
            description = ''
              sac2c package wrapped with stdlib
            '';
            default = pkgs.sac2c-with-stdlib;
          };

          devShells.sac2c = mkOption {
            type = types.package;
            description = ''
              sac2c devShell
            '';
            default = pkgs.mkShell {
              inputsFrom = [ cfg.packages.sac2c ];

              env = {
                # This ensures clangd can pickup on generated header files such
                # as config.h.in
                CMAKE_EXPORT_COMPILE_COMMANDS = true;

                # use Ninja by default
                CMAKE_GENERATOR = "Ninja";
              };

              packages = [ pkgs.gtest ];
            };
          };

          devShells.sac2c-stdlib = mkOption {
            type = types.package;
            description = ''
              sac2c-stdlib devShell
            '';
            default = pkgs.mkShell {
              inputsFrom = [ cfg.packages.sac2c-stdlib ];
            };
          };

          checks.packages = mkOption {
            type = types.attrsOf types.package;
            description = "";
            default = lib.mapAttrs' (n: lib.nameValuePair "package-${n}") cfg.packages;
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
            checks = lib.optionalAttrs (contains "checks" cfg.autoWire) cfg.checks.packages;
            devShells = lib.optionalAttrs (contains "devShells" cfg.autoWire) cfg.devShells;
            packages = lib.optionalAttrs (contains "packages" cfg.autoWire) cfg.packages;
          };
      }
    );
  };
}
