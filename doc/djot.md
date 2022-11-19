# NAME

djot -- converts djot markup.

# SYNOPSIS

djot [options] [file..]

# DESCRIPTION

djot is a command-line parser for [djot markup](https://djot.net).
It can produce

- an HMTL document (default behavior)
- a stream of annotated tokens with byte offsets (`--matches`)
- an AST in either human-readable or JSON form (`--ast`).

# OPTIONS

`--matches, -m`

:   Show matches (annotated tokens with source positions).

`--ast`, `-a`

:   Produce and render an abstract syntax tree.

`--json`, `-j`

:   Use machine-readable JSON format when used with `--matches`
    or `--ast`.

`--sourcepos`, `-p`

:   Include source positions in the AST or HTML document.

`--filter` *FILE*, `-f` *FILE*

:   Run the filter defined in *FILE* on the AST between parsing
    and rendering. The `--filter` option may be used multiple
    times; filters will be applied in the order specified on the
    command line.  See [FILTERS][] below for a description of
    filters.

`--verbose`, `-v`

:   Verbose output, including warnings.

`--version`

:   Print the djot version.

`--help`, `-h`

:   Print usage information.

# FILTERS

TBD

# AUTHORS

John MacFarlane (<jgm@berkeley.edu>).

