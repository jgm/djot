VERSION=$(shell grep "version = \"" djot.lua | sed -e 's/.*"\([^"]*\).*"/\1/')
REVISION=1
ROCKSPEC=djot-$(VERSION)-$(REVISION).rockspec
MODULES=djot.lua djot/attributes.lua djot/inline.lua djot/block.lua djot/ast.lua djot/html.lua djot/filter.lua
SOURCES=$(MODULES) bin/main.lua
TESTSOURCES=test.lua pathological_tests.lua
BUNDLE=djot
VIMDIR?=~/.vim
TIMEOUT=perl -e 'alarm shift; exec @ARGV'
TEMPFILE := $(shell mktemp)

all: test doc/syntax.html doc/djot.1 doc/api/index.html

test: $(ROCKSPEC)
	luarocks test
.PHONY: test

testall: test pathological fuzz
.PHONY: testall

ci: testall install
	make -C clib
	make -C web oldplayground/djot.js
	pandoc --print-default-data-file MANUAL.txt > m.txt
	pandoc -t djot-writer.lua m.txt -o m.dj
	pandoc -f djot-reader.lua m.dj -o m.html
	rm m.dj m.html
.PHONY: ci

fuzz:
	LUA_PATH="./?.lua;$$LUA_PATH" $(TIMEOUT) 90 lua fuzz.lua 500000
.PHONY: fuzz

pathological:
	LUA_PATH="./?.lua;$$LUA_PATH" \
	$(TIMEOUT) 10 lua pathological_tests.lua
.PHONY: pathological

bench: bench-lua bench-luajit
.PHONY: bench

bench-lua: m.dj
	du -h m.dj
	LUA_PATH="./?.lua" hyperfine --warmup 2 "lua bin/main.lua m.dj"
	LUA_PATH="./?.lua" hyperfine --warmup 2 "lua bin/main.lua -m m.dj"
	LUA_PATH="./?.lua" hyperfine --warmup 2 "lua bin/main.lua -p m.dj"
.PHONY: bench-lua

bench-luajit: m.dj
	du -h m.dj
	LUA_PATH="./?.lua" hyperfine --warmup 2 "luajit bin/main.lua m.dj"
	LUA_PATH="./?.lua" hyperfine --warmup 2 "luajit bin/main.lua -m m.dj"
	LUA_PATH="./?.lua" hyperfine --warmup 2 "luajit bin/main.lua -p m.dj"
.PHONY: bench-luajit


m.dj:
	pandoc -t djot-writer.lua https://raw.githubusercontent.com/jgm/pandoc/2.18/MANUAL.txt -o m.dj

djot-reader.amalg.lua: djot-reader.lua $(MODULES)
	LUA_PATH="./?.lua;" amalg.lua djot djot.ast djot.block djot.filter djot.inline djot.attributes djot.html djot.json -s $< -o $@

djot-writer.amalg.lua: djot-writer.lua $(MODULES)
	LUA_PATH="./?.lua;" amalg.lua djot djot.ast djot.block djot.filter djot.inline djot.attributes djot.html djot.json -s $< -o $@

linecount:
	wc -l $(SOURCES)
.PHONY: linecount

check:
	luacheck $(SOURCES) $(TESTSOURCES)
.PHONY: check

doc/syntax.html: doc/syntax.md
	pandoc --lua-filter doc/code-examples.lua $< -t html -o $@ -s --css doc/syntax.css --self-contained --wrap=preserve --toc --section-divs -Vpagetitle="Djot syntax reference"

doc/djot.1: doc/djot.md
	pandoc \
	  --metadata title="DJOT(1)" \
	  --metadata author="" \
	  --variable footer="djot $(VERSION)" \
	  $< -s -o $@

# luarocks packaging

install: $(ROCKSPEC)
	luarocks make $(ROCKSPEC)
.PHONY: install

rock: $(ROCKSPEC)
	luarocks --local make $(ROCKSPEC)
.PHONY: rock

doc/api:
	-mkdir $@

doc/api/index.html: djot.lua djot/ast.lua djot/filter.lua doc/api
	ldoc .

vim:
	cp editors/vim/syntax/djot.vim $(VIMDIR)/syntax/
	cp editors/vim/ftdetect/djot.vim $(VIMDIR)/ftdetect/
.PHONY: vim

## start up nix env with lua 5.1
lua51:
	nix-shell --pure lua51.nix
	rm ~/.luarocks/default-lua-version.lua
.PHONY: lua51

## start up nix env with luajiit
luajit:
	nix-shell --pure luajit.nix
	rm ~/.luarocks/default-lua-version.lua
.PHONY: luajit

$(ROCKSPEC): rockspec.in
	sed -e "s/_VERSION/$(VERSION)/g; s/_REVISION/$(REVISION)/g" $< > $@

