final: prev: {
  sac2c = prev.callPackage ./sac2c { };

  inherit (prev.callPackage ./sac2c-stdlib { })
    sac2c-stdlib-seq
    sac2c-stdlib-mt_pth
    sac2c-stdlib-cuda
    ;

  # sac2c-stdlib =

  sac2c-with-stdlib = prev.callPackage ./sac2c-with-stdlib { };
}
