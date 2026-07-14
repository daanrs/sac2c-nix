{ sacTarget }:

{
  config,
  stdenv,
  lib,
  fetchFromGitHub,
  ninja,
  gcc,
  flex,
  bison,
  sac2c,
  cmake,
  pkg-config,
  sacTargets ? [ sacTarget ],
  debug ? false,
  buildGeneric ? true,
  cudaPackages ? { },
}:
let
  # git describe --tags --abbrev=4
  version = "1.3-603-g9aff";

  pname = "sac2c-stdlib-${sacTarget}";

  src = fetchFromGitHub {
    fetchSubmodules = true;
    owner = "SacBase";
    repo = "Stdlib";
    # using a tag here causes an error because of the interaction with
    # fetchsubmodules. I'm probably just doing something incorrectly. See also
    # https://github.com/NixOS/nixpkgs/issues/26302
    rev = "9afffd46db51fd6877048f34fbd6c5a5de5eede5";
    hash = "sha256-eS12tKLuttmSmvmvPVsZdH0+E7QMQcYS3rGQtSUDeG4=";
  };

in
stdenv.mkDerivation (finalAttrs: {
  inherit src version;
  name = pname;

  postPatch = ''
    substituteInPlace cmake-common/generate-version-vars.cmake \
      --replace-fail ''\'''${GIT_EXECUTABLE} describe --tags --abbrev=4 --dirty' "echo ${version}" \
      --replace-fail "FIND_PACKAGE (Git REQUIRED)" "" \
      --replace-fail "DEFINED GIT_EXECUTABLE" 1

    substituteInPlace src/CMakeLists.txt \
      --replace-fail 'DESTINATION ''${_install_mod_dir}' \
        "DESTINATION $out/lib" \
      --replace-fail 'DESTINATION ''${_install_tree_dir}/tree' \
        "DESTINATION $out/lib/tree"
  '';

  # sac tries to write sac2c-stdlibrc to home directory
  preConfigure = ''
    export HOME=$TMPDIR
  '';

  preInstall = ''
    mkdir -p $out/lib/tree
  '';

  cmakeBuildType = if debug then "DEBUG" else "RELEASE";

  cmakeFlags = [
    (lib.cmakeFeature "SAC2C_EXEC" "${sac2c}/bin/sac2c")
    (lib.cmakeOptionType "list" "TARGETS" (lib.concatStringsSep ";" finalAttrs.finalPackage.sacTargets))
    (lib.cmakeBool "IS_RELEASE" (sac2c.cmakeBuildType == "RELEASE"))
    (lib.cmakeBool "BUILDGENERIC" buildGeneric)
  ];

  nativeBuildInputs = [
    bison
    cmake
    flex
    gcc
    ninja
    pkg-config
    sac2c
  ];

  doCheck = true;

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
