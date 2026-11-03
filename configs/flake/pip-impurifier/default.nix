# SPDX-License-Identifier: MIT
{ ... }:
{ lib, inputs, ... }:
{
  flake.lib = lib.mkForce {
    pip-impurifier =
      { pkgs }:
      import ../../../nix {
        inherit pkgs;
        coreSrc = inputs.impurifier;
      };
  };
  perSystem =
    { pkgs, ... }:
    let
      backend = import ../../../nix {
        inherit pkgs;
        coreSrc = inputs.impurifier;
      };
    in
    {
      packages.default = backend.package;
      checks = import ../../../tests { inherit pkgs backend; };
      formatter = pkgs.nixfmt-tree;
    };
}
