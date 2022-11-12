#include <stdio.h>
#include <string.h>
#include <assert.h>
#include "djot.h"

int failed = 0;
int num = 0;

static void asserteq(char *actual, char *expected) {
  num = num + 1;
  if (strcmp(actual, expected) == 0) {
    printf("Test %4d PASSED\n", num);
  } else {
    printf("Test %4d FAILED\nExpected:\n%s\nGot:\n%s\n", num, expected, actual);
    failed = failed + 1;
  }
}

static int error(lua_State *L) {
  djot_report_error(L);
  return -1;
}

int main (void) {
  char *out;
  int ok;

  /* Do this once, before any use of the djot library */
  lua_State *L = djot_open();
  if (!L) {
    fprintf(stderr, "djot_open returned NULL.\n");
    return -1;
  }

  ok = djot_parse(L, "hi *there*\n", true);
  if (!ok) error(L);
  out = djot_render_html(L);
  if (!out) error(L);
  asserteq(out, "<p data-startpos=\"1:1:1\" data-endpos=\"2:0:11\">hi <strong data-startpos=\"1:4:4\" data-endpos=\"1:10:10\">there</strong></p>\n");

  /* Now use functions like djot_to_ast_json */
  out = djot_render_ast(L, true);
  if (!out) error(L);
  asserteq(out, "{\"tag\":\"doc\",\"children\":[{\"tag\":\"para\",\"pos\":[\"1:1:1\",\"2:0:11\"],\"children\":[{\"tag\":\"str\",\"text\":\"hi \",\"pos\":[\"1:1:1\",\"1:3:3\"]},{\"tag\":\"strong\",\"pos\":[\"1:4:4\",\"1:10:10\"],\"children\":[{\"tag\":\"str\",\"text\":\"there\",\"pos\":[\"1:5:5\",\"1:9:9\"]}]}]}],\"references\":[],\"footnotes\":[]}\n");

  /* When you're finished, close the djot library */
  djot_close(L);

  /* Check that the string returned is still available
   * after closing the lua state: */
  asserteq(out, "{\"tag\":\"doc\",\"children\":[{\"tag\":\"para\",\"pos\":[\"1:1:1\",\"2:0:11\"],\"children\":[{\"tag\":\"str\",\"text\":\"hi \",\"pos\":[\"1:1:1\",\"1:3:3\"]},{\"tag\":\"strong\",\"pos\":[\"1:4:4\",\"1:10:10\"],\"children\":[{\"tag\":\"str\",\"text\":\"there\",\"pos\":[\"1:5:5\",\"1:9:9\"]}]}]}],\"references\":[],\"footnotes\":[]}\n");

  if (failed) {
    printf("%d tests failed.\n", failed);
  } else {
    printf("All good.\n");
  }
  return failed;
}
