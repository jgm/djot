with import <nixpkgs> {};
stdenv.mkDerivation rec {
  name = "lua-env";
  buildInputs = [ lua luarocks ];
}
