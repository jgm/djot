{ pkgs ? import <nixpkgs> {} }:
let
  myLua = pkgs.luajit;
  myLuaWithPackages = myLua.withPackages(ps: with ps; [
      luaposix
  ]);
in
pkgs.mkShell {
  packages = [ pkgs.hyperfine pkgs.perl pkgs.luarocks myLuaWithPackages
  ];
  shellHook = ''
    luarocks config lua_version 5.1
    '';
}
