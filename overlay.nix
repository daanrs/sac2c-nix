final: prev:
let
  wrap-sac2c =
    prevSac2c: package:
    prev.writeShellScriptBin "sac2c" ''
      exec ${prevSac2c}/bin/sac2c -L "${package}/lib" -T "${package}/lib" "$@"
    '';
in
{
  inherit wrap-sac2c;

  sac2c = prev.callPackage ./sac2c { };

  sac2c-stdlib = prev.callPackage ./sac2c-stdlib { };

  sac2c-with-stdlib = wrap-sac2c final.sac2c final.sac2c-stdlib;
}
