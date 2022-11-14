#!/bin/sh
LUA_PATH="./?.lua;$LUA_PATH" lua bin/main.lua "$@"
