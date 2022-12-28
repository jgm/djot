CLIB=../clib
PLAYGROUND=oldplayground

all: djot.1.html
.PHONY: all

djot.1.html: ../doc/djot.md
	pandoc $< -s -o $@

# also creates djot.wasm
$(PLAYGROUND)/djot.js:
	make -C $(CLIB) wasm
	cp $(CLIB)/djot.js $(PLAYGROUND)/
	cp $(CLIB)/djot.wasm $(PLAYGROUND)/

server:
	cd playground && python3 -m http.server
.PHONY: server

upload:
	rsync -a --delete index.html djot.1.html website:djot.net/
.PHONY: upload

clean:
	rm -rf $(PLAYGROUND)/djot.js $(PLAYGROUND)/djot.wasm
.PHONY: clean
