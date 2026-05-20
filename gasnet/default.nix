{
  stdenv,
  fetchFromGitHub,
  gcc,
  pkg-config,
  perl,
  gnum4,
  autoreconfHook,
  autoconf,
  automake,
  which,
  writeShellApplication,
}:
let
  version = "2025.8.1";

  pname = "gasnet";

  src = fetchFromGitHub {
    owner = "BerkeleyLab";
    repo = "gasnet";
    rev = "gex-${version}";
    hash = "sha256-Zs9zbgVXa4rq20CaKa25m+ZO7dn9RqnLFjI31pOpmR0=";
  };

  # it terminates on the $autofilter thing, which is some perl magic
  bootstrap = writeShellApplication {
    name = "bootstrap";
    text = builtins.readFile "${src}/Bootstrap";
    bashOptions = [ ];
    runtimeInputs = [
      which
      gnum4
      autoconf
      automake
      perl
    ];

    checkPhase = "";
  };
in
stdenv.mkDerivation (finalAttrs: {
  inherit src version;
  name = pname;

  patches = [
    ./rename-configure.patch
  ];

  postPatch = ''
    # bash ${src}/Bootstrap
  '';

  nativeBuildInputs = [
    autoreconfHook

    autoconf
    automake
    gcc
    pkg-config
    perl

    which
    gnum4
  ];
})
