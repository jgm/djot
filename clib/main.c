#include "djot.h"
#include <stdio.h>
#include <string.h>
#include <assert.h>
#include "lauxlib.h"

#include "djot_main.inc"
/* unsigned char djot_main_lua[], unsigned int djot_main_lua_len */

int main(int argc, char* argv[]) {
  int status;
  /* Do this once, before any use of the djot library */
  lua_State *L = djot_open();
  if (!L) {
    fprintf(stderr, "djot_open returned NULL.\n");
    return -1;
  }

  // start array structure
  lua_newtable( L );

  for (int i=1; i<=argc; i++) {

    lua_pushnumber( L, i );
    lua_pushstring( L, argv[i] );
    lua_rawset( L, -3 );

  }

  lua_setglobal( L, "arg" );

  status = luaL_dostring(L, (char*)djot_main_lua);
  if (status != LUA_OK) {
	  djot_report_error(L);
  }

  djot_close(L);
  return 0;
}

