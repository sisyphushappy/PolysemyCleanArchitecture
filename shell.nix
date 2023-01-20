{nixpkgs ? import <nixpkgs> { }, ghc ? nixpkgs.ghc}:

with nixpkgs;

haskell.lib.buildStackProject {
  name = "PolysemyCleanArchitecture";
  buildInputs = [
    zlib
    lzma
  ];
  inherit ghc;
}
