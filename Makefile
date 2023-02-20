VIMDIR?=~/.vim

all: doc/syntax.html

doc/syntax.html: doc/syntax.md doc/syntax.css doc/code-examples.lua
	pandoc --lua-filter doc/code-examples.lua $< -t html -o $@ -s --css doc/syntax.css --self-contained --wrap=preserve --toc --section-divs -Vpagetitle="Djot syntax reference"
