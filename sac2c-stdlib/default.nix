{ callPackage }:
{
  sac2c-stdlib-seq = callPackage (import ./generic.nix { sacTarget = "seq"; }) { };

  sac2c-stdlib-mt_pth = callPackage (import ./generic.nix { sacTarget = "mt_pth"; }) { };

  sac2c-stdlib-cuda = callPackage (import ./generic.nix { sacTarget = "cuda"; }) { };
}
