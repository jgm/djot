#include <stdio.h>
#include <string.h>
#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>
#include "djot.h"

#include "djot_combined.inc"
/* unsigned char djot_combined_lua[], unsigned int djot_combined_lua_len */

lua_State *djot_open() {
  lua_State *L = luaL_newstate(); /* create Lua state */
  if (L == NULL) {
    printf("error: %s", lua_tostring(L, -1));
    return NULL;
  }
  luaL_openlibs(L);               /* opens Lua libraries */

  if (luaL_dostring(L, (const char*)djot_combined_lua) != LUA_OK) {
        printf("error: %s", lua_tostring(L, -1));
        return NULL;
  }

  lua_setglobal(L, "djot");

  if (luaL_dostring(L, "function djot_to_json_ast(s)\n"
                       "  p = djot.Parser:new(s)\n"
		       "  p:parse()\n"
		       "  return p:render_ast(nil, true)\n"
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
        printf("error: %s", lua_tostring(L, -1));
        return NULL;
  }
  out = (char *)lua_tostring(L, -1);
  if (out == NULL) {
        printf("error: %s", lua_tostring(L, -1));
        return NULL;
  }
  return out;
}
