LUAPREFIX=$(shell brew --prefix)
LIBLUA=$(LUAPREFIX)/lib/liblua.a
LUAHEADERS=$(LUAPREFIX)/include/lua
MODULES=$(patsubst %, ../%, djot/match.lua djot/attributes.lua djot/inline.lua djot/block.lua djot/ast.lua djot/emoji.lua djot/html.lua djot/filter.lua djot/json.lua djot.lua)
LUAOBJFILES=$(shell ar -t $(LIBLUA) | tail +2)
LUAVERSION=5.4.4
LUAURL=https://www.lua.org/ftp/lua-$(LUAVERSION).tar.gz
LUADIR=lua-$(LUAVERSION)

test: tests
	./tests
.PHONY: test

tests: tests.c libdjot.a
	$(CC) -I $(LUAHEADERS) -o $@ $^

lua.h:
	cp $(LUAHEADERS)/$@ .

libdjot.a: djot.o $(LIBLUA)
	UNPACKDIR=`mktemp -d djot-archive.XXXX` || exit 1 && \
	trap 'rm -rf -- "$$UNPACKDIR"' EXIT && \
	cd $$UNPACKDIR && \
	cp ../$< . && \
	ar -x $(LIBLUA)  && \
	ar -rc $@ $< $(LUAOBJFILES) && \
	cd .. && \
	cp $$UNPACKDIR/$@ .

djot.o: djot.c djot_combined.inc
	$(CC) -c -I $(LUAHEADERS) $<

djot_combined.lua: $(MODULES)
	lua combine.lua $^ > $@

djot_combined.inc: djot_combined.lua
	(cat $< && printf "\0") | xxd -i -n djot_combined_lua > $@

$(LUADIR):
	curl $(LUAURL) | tar xv
	rm $(LUADIR)/src/lua.c # avoid duplicate main

wasm: djot.js
.PHONY: wasm

# This also creates djot.wasm
djot.js: djot.c djot.h djot_combined.inc $(LUADIR)
	emcc -g0 -sALLOW_MEMORY_GROWTH -Oz -sFILESYSTEM=0 -s 'EXPORTED_RUNTIME_METHODS=["cwrap"]' -s 'EXPORTED_FUNCTIONS=["_djot_open", "_djot_report_error", "_djot_close", "_djot_parse", "_djot_render_ast", "_djot_render_matches", "_djot_render_html"]'  -I $(LUADIR)/src $(LUADIR)/src/*.c -o $@ $<

clean:
	rm -rf djot_combined.lua djot_combined.inc *.o test
distclean: clean
	-rm -rf libdjot.a lua.h $(LUADIR) djot.js djot.wasm
.PHONY: clean
