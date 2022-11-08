LIBLUA=/opt/homebrew/lib/liblua.a
LUAHEADERS=/opt/homebrew/include/lua
MODULES=$(patsubst %, ../%, djot/match.lua djot/attributes.lua djot/inline.lua djot/block.lua djot/ast.lua djot/emoji.lua djot/html.lua djot.lua)

test: test.c djot_combined.inc
	$(CC) $< $(LIBLUA) -I $(LUAHEADERS) -o $@

djot_combined.lua: $(MODULES)
	lua combine.lua > $@

djot_combined.inc: djot_combined.lua
	(cat $< && printf "\0") | xxd -i -n djot_combined_lua > $@

clean:
	-rm djot_combined.lua djot_combined.inc test
.PHONY: clean
