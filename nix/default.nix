# SPDX-License-Identifier: MIT
{ pkgs, coreSrc }:
let
  inherit (pkgs) lib;
  makeWheel =
    {
      name,
      version,
      payload,
      tag ? "py3-none-any",
      pure ? true,
      dependencies ? [ ],
      entryPoints ? { },
      summary ? "Prepared Python distribution",
    }:
    assert lib.assertMsg (
      builtins.match "[A-Za-z0-9][A-Za-z0-9_-]*" name != null
    ) "invalid wheel distribution name";
    assert lib.assertMsg (
      builtins.match "[A-Za-z0-9][A-Za-z0-9_.!+]*" version != null
    ) "invalid wheel version";
    assert lib.assertMsg (
      builtins.match "[A-Za-z0-9_.]+-[A-Za-z0-9_.]+-[A-Za-z0-9_.]+" tag != null
    ) "invalid wheel compatibility tag";
    assert lib.assertMsg (lib.all (x: !lib.hasInfix "\n" x && !lib.hasInfix "\r" x) (
      [ summary ] ++ dependencies ++ builtins.attrValues entryPoints
    )) "wheel metadata cannot contain newlines";
    assert lib.assertMsg (lib.all (x: builtins.match "[A-Za-z0-9_.-]+" x != null) (
      builtins.attrNames entryPoints
    )) "invalid entry point name";
    pkgs.runCommand "${name}-${version}-wheel" { nativeBuildInputs = [ pkgs.python3 ]; } ''
      mkdir -p $out
      python3 ${../src/wheel.py} ${payload} ${
        pkgs.writeText "wheel.json" (
          builtins.toJSON {
            inherit
              name
              version
              tag
              pure
              dependencies
              entryPoints
              summary
              ;
          }
        )
      } $out/${builtins.replaceStrings [ "-" ] [ "_" ] name}-${version}-${tag}.whl
    '';
in
{
  inherit makeWheel;
  package = pkgs.python3.withPackages (p: [ p.pip ]);
}
