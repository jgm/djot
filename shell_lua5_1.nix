with import <nixpkgs> {};
stdenv.mkDerivation rec {
  name = "lua-env";
  buildInputs = [ lua5_1 luarocks ];
  shellHook = ''
    export LUA_PATH="./?.lua;$HOME/.luarocks/share/lua/5.1/?.lua;$HOME/.luarocks/share/lua/5.1/?/init.lua;$HOME/.luarocks/lib/lua/5.1/?.lua;$HOME/.luarocks/lib/lua/5.1/?/init.lua;./?.lua"
    export LUA_CPATH="/Users/jgm/.luarocks/lib/lua/5.1/?.so;/Users/jgm/.luarocks/lib/lua/5.1/loadall.so"
    '';
}
