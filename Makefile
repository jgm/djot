VIMDIR?=~/.vim

all: doc/syntax.html

# luarocks install --lua-version=5.4 djot

doc/syntax.html: doc/syntax.md
	pandoc --lua-filter doc/code-examples.lua $< -t html -o $@ -s --css doc/syntax.css --embed-resources --wrap=preserve --toc --section-divs -Vpagetitle="Djot syntax reference"

