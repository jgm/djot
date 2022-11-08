LIBLUA=/opt/homebrew/lib/liblua.a
LUAHEADERS=/opt/homebrew/include/lua
MODULES=$(patsubst %, ../%, djot/match.lua djot/attributes.lua djot/inline.lua djot/block.lua djot/ast.lua djot/emoji.lua djot/html.lua djot.lua)
LUAOBJFILES=$(shell ar -t /opt/homebrew/lib/liblua.a | tail +2)
LUAVERSION=5.4.4
LUAURL=https://www.lua.org/ftp/lua-$(LUAVERSION).tar.gz
LUADIR=lua-$(LUAVERSION)

test: tests
	./tests
.PHONY: test

tests: tests.c libdjot.a
	$(CC) -o $@ $^

lua.h:
	cp ${LUAHEADERS)/$@ .

luaconf.h:
	cp ${LUAHEADERS)/$@ .

libdjot.a: djot.o $(LIBLUA)
	ar -x $(LIBLUA) # extract object files
	ar -rc $@ $< $(LUAOBJFILES)

djot.o: djot.c djot_combined.inc lua.h luaconf.h
	$(CC) -c -I $(LUAHEADERS) $<

djot_combined.lua: $(MODULES)
	lua combine.lua > $@

djot_combined.inc: djot_combined.lua
	(cat $< && printf "\0") | xxd -i -n djot_combined_lua > $@

$(LUADIR):
	curl $(LUAURL) | tar xv
	rm $(LUADIR)/src/lua.c # avoid duplicate main

tests.js: djot.c djot.h djot_combined.inc $(LUADIR)
	emcc -Os -s 'EXPORTED_RUNTIME_METHODS=["cwrap"]' -s 'EXPORTED_FUNCTIONS=["_djot_open", "_djot_report_error", "_djot_close", "_djot_to_json_ast"]'  -I $(LUADIR)/src $(LUADIR)/src/*.c -o $@ $<

clean:
	rm -rf djot_combined.lua djot_combined.inc *.o test "__.SYMDEF SORTED" *.js *.wasm $(LUADIR)
distclean: clean
	-rm -f libdjot.a lua.h luaconf.h
.PHONY: clean
