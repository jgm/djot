#include <stdio.h>
#include <string.h>
#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>
#include <djot.h>

#include "djot_combined.inc"
/* unsigned char djot_combined_luac[] */
/* size_t djot_combined_luac_len */

void djot_report_error(lua_State *L) {
  if(!L) {
    fprintf(stderr, "lua_State is NULL\n");
  } else {
    fprintf(stderr, "error: %s\n", lua_tostring(L, -1));
  }
}

lua_State *djot_open() {
  lua_State *L = luaL_newstate(); /* create Lua state */
  if (L == NULL) {
    return NULL;
  }
  luaL_openlibs(L);               /* opens Lua libraries */

  if (luaL_loadbuffer(L, (const char*)djot_combined_luac,
			  djot_combined_luac_len,
			  "djot_combined_luac") != LUA_OK) {
    djot_report_error(L);
    return NULL;
  }
  if (lua_pcall(L, 0, LUA_MULTRET, 0) != LUA_OK) {
    djot_report_error(L);
    return NULL;
  }

  lua_setglobal(L, "djot");

  return L;
}

void djot_close(lua_State *L) {
  lua_close(L);
}

/* Parse input (optionally including source positions) and return a
 * thread with the parsed document in the global 'doc'. The
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
  lua_getglobal(L, "doc");
  lua_getfield(L, -1, "render_html");
  lua_getglobal(L, "doc");
  lua_pushnil(L);
  if (lua_pcall(L, 2, 1, 0) != LUA_OK) {
    return NULL;
  }
  return (char *)lua_tostring(L, -1);
}

/* Render the AST of the document in the global 'doc'.
 * If 'as_json' is true, use JSON, otherwise, produce a compact
 * human-readable tree. NULL is returned on error. */
char *djot_render_ast(lua_State *L, bool as_json) {
  lua_getglobal(L, "doc");
  lua_getfield(L, -1, "render_ast");
  lua_getglobal(L, "doc");
  lua_pushnil(L);
  lua_pushboolean(L, as_json);
  if (lua_pcall(L, 3, 1, 0) != LUA_OK) {
    return NULL;
  }
  return (char *)lua_tostring(L, -1);
}

/* Tokenize input and render the matches.
 * If 'as_json' is true, use JSON, otherwise, produce a compact
 * human-readable tree. NULL is returned on error. */
char *djot_render_matches(lua_State *L, char *input, bool as_json) {
  lua_getglobal(L, "djot");
  lua_getfield(L, -1, "render_matches");
  lua_pushstring(L, input);
  lua_pushnil(L);
  lua_pushboolean(L, as_json);
  if (lua_pcall(L, 3, 1, 0) != LUA_OK) {
    return NULL;
  }
  return (char *)lua_tostring(L, -1);
}

