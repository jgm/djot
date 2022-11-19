LUAVERSION=5.4.4
LUAURL=https://www.lua.org/ftp/lua-$(LUAVERSION).tar.gz
LUASRC=lua-src
LIBLUA=$(LUASRC)/liblua.a
LUAHEADERS=$(LUASRC)
# Or, for example, to use homebrew-installed luajit on macos:
# LIBLUA=$(shell brew --prefix)/lib/libluajit.a
# LUAHEADERS=$(shell brew --prefix)/include/luajit-2.1
MODULES=$(patsubst %, ../%, djot/match.lua djot/attributes.lua djot/inline.lua djot/block.lua djot/ast.lua djot/emoji.lua djot/html.lua djot/filter.lua djot/json.lua djot.lua)
LUASRCS=$(patsubst %,$(LUASRC)/%.c,lapi lgc lstate lauxlib linit lstring lbaselib liolib lstrlib lcode llex ltable lcorolib lmathlib ltablib lctype lmem ltm ldblib loadlib luac ldebug lobject lundump ldo lopcodes lutf8lib ldump loslib lvm lfunc lparser lzio)
CFLAGS= -std=c99 -O2 -Wall -DLUA_COMPAT_5_3 $(SYSCFLAGS) $(MYCFLAGS)
UNAME=$(shell uname)
ifeq ($(UNAME), Linux)
LDFLAGS=-static -lm $(SYSLDFLAGS) $(MYLDFLAGS)
else
LDFLAGS=$(SYSLDFLAGS) $(MYLDFLAGS)
endif

test: djot tests
	./tests
.PHONY: test

tests: tests.c djot.o $(LIBLUA)
	$(CC) $(CFLAGS) $^ -I . -I $(LUAHEADERS) -o $@ $(LDFLAGS)

djot: main.c djot.o $(LIBLUA) djot_main.inc
	$(CC) $(CFLAGS) $< djot.o $(LIBLUA) -I . -I $(LUAHEADERS) -o $@ $(LDFLAGS)

libdjot.a: djot.o
	ar -rc $@ $<

$(LUASRC)/liblua.a: $(LUASRC)
	make -C $(LUASRC) liblua.a

$(LUASRC):
	mkdir -p $(LUASRC)
	curl $(LUAURL) | tar xzv -C $(LUASRC) --strip-components=2 lua-$(LUAVERSION)/src

djot.o: djot.c djot_combined.inc $(LUASRC)
	$(CC) $(CFLAGS) -c -I . -I $(LUAHEADERS) $<

djot_combined.lua: $(MODULES)
	lua combine.lua $^ > $@

djot_combined.inc: djot_combined.lua
	echo "unsigned char djot_combined_lua[] = {" > $@
	(cat $< && printf "\0") | xxd -i >> $@
	echo "};" >> $@

djot_main.inc: ../bin/main.lua
	echo "unsigned char djot_main_lua[] = {" > $@
	(cat $< && printf "\0") | xxd -i >> $@
	echo "};" >> $@

wasm: djot.js
.PHONY: wasm

# This also creates djot.wasm
djot.js: djot.c djot_combined.inc $(LUAOBJS)
	emcc -g0 -sALLOW_MEMORY_GROWTH -Oz -sFILESYSTEM=0 -s 'EXPORTED_RUNTIME_METHODS=["cwrap"]' -s 'EXPORTED_FUNCTIONS=["_djot_open", "_djot_report_error", "_djot_close", "_djot_parse", "_djot_render_ast", "_djot_render_matches", "_djot_render_html"]'  -I $(LUASRC) -I . $(LUASRCS) -o $@ $<

clean:
	rm -rf djot_combined.lua djot_combined.inc *.o test
distclean: clean
	-rm -rf $(LUASRC) djot.js djot.wasm
.PHONY: clean
