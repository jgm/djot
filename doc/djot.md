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

```
return {
  str = function(e)
     e.text = e.text:upper()
   end
}
```

Save this as `caps.lua` use tell djot to use it using

```
djot --filter caps input.djot
```

Note that djot will search your LUA_PATH for the filter if
it is not found in the working directory, so you can in
principle install filters using luarocks.

Here's a filter that prints a list of all the URLs you
link to in a document.  This filter doesn't alter the
document at all; it just prints the list to stderr.

```
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

By default filters do a bottom-up traversal; that is, the
filter for a node is run after its children have been processed.
It is possible to do a top-down travel, though, and even
to run separate actions on entering a node (before processing the
children) and on exiting (after processing the children). To do
this, associate the node's tag with a table containing `enter` and/or
`exit` functions.  The following filter will capitalize text
that is nested inside emphasis, but not other text:

```
local capitalize = 0
return {
   emph = {
     enter = function(e)
       capitalize = capitalize + 1
     end,
     exit = function(e)
       capitalize = capitalize - 1
     end,
   },
   str = function(e)
     if capitalize > 0 then
       e.text = e.text:upper()
      end
   end
}
```

For a top-down traversal, you'd just use the `enter` functions.
If the tag is associated directly with a function, as in the
first example above, it is treated as an `exit' function.

It is possible to inhibit traversal into the children of a node,
by having the `enter` function return the value true (or any truish
value, say `"stop"`).  This can be used, for example, to prevent
the contents of a footnote from being processed:

```
return {
 footnote = {
   enter = function(e)
     return true
   end
  }
}
```

A single filter may return a table with multiple tables, which will be
applied sequentially.

# AUTHORS

John MacFarlane (<jgm@berkeley.edu>).

