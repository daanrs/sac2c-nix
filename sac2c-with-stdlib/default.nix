{
  sac2c,
  sac2c-stdlib,
  symlinkJoin,
  makeWrapper,
}:

symlinkJoin {
  name = "sac2c-with-stdlib";

  paths = [ sac2c ];

  buildInputs = [
    sac2c-stdlib
  ];

  nativeBuildInputs = [
    makeWrapper
  ];

  postBuild = ''
    wrapProgram $out/bin/sac2c \
      --add-flags "-L${sac2c-stdlib}/lib" \
      --add-flags "-T${sac2c-stdlib}/lib"
  '';

  inherit (sac2c) meta;
}
