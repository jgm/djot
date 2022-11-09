#include <stdio.h>
#include <string.h>
#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>
#include "djot.h"

#include "djot_combined.inc"
/* unsigned char djot_combined_lua[], unsigned int djot_combined_lua_len */

void djot_report_error(lua_State *L) {
  printf("error: %s", lua_tostring(L, -1));
}

lua_State *djot_open() {
  lua_State *L = luaL_newstate(); /* create Lua state */
  if (L == NULL) {
    return NULL;
  }
  luaL_openlibs(L);               /* opens Lua libraries */

  if (luaL_dostring(L, (const char*)djot_combined_lua) != LUA_OK) {
    return NULL;
  }

  lua_setglobal(L, "djot");

  return L;
}

void djot_close(lua_State *L) {
  lua_close(L);
}

char * djot_to_html(lua_State *L, char *in, bool sourcepos) {
  lua_getglobal(L, "djot");
  lua_getfield(L, -1, "djot_to_html");
  lua_pushstring(L, in);
  lua_pushboolean(L, sourcepos);
  if (lua_pcall(L, 2, 1, 0) != LUA_OK) {
    return NULL;
  }
  return (char *)lua_tostring(L, -1);
}

char * djot_to_matches_json(lua_State *L, char *in) {
  lua_getglobal(L, "djot");
  lua_getfield(L, -1, "djot_to_matches_json");
  lua_pushstring(L, in);
  if (lua_pcall(L, 1, 1, 0) != LUA_OK) {
    return NULL;
  }
  return (char *)lua_tostring(L, -1);
}

char * djot_to_ast_json(lua_State *L, char *in, bool sourcepos) {
  lua_getglobal(L, "djot");
  lua_getfield(L, -1, "djot_to_ast_json");
  lua_pushstring(L, in);
  lua_pushboolean(L, sourcepos);
  if (lua_pcall(L, 2, 1, 0) != LUA_OK) {
    return NULL;
  }
  return (char *)lua_tostring(L, -1);
}
