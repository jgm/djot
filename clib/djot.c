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

  if (luaL_dostring(L, "function djot_to_json_ast(s)\n"
                       "  local x = djot.parse(s)\n"
                       "  return djot.render_ast_json(x)\n"
                       "end") != LUA_OK) {
    printf("error: %s", lua_tostring(L, -1));
    return NULL;
  }

  return L;
}

void djot_close(lua_State *L) {
  lua_close(L);
}

char * djot_to_json_ast(lua_State *L, char *in) {
  char *out;
  lua_getglobal(L, "djot_to_json_ast");
  lua_pushstring(L, in);
  if (lua_pcall(L, 1, 1, 0) != LUA_OK) {
    return NULL;
  }
  out = (char *)lua_tostring(L, -1);
  if (out == NULL) {
    return NULL;
  }
  return out;
}
