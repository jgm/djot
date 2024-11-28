#!/bin/sh

PANDOC_MANUAL=https://github.com/jgm/djot/files/11900633/pandoc-manual.txt
PANDOC_MANUAL_DJ=pandoc-manual.dj

wget --no-clobber --output-document=$PANDOC_MANUAL_DJ $PANDOC_MANUAL

hyperfine --warmup 20 --shell=none --export-markdown implementations.md \
"$HOME/go/bin/godjot $PANDOC_MANUAL_DJ" \
"$HOME/.cabal/bin/djoths $PANDOC_MANUAL_DJ" \
"djot $PANDOC_MANUAL_DJ" \
"$HOME/.luarocks/bin/djot $PANDOC_MANUAL_DJ" \
"jotdown $PANDOC_MANUAL_DJ"
