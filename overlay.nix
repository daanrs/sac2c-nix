final: prev: {
  sac2c = final.callPackage ./sac2c { };

  sac2c-stdlib = final.callPackage ./sac2c-stdlib { };

  sac2c-with-stdlib = final.wrap-sac2c final.sac2c final.sac2c-stdlib;

  wrap-sac2c =
    prevSac2c: package:
    final.writeShellScriptBin "sac2c" ''
      exec ${prevSac2c}/bin/sac2c -L "${package}/lib" -T "${package}/lib" "$@"
    '';
}
