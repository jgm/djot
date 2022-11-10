#include <stdio.h>
#include <string.h>
#include <assert.h>
#include "djot.h"

int failed = 0;
int num = 0;

static void asserteq(int actual, int expected) {
  num = num + 1;
  if (actual == expected) {
    printf("Test %4d PASSED\n", num);
  } else {
    printf("Test %4d FAILED\nExpected %d, got %d\n", num, expected, actual);
    failed = failed + 1;
  }
}

static int error(lua_State *L) {
  djot_report_error(L);
  return -1;
}

int main (void) {
  char *out;

  /* Do this once, before any use of the djot library */
  lua_State *L = djot_open();
  if (!L) error(L);

  /* Now use functions like djot_to_ast_json */
  out = djot_to_ast_json(L, "hi *there*\n", 0);
  if (!out) error(L);

  /* Note: we just compare lengths, because JSON rendering is
   * non-deterministic. */
  asserteq(strlen(out), strlen("{\"children\":[{\"children\":[{\"text\":\"hi \",\"tag\":\"str\"},{\"children\":[{\"text\":\"there\",\"tag\":\"str\"}],\"tag\":\"strong\"}],\"tag\":\"para\"}],\"tag\":\"doc\",\"references\":[],\"footnotes\":[]}\n"));

  /* When you're finished, close the djot library */
  djot_close(L);

  /* Check that the string returned is still available
   * after closing the lua state: */
  asserteq(strlen(out), strlen("{\"children\":[{\"children\":[{\"text\":\"hi \",\"tag\":\"str\"},{\"children\":[{\"text\":\"there\",\"tag\":\"str\"}],\"tag\":\"strong\"}],\"tag\":\"para\"}],\"tag\":\"doc\",\"references\":[],\"footnotes\":[]}\n"));

  if (failed) {
    printf("%d tests failed.\n", failed);
  } else {
    printf("All good.\n");
  }
  return failed;
}
