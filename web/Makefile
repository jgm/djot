CLIB=../clib
PLAYGROUND=playground

all: $(PLAYGROUND)/djot.js $(PLAYGROUND)/styles.css
.PHONY: all

# also creates djot.wasm
$(PLAYGROUND)/djot.js: $(CLIB)/djot.c $(CLIB)/djot.h $(CLIB)/djot_combined.inc
	make -C $(CLIB) wasm
	cp $(CLIB)/djot.js $(PLAYGROUND)/
	cp $(CLIB)/djot.wasm $(PLAYGROUND)/

$(PLAYGROUND)/styles.css: $(PLAYGROUND)/index.html $(PLAYGROUND)/input.css
	tailwindcss --content $< --input $(PLAYGROUND)/input.css --minify > $@

server:
	cd playground && python3 -m http.server
.PHONY: server

upload:
	rsync -a --delete index.html playground website:djot.net/
.PHONY: upload

clean:
	rm -rf djot.js djot.wasm styles.css
.PHONY: clean
