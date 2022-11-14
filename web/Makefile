CLIB=../clib

all: djot.js styles.css
.PHONY: all

# also creates djot.wasm
djot.js: $(CLIB)/djot.c $(CLIB)/djot.h $(CLIB)/djot_combined.inc
	make -C $(CLIB) wasm

styles.css: index.html input.css
	tailwindcss --content $< --input input.css --minify > $@

server:
	python3 -m http.server
.PHONY: server

clean:
	rm -rf djot.js djot.wasm styles.css
.PHONY: clean
