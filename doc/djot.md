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

Filters are small Lua programs that modify the parsed document
prior to rendering.  Here is an example of a filter that
capitalizes all the content text in a document:

```lua
return {
  str = function(e)
     e.text = e.text:upper()
   end
}
```

Save this as `caps.lua` use tell djot to use it using

   djot --filter caps input.djot

Note that djot will search your LUA_PATH for the filter if
it is not found in the working directory, so you can in
principle install filters using luarocks.

Here's a filter that prints a list of all the URLs you
link to in a document.  This filter doesn't alter the
document at all; it just prints the list to stderr.

```lua
return {
  link = function(el)
    io.stderr:write(el.destination .. "\n")
  end
}
```

A filter walks the document's abstract syntax tree, applying
functions to like-tagged nodes, so you will want to get familiar
with how djot's AST is designed. The easiest way to do this is
to use `djot --ast`.

Normally a "bottom-up" traversal is done, with child nodes being
modified before their parents.  If you want a "top-down"
traversal instead, add `traversal = "topdown"` to your filter:

return {
  traversal = "topdown",
  str = function(e)
     e.text = e.text:upper()
   end
}

TODO check.



# AUTHORS

John MacFarlane (<jgm@berkeley.edu>).

