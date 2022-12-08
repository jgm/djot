#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>
#include "djot.h"

int failed = 0;
int num = 0;
int result;

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
  exit(1);
}

int main (void) {
  char *out;
  int ok;

  /* Do this once, before any use of the djot library */
  lua_State *L = djot_open();
  if (!L) {
    fprintf(stderr, "djot_open returned NULL.\n");
    exit(1);
  }

  out = djot_parse_and_render_events(L, "hi *there*\n");
  if (!out) error(L);
  asserteq(out,
"[[\"+para\",1,1]\n\
,[\"str\",1,3]\n\
,[\"+strong\",4,4]\n\
,[\"str\",5,9]\n\
,[\"-strong\",10,10]\n\
,[\"-para\",11,11]\n\
]\n");

  ok = djot_parse(L, "hi *there*\n", true);
  if (!ok) error(L);
  out = djot_render_html(L);
  if (!out) error(L);
  asserteq(out,
"<p data-startpos=\"1:1:1\" data-endpos=\"1:11:11\">hi <strong data-startpos=\"1:4:4\" data-endpos=\"1:10:10\">there</strong></p>\n");

  out = djot_render_ast_json(L);
  if (!out) error(L);
  asserteq(out,
"{\"tag\":\"doc\",\"children\":[{\"tag\":\"para\",\"pos\":[\"1:1:1\",\"1:11:11\"],\"children\":[{\"tag\":\"str\",\"text\":\"hi \",\"pos\":[\"1:1:1\",\"1:3:3\"]},{\"tag\":\"strong\",\"pos\":[\"1:4:4\",\"1:10:10\"],\"children\":[{\"tag\":\"str\",\"text\":\"there\",\"pos\":[\"1:5:5\",\"1:9:9\"]}]}]}],\"references\":[],\"footnotes\":[]}\n");

  char *capsfilter = "return {\n\
str = function(e)\n\
   e.text = e.text:upper()\n\
end\n\
}\n";

  result = djot_apply_filter(L, capsfilter);
  if (!result) {
    error(L);
  } else {
    out = djot_render_html(L);
    if (!out) error(L);
    asserteq(out,
"<p data-startpos=\"1:1:1\" data-endpos=\"1:11:11\">HI <strong data-startpos=\"1:4:4\" data-endpos=\"1:10:10\">THERE</strong></p>\n");
  }

  /* When you're finished, close the djot library */
  djot_close(L);

  if (failed) {
    printf("%d tests failed.\n", failed);
  } else {
    printf("All good.\n");
  }
  return failed;
}
