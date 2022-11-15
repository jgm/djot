{ pkgs ? import <nixpkgs> {} }:
let
  myLua = pkgs.lua5_1;
  myLuaWithPackages = myLua.withPackages(ps: with ps; [
      busted
      luafilesystem
      compat53
      luautf8
  ]);
in
pkgs.mkShell {
  packages = [ pkgs.perl pkgs.luarocks myLuaWithPackages
  ];
  shellHook = ''
    luarocks config lua_version 5.1
    '';
}
