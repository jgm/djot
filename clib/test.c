#include <stdio.h>
#include <string.h>
#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>

#include "djot_combined.inc"
/* unsigned char djot_combined_lua[], unsigned int djot_combined_lua_len */

int main (void) {
  int status;
  lua_State *L = luaL_newstate(); /* create Lua state */
  luaL_openlibs(L);               /* opens Lua libraries */

  status = luaL_dostring(L, (const char*)djot_combined_lua);
  if (status != LUA_OK) {
        printf("error: %s", lua_tostring(L, -1));
        return -1;
  }

  lua_setglobal(L, "djot");
  status = luaL_dostring(L, "p=djot.Parser:new('hi'); p:parse(); print(p:render_ast());");
  if (status != LUA_OK) {
        printf("error: %s", lua_tostring(L, -1));
        return -1;
  }

  lua_close(L);
  return 0;
}
