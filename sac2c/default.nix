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
  version = "v2.1.0-PuurGeluk-205-gbed278c6c";

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
    repo = pname;
    tag = version;
    hash = "sha256-PVcw8UouAR2DFiyo3y23k37QmErti7aenwiyUemIptg=";
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

  preFixup = ''
    for d in $out/lib/sac2c/${version}/modlibs/{host/*,tree/host/*}; do
      if [ -d "$d" ]; then
        for f in "$d"/*; do
          if [ -f "$f" ] && isELF "$f"; then
            # add the directory it exists in, since it might depend on other libraries
            patchelf --add-rpath "$d" "$f"

            # # this is not specified as needed but I think the sac2c compiler manages it?
            # if [[ "$(basename "$f")" == "libsacprelude_pMod.so" ]]; then
            #   patchelf --add-needed "libsac_p.so" "$f"
            # fi

            # add runtime directory
            rt_d=$(sed 's|/modlibs/|/rt/|g' <<<"$d")
            patchelf --add-rpath "$rt_d" "$f"

            # remove directories outside the nix store
            patchelf --shrink-rpath --allowed-rpath-prefixes "$NIX_STORE" "$f"

            chmod +x "$f"
          fi
        done
      fi
    done
  '';
})
