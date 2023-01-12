with import <nixpkgs> {};

stdenv.mkDerivation {
    name = "haskell-homework";
    buildInputs = [ gnumake entr pandoc texlive.combined.scheme-full plantuml pandoc-plantuml-filter ];
}
