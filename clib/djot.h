#ifndef DJOT_H
#define DJOT_H
#include <stdio.h>
#include <string.h>
#include "lua.h"

lua_State *djot_open();
void djot_close(lua_State *L);
char * djot_to_json_ast(lua_State *L, char *in);

#endif
