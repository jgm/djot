LUAVERSION=5.4.4
LUAURL=https://www.lua.org/ftp/lua-$(LUAVERSION).tar.gz
LUASRC=lua-$(LUAVERSION)/src
MODULES=$(patsubst %, ../%, djot/match.lua djot/attributes.lua djot/inline.lua djot/block.lua djot/ast.lua djot/emoji.lua djot/html.lua djot/filter.lua djot/json.lua djot.lua)
LUAOBJS=$(patsubst %,$(LUASRC)/%.o,lapi lgc lstate lauxlib linit lstring lbaselib liolib lstrlib lcode llex ltable lcorolib lmathlib ltablib lctype lmem ltm ldblib loadlib luac ldebug lobject lundump ldo lopcodes lutf8lib ldump loslib lvm lfunc lparser lzio)
LUASRCS=$(patsubst %.o,%.c,$(LUAOBJS))
CFLAGS= -O2 -Wall -Wextra -DLUA_COMPAT_5_3

test: djot tests
	./tests
.PHONY: test

tests: tests.c libdjot.a lua.h luaconf.h
	$(CC) $(CFLAGS) -I . -o $@  tests.c libdjot.a

djot: main.c libdjot.a djot_main.inc
	$(CC) $(CFLAGS) -I . -I $(LUASRC) -o $@ $< libdjot.a

$(LUASRC):
	curl $(LUAURL) | tar xv lua-$(LUAVERSION)/src

$(LUASRC)/%: $(LUASRC)

$(LUASRCS): $(LUASRC)

%.h: $(LUASRC)/%.h
	cp $< $@

$(LUASRC)/%.o: $(LUASRC)/%.c
	$(CC) $(CFLAGS) -c -I $(LUASRC) -o $@ $<

libdjot.a: djot.o $(LUAOBJS)
	ar -rc $@ $^

djot.o: djot.c djot_combined.inc $(LUASRC)
	$(CC) $(CFLAGS) -c -I . -I $(LUASRC) $<

djot_combined.lua: $(MODULES)
	lua combine.lua $^ > $@

djot_combined.inc: djot_combined.lua
	(cat $< && printf "\0") | xxd -i -n djot_combined_lua > $@

djot_main.inc: ../bin/main.lua
	(cat $< && printf "\0") | xxd -i -n djot_main_lua > $@

wasm: djot.js
.PHONY: wasm

# This also creates djot.wasm
djot.js: djot.c djot.h djot_combined.inc $(LUAOBJS)
	emcc -g0 -sALLOW_MEMORY_GROWTH -Oz -sFILESYSTEM=0 -s 'EXPORTED_RUNTIME_METHODS=["cwrap"]' -s 'EXPORTED_FUNCTIONS=["_djot_open", "_djot_report_error", "_djot_close", "_djot_parse", "_djot_render_ast", "_djot_render_matches", "_djot_render_html"]'  -I $(LUASRC) $(LUASRCS) -o $@ $<

clean:
	rm -rf djot_combined.lua djot_combined.inc *.o test
distclean: clean
	-rm -rf libdjot.a lua.h luaconf.h $(LUASRC) djot.js djot.wasm
.PHONY: clean
