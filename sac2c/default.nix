{
  config,
  stdenv,
  lib,
  ninja,
  fetchFromGitLab,
  libuuid,
  libxslt,
  hwloc,
  m4,
  gcc,
  cmake,
  pkg-config,
  python3,
  buildGeneric ? true,
  debug ? false,
  cudaSupport ? config.cudaSupport,
  cudaPackages ? { },
}@inputs:
let
  # git describe --tags --abbrev=4
  version = "v2.0.0-Tintigny";

  pname = "sac2c";

  src = fetchFromGitLab {
    domain = "gitlab.sac-home.org";
    owner = "sac-group";
    repo = "sac2c";
    rev = "4c765f73fca263ba88be1e746c659f318603b93d";
    hash = "sha256-cKOKF2H9N1/tLXW1I9Pt8+hvXq4hu7b5gYPMXGyzF18=";
  };

  stdenv = throw "Use effectiveStdenv instead";

  effectiveStdenv = if cudaSupport then cudaPackages.backendStdenv else inputs.stdenv;

  inherit (cudaPackages) cudatoolkit;
in
effectiveStdenv.mkDerivation (drv: {
  inherit src version;
  name = pname;

  buildInputs = [
    hwloc
    libuuid
    libxslt
    m4
  ]
  ++ lib.optionals cudaSupport [ cudatoolkit ];

  postPatch = ''
    substituteInPlace cmake/sac2c-version-related.cmake \
      --replace-fail ''\'''${GIT_EXECUTABLE} describe --tags --abbrev=4 --dirty' "echo ${version}" \
      --replace-fail ''\'''${GIT_EXECUTABLE} diff-index --quiet HEAD' "echo" \
      --replace-fail '="''${GIT_EXECUTABLE}"' "=echo" \
      --replace-fail "FIND_PACKAGE (Git)" "" \
      --replace-fail "GIT_FOUND" 1

    substituteInPlace cmake/check-repo-version.cmake \
      --replace-fail ''\'''${GIT_COMMAND} describe --tags --abbrev=4 --dirty' "echo ${version}"
  '';

  # Sac tries to write sac2crc to home directory.
  preConfigure = ''
    export HOME=$TMPDIR
  '';

  cmakeBuildType = if debug then "DEBUG" else "RELEASE";

  cmakeFlags = [
    (lib.cmakeBool "CUDA" cudaSupport)
    (lib.cmakeBool "BUILDGENERIC" buildGeneric)
  ];

  nativeBuildInputs = [
    cmake
    gcc
    pkg-config
    python3
  ];
})
