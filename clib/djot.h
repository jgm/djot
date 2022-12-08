#ifndef DJOT_H
#define DJOT_H
#include <stdio.h>
#include <string.h>
#include <stdbool.h>
#include <lua.h>

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

/* Return string version of error on top of Lua stack.
* This should be run immediately if a function that is supposed to return
* a pointer returns NULL. */
const char *djot_get_error(lua_State *L);

/* Parse input (optionally including source positions) and add
 * a global 'doc' with the parsed AST. The
 * subordinate functions djot_render_html, djot_render_ast,
 * djot_render_matches, djot_apply_filter can then be used to manipulate
 * or render the content. Returns 1 on success, 0 on error. */
int djot_parse(lua_State *L, char *input, bool sourcepos);

/* Render the document in the global 'doc' as HTML, returning a string,
 * or NULL on error. */
char *djot_render_html(lua_State *L);

/* Render the AST of the document in the global 'doc' as JSON.
 * NULL is returned on error. */
char *djot_render_ast_json(lua_State *L);

/* Render the AST of the document in the global 'doc' as JSON.
 * NULL is returned on error. */
char *djot_render_ast_pretty(lua_State *L);

/* Tokenize input and render the matches.
 * If 'as_json' is true, use JSON, otherwise, produce a compact
 * human-readable tree. NULL is returned on error. */
char *djot_parse_and_render_events(lua_State *L, char *input);

/* Load a filter from a string and apply it to the AST in global 'doc'.
 * Return 1 on success, 0 on error. */
int djot_apply_filter(lua_State *L, char *filter);

#endif
