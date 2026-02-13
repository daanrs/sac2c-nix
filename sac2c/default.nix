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
  writeShellApplication,
  pkg-config,
  python3,
  buildGeneric ? true,
  mockGit ? true,
  debug ? false,
  cudaSupport ? config.cudaSupport,
  cudaPackages ? { },
}@inputs:
let
  # git describe --tags --abbrev=4
  version = "v2.0";

  # Because the sac2c compilation sets the version using git we need to mock it
  # existing. This is also what our patch works around. When making a devshell
  # make sure to set mockGit as false, otherwise you will be very confused.
  mock-git = writeShellApplication {
    name = "git";
    text = ''
      echo "v${version}"
    '';
  };

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
  inherit src;
  name = pname;

  buildInputs = [
    hwloc
    libuuid
    libxslt
    m4
  ]
  ++ lib.optionals cudaSupport [ cudatoolkit ];

  # Sac tries to write sac2crc to home directory. Because we do not allow it do
  # so we will have to manage packages ourselves.
  preConfigure = ''
    export HOME=$TMPDIR
  '';

  patches = [
    ./unset_sac2c_is_dirty.patch
  ];

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
  ]
  ++ lib.optionals mockGit [ mock-git ];
})
