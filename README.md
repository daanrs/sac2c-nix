# Nix derivation for building and developing sac2c from source

Use this if you need:
* To build a version of sac2c with particular inputs or build flags. Such as the latest git commit, with a a patch, or with particular build flags.
* A nix dev shell to compile sac2c

Otherwise, using [sac-nix](https://github.com/cxandru/sac-nix) will probably be easier.

Keep in mind that building sac2c and the standard library from source takes a while.

## How to use
Either use the overlay exposed as `overlays.default`, or directly use the
`packages.sac2c` and/or `packages.sac2c-with-stdlib`.

For instance, since I need a particular version of cuda, I do the following:
```nix
let pkgs = import inputs.nixpkgs {
  localSystem.system = "x86_64-linux";
  config = {
    allowUnfree = true;
    cudaSupport = true;
    cudaVersion = 12.0;
    cudaCapabilities = [ "5.2" ];
  };

  overlays = [ inputs.sac2c-nix.overlays.default ];
};
in
  ...
```

See <https://gitlab.sac-home.org/daanrs/internship-code/-/blob/main/flake.nix>
for an example.
