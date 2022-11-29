CLIB=../clib
PLAYGROUND=playground

all: $(PLAYGROUND)/djot.js $(PLAYGROUND)/styles.css
.PHONY: all

# also creates djot.wasm
$(PLAYGROUND)/djot.js:
	make -C $(CLIB) wasm
	cp $(CLIB)/djot.js $(PLAYGROUND)/
	cp $(CLIB)/djot.wasm $(PLAYGROUND)/

server:
	cd playground && python3 -m http.server
.PHONY: server

upload:
	rsync -a --delete index.html playground website:djot.net/
.PHONY: upload

clean:
	rm -rf $(PLAYGROUND)/djot.js $(PLAYGROUND)/djot.wasm
.PHONY: clean
