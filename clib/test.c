#include <stdio.h>
#include <string.h>
#include "djot.h"

int main (void) {
  lua_State *L = djot_open();
  if (L == NULL) return -1;
  printf("%s", djot_to_json_ast(L, "hi *there*\n"));
  djot_close(L);
  return 0;
}
