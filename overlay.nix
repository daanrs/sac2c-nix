final: prev: {
  sac2c = prev.callPackage ./sac2c { };

  sac2c-stdlib = prev.callPackage ./sac2c-stdlib { };

  sac2c-with-stdlib = prev.symlinkJoin {
    name = "sac2c-with-stdlib";

    paths = [ final.sac2c ];

    buildInputs = [
      final.sac2c-stdlib
    ];

    nativeBuildInputs = [
      final.makeWrapper
    ];

    postBuild = ''
      wrapProgram $out/bin/alacritty \
        --add-flags "-L${final.sac2c-stdlib}/lib" \
        --add-flags "-T${final.sac2c-stdlib}/lib"
    '';
  };
}
