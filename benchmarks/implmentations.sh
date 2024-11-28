#!/bin/sh

PANDOC_MANUAL=https://github.com/jgm/djot/files/11900633/pandoc-manual.txt
PANDOC_MANUAL_DJ=pandoc-manual.dj

wget --no-clobber --output-document=$PANDOC_MANUAL_DJ $PANDOC_MANUAL

hyperfine --warmup 20 --shell=none "djoths $PANDOC_MANUAL_DJ"
hyperfine --warmup 20 --shell=none "djot $PANDOC_MANUAL_DJ"
hyperfine --warmup 20 --shell=none "jotdown $PANDOC_MANUAL_DJ"
