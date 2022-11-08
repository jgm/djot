LIBLUA=/opt/homebrew/lib/liblua.a
LUAHEADERS=/opt/homebrew/include/lua
MODULES=$(patsubst %, ../%, djot/match.lua djot/attributes.lua djot/inline.lua djot/block.lua djot/ast.lua djot/emoji.lua djot/html.lua djot.lua)
LUAOBJFILES=$(shell ar -t /opt/homebrew/lib/liblua.a | tail +2)

test: test.c libdjot.a
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

clean:
	rm -rf djot_combined.lua djot_combined.inc *.o test "__.SYMDEF SORTED"
distclean: clean
	-rm -f libdjot.a lua.h luaconf.h
.PHONY: clean
