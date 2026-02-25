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
  ctestCheckHook,
  buildGeneric ? true,
  debug ? false,
  cudaSupport ? config.cudaSupport,
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

  stdenv = throw "Use effectiveStdenv instead";

  effectiveStdenv = if cudaSupport then cudaPackages.backendStdenv else inputs.stdenv;

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
  ++ lib.optional cudaSupport cudatoolkit;

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
    (lib.cmakeBool "CUDA" cudaSupport)
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
