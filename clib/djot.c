#include <stdio.h>
#include <string.h>
#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>
#include <djot.h>

#include "djot_combined.inc"
/* unsigned char djot_combined_lua[] */

void djot_report_error(lua_State *L) {
  if(!L) {
    fprintf(stderr, "lua_State is NULL\n");
  } else {
    fprintf(stderr, "error: %s\n", lua_tostring(L, -1));
  }
}

const char *djot_get_error(lua_State *L) {
  if(!L) {
    return "lua_State is NULL\n";
  } else {
    return lua_tostring(L, -1);
  }
}

lua_State *djot_open() {
  lua_State *L = luaL_newstate(); /* create Lua state */
  if (L == NULL) {
    return NULL;
  }
  luaL_openlibs(L);               /* opens Lua libraries */

  if (luaL_dostring(L, (const char*)djot_combined_lua) != LUA_OK) {
    djot_report_error(L);
    return NULL;
  }

  lua_setglobal(L, "djot");

  return L;
}

void djot_close(lua_State *L) {
  lua_close(L);
}

/* Parse input (optionally including source positions) and add
 * a global 'doc' with the parsed AST. The
 * subordinate functions djot_render_html, djot_render_ast,
 * djot_render_matches, djot_apply_filter can then be used to manipulate
 * or render the content. Returns 1 on success, 0 on error. */
int djot_parse(lua_State *L, char *input, bool sourcepos) {
  lua_getglobal(L, "djot");
  lua_getfield(L, -1, "parse");
  lua_pushstring(L, input);
  lua_pushboolean(L, sourcepos);
  if (lua_pcall(L, 2, 1, 0) != LUA_OK) {
    return 0;
  }
  lua_setglobal(L, "doc");
  return 1;
}

/* Render the document in the global 'doc' as HTML, returning a string,
 * or NULL on error. */
char *djot_render_html(lua_State *L) {
  lua_getglobal(L, "djot");
  lua_getfield(L, -1, "render_html");
  lua_getglobal(L, "doc");
  if (lua_pcall(L, 1, 1, 0) != LUA_OK) {
    return NULL;
  }
  return (char *)lua_tostring(L, -1);
}

/* Render the AST of the document in the global 'doc' as JSON.
 * NULL is returned on error. */
char *djot_render_ast_json(lua_State *L) {
  lua_getglobal(L, "djot");
  lua_getfield(L, -1, "render_ast_json");
  lua_getglobal(L, "doc");
  if (lua_pcall(L, 1, 1, 0) != LUA_OK) {
    return NULL;
  }
  return (char *)lua_tostring(L, -1);
}

/* Render the AST of the document in the global 'doc' as JSON.
 * NULL is returned on error. */
char *djot_render_ast_pretty(lua_State *L) {
  lua_getglobal(L, "djot");
  lua_getfield(L, -1, "render_ast_pretty");
  lua_getglobal(L, "doc");
  if (lua_pcall(L, 1, 1, 0) != LUA_OK) {
    return NULL;
  }
  return (char *)lua_tostring(L, -1);
}

/* Load a filter from a string and apply it to the AST in global 'doc'.
 * Return 1 on success, 0 on error. */
int djot_apply_filter(lua_State *L, char *filter) {
  lua_getglobal(L, "djot");
  lua_getfield(L, -1, "filter");
  lua_getfield(L, -1, "load_filter");
  lua_pushstring(L, filter);
  if (lua_pcall(L, 1, 1, 0) != LUA_OK) {
    return 0;
  }
  // Now we should have the loaded filter on top of stack, or nil and an error
  if lua_isnil(L, -2) {
    return 0;
  }
  // If we're here, top of stack should be the compiled filter
  lua_getglobal(L, "djot");
  lua_getfield(L, -1, "filter");
  lua_getfield(L, -1, "apply_filter");
  lua_getglobal(L, "doc");
  lua_pushvalue(L, -5); /* push the compiled filter to top of stack */
  if (lua_pcall(L, 2, 1, 0) != LUA_OK) {
    return 0;
  }
  return 1;
}

/* Parse input and render the events as a JSON array.
 * NULL is returned on error. */
char *djot_parse_and_render_events(lua_State *L, char *input) {
  lua_getglobal(L, "djot");
  lua_getfield(L, -1, "parse_and_render_events");
  lua_pushstring(L, input);
  if (lua_pcall(L, 1, 1, 0) != LUA_OK) {
    return NULL;
  }
  return (char *)lua_tostring(L, -1);
}

