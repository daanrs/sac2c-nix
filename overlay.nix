final: prev: {
  sac2c = prev.callPackage ./sac2c { };

  sac2c-stdlib = prev.callPackage ./sac2c-stdlib { };

  sac2c-with-stdlib = prev.callPackage ./sac2c-with-stdlib { };
}
