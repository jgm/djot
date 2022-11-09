#ifndef DJOT_H
#define DJOT_H
#include <stdio.h>
#include <string.h>
#include <stdbool.h>
#include "lua.h"

/* Open a Lua virtual machine and load the djot code.
 * This should only be done once, before all use of djot functions.
 * The state can be closed with djot_close. */
lua_State *djot_open();

/* Close the Lua virtual machine opened by djot_open, freeing its
 * memory. */
void djot_close(lua_State *L);

/* Report the error on the top of the Lua stack. This should
 * be run immediately if a function that is supposed to return
 * a pointer returns NULL. */
void djot_report_error(lua_State *L);

/* Parse a string and return a C string containing a JSON formatted AST. */
char * djot_to_ast_json(lua_State *L, char *in, bool sourcepos);

/* Parse a string and return a prettyprinted AST. */
char * djot_to_ast_pretty(lua_State *L, char *in, bool sourcepos);

/* Parse a string and return a C string containing a JSON formatted array
 * of match objects. */
char * djot_to_matches_json(lua_State *L, char *in);

/* Parse a string and return a C string containing a human-readable list of
 * match objects. */
char * djot_to_matches_pretty(lua_State *L, char *in);

/* Parse a string and return a C string containing HTML. */
char * djot_to_html(lua_State *L, char *in, bool sourcepos);

#endif
