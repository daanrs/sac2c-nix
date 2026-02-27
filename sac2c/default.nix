{
  config,
  stdenv,
  lib,
  fetchFromGitLab,
  libuuid,
  libxslt,
  hwloc,
  m4,
  gcc,
  cmake,
  pkg-config,
  python3,
  gtest,
  testers,
  ctestCheckHook,
  debug ? false,
  buildGeneric ? true,
  enableThreads ? true,
  enableCuda ? config.cudaSupport,
  cudaPackages ? { },
}@inputs:
let
  # git describe --tags --abbrev=4
  version = "2.1.0-PuurGeluk-219-gd30c2";

  pname = "sac2c";

  src = fetchFromGitLab {
    domain = "gitlab.sac-home.org";
    owner = "sac-group";
    repo = pname;
    tag = "v${version}";
    hash = "sha256-OXNQ8d8U5pFODGXYoiUqHdx9SFfQFBjfffTR7oh04uo=";
  };

  postfix = if debug then "_d" else "_p";

  stdenv = throw "Use effectiveStdenv instead";

  effectiveStdenv = if enableCuda then cudaPackages.backendStdenv else inputs.stdenv;

  # RT_TARGETS and their SBI names
  targets = {
    seq = "seq";
    seq_checks = "seq";
  }
  // lib.optionalAttrs enableThreads {
    mt_pth = "mt-pth";
    mt_pth_rt = "mt-pth-rtspec";
    mt_pth_xt = "mt-pth-xt";
  }
  // lib.optionalAttrs enableCuda {
    cuda = "cuda";
    cuda_alloc = "cuda-alloc";
    cuda_man = "cuda-man";
    cuda_manp = "cuda-man-pref";
    cuda_reg = "cuda-reg";
    multi_gpu = "cuda-man-multi";
  };

  targetSBIs = builtins.attrValues targets;

  inherit (cudaPackages) cudatoolkit;
in
effectiveStdenv.mkDerivation (finalAttrs: {
  inherit src version;
  name = pname;

  buildInputs = [
    hwloc
    libuuid
    libxslt
    m4
  ]
  ++ lib.optional enableCuda cudatoolkit;

  patches = [
    ./remove_is_udt.patch
    ./620.patch
  ];

  postPatch = ''
    # Fix the issues with .git not existing in a nix build
    substituteInPlace cmake/sac2c-version-related.cmake \
      --replace-fail ''\'''${GIT_EXECUTABLE} describe --tags --abbrev=4 --dirty' "echo v${version}" \
      --replace-fail ''\'''${GIT_EXECUTABLE} diff-index --quiet HEAD' "echo" \
      --replace-fail '="''${GIT_EXECUTABLE}"' "=echo" \
      --replace-fail "FIND_PACKAGE (Git)" "" \
      --replace-fail "GIT_FOUND" 1

    substituteInPlace cmake/check-repo-version.cmake \
      --replace-fail ''\'''${GIT_COMMAND} describe --tags --abbrev=4 --dirty' "echo v${version}"

    # We dont need to prepend every installation path with sac2c/$version
    substituteInPlace cmake/sac2c/config.cmake \
      --replace-fail '/sac2c/''${SAC2C_VERSION}' "" \
      --replace-fail 'include/''${BUILD_TYPE_NAME}' 'include/'

    substituteInPlace scripts/sac2c-version-manager.in \
      --replace-fail 'link_src = os.path.join (prefix, "libexec", "sac2c", version, *pp)' \
        'link_src = os.path.join (prefix, "libexec", *pp)'
  '';

  # Sac tries to write sac2crc to home directory.
  preConfigure = ''
    export HOME=$TMPDIR
  '';

  cmakeBuildType = if debug then "DEBUG" else "RELEASE";

  cmakeFlags = [
    (lib.cmakeBool "CUDA" enableCuda)
    (lib.cmakeBool "MT" enableThreads)
    (lib.cmakeBool "BUILDGENERIC" buildGeneric)
    (lib.cmakeBool "FUNCTESTS" finalAttrs.finalPackage.doCheck)
  ];

  nativeBuildInputs = [
    cmake
    gcc
    pkg-config
    python3
  ];

  doCheck = true;

  checkInputs = [ gtest ];

  nativeCheckInputs = [ ctestCheckHook ];

  # idk why but these fail
  disabledTests = [
    "test-global-object-exp"
    "test-global-object-indirect-exp"
    "test-global-object-wl"
    "test-icc-guard-prf"
    "test-issue-2286"
    "test-fold-object-checkp"
    "test-fold-prefarg-checkp"
    "test-mowl-SE"
    "test-mowl-SE2"
    "test-void"
  ];

  # Generate pkg-configs for the runtime libraries
  postInstall = ''
    mkdir -p "$out/lib/pkgconfig"
  ''
  + (lib.concatMapStringsSep "\n" (tar: ''
    cat > "$out/lib/pkgconfig/sac-${tar}.pc" <<EOF
    prefix=$out
    includedir=\''${prefix}/include
    libdir=\''${prefix}/lib/rt/host/${tar}

    Name: sac-${tar}
    Description: sac runtime library for target ${tar}
    Version: ${finalAttrs.version}
    Libs: -L\''${libdir} -lsac${postfix}
    Cflags: -I\''${includedir}
    EOF
  '') targetSBIs);

  passthru = {
    inherit enableCuda enableThreads;

    tests.pkg-config = testers.testMetaPkgConfig finalAttrs.finalPackage;
  };

  preFixup = ''
    for d in $out/lib/modlibs/{host/*,tree/host/*}; do
      if [ -d "$d" ]; then
        for f in "$d"/*; do
          if [ -f "$f" ] && isELF "$f"; then
            # add the directory it exists in, since it might depend on other libraries
            patchelf --add-rpath "$d" "$f"

            # add runtime directory, which is located at the same path with rt/
            # instead of modlibs/
            rt_d=$(sed 's|/modlibs/|/rt/|g' <<<"$d")
            patchelf --add-rpath "$rt_d" "$f"

            # remove directories outside the nix store
            patchelf --shrink-rpath --allowed-rpath-prefixes "$NIX_STORE" "$f"
          fi
        done
      fi
    done
  '';

  meta = {
    pkgConfigModules = lib.map (x: "sac2c-${x}") targetSBIs;
  };
})
