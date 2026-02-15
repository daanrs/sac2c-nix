{
  config,
  stdenv,
  lib,
  fetchFromGitHub,
  gcc,
  flex,
  bison,
  sac2c,
  writeShellApplication,
  cmake,
  pkg-config,
  mockGit ? true,
  debug ? false,
  buildGeneric ? true,
  doCheck ? false,
  cudaSupport ? config.cudaSupport,
  cudaPackages ? { },
}@inputs:
let
  # git describe --tags --abbrev=4
  version = "1.3";

  # see mock-git in ../sac2c for explanation
  mock-git = writeShellApplication {
    name = "git";
    text = ''
      echo "v${version}"
    '';
  };

  pname = "sac2c-stdlib";

  src = fetchFromGitHub {
    fetchSubmodules = true;
    owner = "SacBase";
    repo = "Stdlib";
    # commit roughly the same time as the sac2c package v2
    rev = "3686b4fdab53a107d76a65727a54dc07e075e7cd";
    hash = "sha256-X9PlaxE2lTrATfDjKFiql7ol2+GNm/QCNu2QLp43VV0=";
  };

  stdenv = throw "Use effectiveStdenv instead";

  effectiveStdenv = if cudaSupport then cudaPackages.backendStdenv else inputs.stdenv;

  inherit (cudaPackages) cudatoolkit;
in
effectiveStdenv.mkDerivation (drv: {
  inherit src;
  name = pname;

  # sac tries to write sac2c-stdlibrc to home directory
  preConfigure = ''
    export HOME=$TMPDIR

    mkdir -p $out/lib/tree

    substituteInPlace src/CMakeLists.txt \
      --replace-fail 'DESTINATION ''${_install_mod_dir}' \
        "DESTINATION $out/lib" \
      --replace-fail 'DESTINATION ''${_install_tree_dir}/tree' \
        "DESTINATION $out/lib/tree"
  '';

  cmakeBuildType = if debug then "DEBUG" else "RELEASE";

  cmakeFlags = [
    (lib.cmakeFeature "SAC2C_EXEC" "${sac2c}/bin/sac2c")
    (lib.cmakeOptionType "list" "TARGETS" (
      lib.concatStringsSep ";" (
        [
          "mt_pth"
          "seq"
        ]
        ++ lib.optionals doCheck [ "seq_checks" ]
        ++ lib.optionals cudaSupport [ "cuda" ]
      )
    ))
    (lib.cmakeBool "IS_RELEASE" (sac2c.cmakeBuildType == "RELEASE"))
    (lib.cmakeBool "BUILDGENERIC" buildGeneric)
  ];

  buildInputs = lib.optionals cudaSupport [ cudatoolkit ];

  nativeBuildInputs = [
    bison
    cmake
    flex
    gcc
    pkg-config
    sac2c
  ]
  ++ lib.optionals mockGit [ mock-git ];

  preFixup = ''
    for d in $out/lib/{host/*,tree/host/*}; do
      if [ -d "$d" ]; then
        for f in "$d"/*; do
          if [ -f "$f" ] && isELF "$f"; then
            # add the directory it exists in, since it might depend on other libraries
            patchelf --add-rpath "$d" "$f"

            # remove directories outside the nix store
            patchelf --shrink-rpath --allowed-rpath-prefixes "$NIX_STORE" "$f"

            chmod +x "$f"
          fi
        done
      fi
    done
  '';
})
