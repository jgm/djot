# Djot

Djot is a light markup syntax. It derives most of its features
from [commonmark](https://spec.commonmark.org), but it fixes
a few things that made commonmark's syntax complex and difficult
to parse efficiently. It is also much fuller-featured than
commonmark, with support for definition lists, footnotes,
tables, several new kinds of inline formatting (insert, delete,
highlight, superscript, subscript), math, smart punctuation,
attributes that can be applied to any element, and generic
containers for block-level, inline-level, and raw content.

The project began as an attempt to implement some of the
ideas I suggested in my essay [Beyond Markdown](https://johnmacfarlane.net/beyond-markdown.html).
I wanted to keep the good parts of Markdown, while fixing
the pain points. I also wanted to extend the syntax to make
djot a more flexible tool for writing. (See
[Rationale](#rationale), below.)

This repository contains a reference implementation, written
in Lua, and a [syntax
description](https://htmlpreview.github.io/?https://github.com/jgm/djot/blob/master/doc/syntax.html). Despite being
written in an interpreted language, the reference implementation
is very fast (converting a 260K test document in 141 ms on an M1 mac
using the standard `lua` interpreter). It can produce
an AST, rendered HTML, or a stream of match tokens that identify
elements by source position, which could be used for syntax
highlighting or a linting tool.

We also provide a custom pandoc writer for djot (`djot-writer.lua`),
so that documents in other formats can be converted to djot
format, and a custom pandoc reader (`djot-reader.lua`), so that
djot documents can be converted to any format pandoc supports.
To use these, just put them in your working directory and use
`pandoc -f djot-reader.lua` to convert from djot, and `pandoc -t
djot-writer.lua` to convert to djot. (You'll need pandoc version
2.18 or higher.)

## Rationale

Here are some design goals:

1. It should be possible to parse djot markup in linear time,
    with no backtracking.

2. Parsing of inline elements should be "local" and not depend
    on what references are defined later. This is not the case
    in commonmark:  `[foo][bar]` might be "[foo]" followed by
    a link with text "bar", or "[foo][bar]", or a link with
    text "foo", or a link with text "foo" followed by
    "[bar]", depending on whether the references `[foo]` and
    `[bar]` are defined elsewhere (perhaps later) in the
    document. This non-locality makes accurate syntax highlighting
    nearly impossible.

3. Rules for emphasis should be simpler. The fact that doubled
    characters are used for strong emphasis in commonmark leads to
    many potential ambiguities, which are resolved by a daunting
    list of 17 rules. It is hard to form a good mental model
    of these rules. Most of the time they interpret things the
    way a human would most naturally interpret them---but not always.

4. Expressive blind spots should be avoided. In commonmark,
    you're out of luck if you want to produce the HTML
    `a<emph>?</emph>b`, because the flanking rules classify
    the first asterisk in `a*?*b` as right-flanking. There is a
    way around this, but it's ugly (using a numerical entity instead
    of `a`). In djot there should not be expressive blind spots of
    this kind.

5. Rules for what content belongs to a list item should be simple.
    In commonmark, content under a list item must be indented as far
    as the first non-space content after the list marker (or five
    spaces after the marker, in case the list item begins with indented
    code). Many people get confused when their indented content is
    not indented far enough and does not get included in the list item.

6. Parsers should not be forced to recognize unicode character classes,
    HTML tags, or entities, or perform unicode case folding.
    That adds a lot of complexity.

7. The syntax should be friendly to hard-wrapping: hard-wrapping
    a paragraph should not lead to different interpretations, e.g.
    when a number followed by a period ends up at the beginning of
    a line. (I anticipate that many will ask, why hard-wrap at
    all?  Answer:  so that your document is readable just as it
    is, without conversion to HTML and without special editor
    modes that soft-wrap long lines. Remember that source readability
    was one of the prime goals of Markdown and Commonmark.)

8. The syntax should compose uniformly, in the following sense:
    if a sequence of lines has a certain meaning outside a list
    item or block quote, it should have the same meaning inside it.
    This principle is [articulated in the commonmark 
    spec](https://spec.commonmark.org/0.30/#principle-of-uniformity),
    but the spec doesn't completely abide by it (see
    commonmark/commonmark-spec#634).

9. It should be possible to attach arbitrary attributes to any
    element.

10. There should be generic containers for text, inline content,
    and block-level content, to which arbitrary attributes can be applied.
    This allows for extensibility using AST transformations.

11. The syntax should be kept as simple as possible, consistent with
    these goals. Thus, for example, we don't need two different
    styles of headings or code blocks.

These goals motivated the following decisions:


- Block-level elements can't interrupt paragraphs (or headings),
  because of goal 7. So in djot the following is a single paragraph, not
  (as commonmark sees it) a paragraph followed by an ordered list
  followed by a block quote followed by a section heading:

  ```
  My favorite number is probably the number
  1. It's the smallest natural number that is
  > 0. With pencils, though, I prefer a
  # 2.
  ```

  Commonmark does make some concessions to goal 7, by forbidding
  lists beginning with markers other than `1.` to interrupt paragraphs.
  But this is a compromise and a sacrifice of regularity and
  predictability in the syntax. Better just to have a general rule.

- An implication of the last decision is that, although "tight"
  lists are still possible (without blank lines between items),
  a *sublist* must always be preceded by a blank line. Thus,
  instead of

  ```
  - Fruits
    - apple
    - orange
  ```

  you must write

  ```
  - Fruits

    - apple
    - orange
  ```

  (This blank line doesn't count against "tightness.")
  reStructuredText makes the same design decision.

- Also to promote goal 7, we allow headings to "lazily"
  span multiple lines:

  ```
  ## My excessively long section heading is too
  long to fit on one line.
  ``` 

  While we're at it, we'll simplify by removing setext-style
  (underlined) headings. We don't really need two heading
  syntaxes (goal 11).

- To meet goal 5, we have a very simple rule: anything that is
  indented further than the start of the list marker belongs in
  the list item.

  ```
  1. list item

    > block quote inside item 1

  2. second item
  ```

  In commonmark, this would be parsed as two separate lists with
  a block quote between them, because the block quote is not
  indented far enough. What kept us from using this simple rule
  in commonmark was indented code blocks. If list items are
  going to contain an indented code block, we need to know at
  what column to start counting the indentation, so we fixed on
  the column that makes the list look best (the first column of
  non-space content after the marker):

  ```
  1.  A commonmark list item with an indented code block in it.

          code!
  ```

  In djot, we just get rid of indented code blocks. Most people
  prefer fenced code blocks anyway, and we don't need two
  different ways of writing code blocks (goal 11).

- To meet goal 6 and to avoid the complex rules commonmark
  adopted for handling raw HTML, we simply do not allow raw HTML,
  except in explicitly marked contexts, e.g.
  `` `<a id="foo">`{=html} `` or

  ````
  ``` =html
  <table>
  <tr><td>foo</td></tr>
  </table>
  ```
  ````

  Unlike Markdown, djot is not HTML-centric. Djot documents
  might be rendered to a variety of different formats, so although
  we want to provide the flexibility to include raw content in
  any output format, there is no reason to privilege HTML. For
  similar reasons we do not interpret HTML entities, as
  commonmark does.

- To meet goal 2, we make reference link parsing local.
  Anything that looks like `[foo][bar]` or `[foo][]` gets
  treated as a reference link, regardless of whether `[foo]`
  is defined later in the document. A corollary is that we
  must get rid of shortcut link syntax, with just a single
  bracket pair, `[like this]`. It must always be clear what is a
  link without needing to know the surrounding context.

- In support of goal 6, reference links are no longer
  case-insensitive. Supporting this beyond an ASCII context
  would require building in unicode case folding to every
  implementation, and it doesn't seem necessary.

- A space or newline is required after `>` in block quotes,
  to avoid the violations of the principle of uniformity 
  noted in goal 8:

  ```
  >This is not a
  >block quote in djot.
  ```

- To meet goal 3, we avoid using doubled characters for
  strong emphasis. Instead, we use `_` for emphasis and `*` for
  strong emphasis. Emphasis can begin with one of these
  characters, as long as it is not followed by a space,
  and will end when a similar character is encountered,
  as long as it is not preceded by a space and some
  different characters have occurred in between. In the case
  of overlap, the first one to be closed takes precedence.
  (This simple rule also avoids the need we had in commonmark to
  determine unicode character classes---goal 6.)

- Taken just by itself, this last change would introduce a
  number of expressive blind spots. For example, given the
  simple rule,
  ```
  _(_foo_)_
  ```
  parses as
  ``` html
  <em>(</em>foo<em>)</em>
  ```
  rather than
  ``` html
  <em>(<em>foo</em>)</em>
  ```
  If you want the latter
  interpretation, djot allows you to use the syntax
  ```
  _({_foo_})_
  ```
  The `{_` is a `_` that can only open emphasis, and the `_}` is
  a `_` that can only close emphasis. The same can be done with
  `*` or any other inline formatting marker that is ambiguous
  between an opener and closer. These curly braces are
  *required* for certain inline markup, e.g. `{=highlighting=}`,
  `{+insert+}`, and `{-delete-}`, since the characters `=`, `+`,
  and `-` are found often in ordinary text.

- In support of goal 1, code span parsing does not backtrack.
  So if you open a code span and don't close it, it extends to
  the end of the paragraph. That is similar to the way fenced
  code blocks work in commonmark.

  ```
  This is `inline code.
  ```

- In support of goal 9, a generic attribute syntax is
  introduced. Attributes can be attached to any block-level
  element by putting them on the line before it, and to any
  inline-level element by putting them directly after it.

  ```
  {#introduction}
  This is the introductory paragraph, with
  an identifier `introduction`.

                             {.important color="blue" #heading}
  ## heading

  The word *atelier*{weight="600"} is French.
  ```

- Since we are going to have generic attributes, we no longer
  use support quoted titles in links. One can add a title
  attribute if needed, but this isn't very common, so we don't
  need a special syntax for it:

  ```
  [Link text](url){title="Click me!"}
  ```

- Fenced divs and bracketed spans are introduced in order to
  allow attributes to be attached to arbitrary sequences of
  block-level or inline-level elements. For example,

  ```
  {#warning .sidebar}
  ::: Warning
  This is a warning.
  Here is a word in [français]{lang=fr}.
  :::
  ```

## Syntax

For a full syntax reference, see the
[syntax description](https://htmlpreview.github.io/?https://github.com/jgm/djot/blob/master/doc/syntax.html).

A vim syntax highlighting definition for djot is provided in
`editors/vim/`.

## Playground

You can play with djot on the live [djot
playground](https://djot.net/playground/), designed
by @dtinth.

## Using the Lua library

### Quick start

If you just want to parse some input and produce HTML:

``` lua
local djot = require("djot")
local input = "This is *djot*"
local parser = djot.Parser:new(input)
parser:parse()
local html = parser:render_html()
```

### In more depth

``` lua
local djot = require("djot")

-- Create a parser with input string and options:
local parser = djot.Parser:new(input, options)
-- Parse the document:
parser:parse()

-- 'options' may be omitted, but if present it should be
-- a table with the following boolean fields (both defaulting
-- to false):
--
-- verbose: if true, warnings are emitted to stderr.
-- sourcepos: if true, source positions are tracked.

-- At this point we have a list of "matches"
-- (including start/end -- position and an annotation like '+blockquote').
local matches = parser:get_matches()

-- 'matches' is an array of match objects; to deal with them, you'll need
local match = require("djot.match")
local startpos, endpos, annotation = match.unpack_match(matches[1])

-- Here 'startpos' and 'endpos' are integer byte positions in the
-- input string, and 'annotation' is a string starting with '+'
-- or '-', e.g. '+blockquote'.

-- You can use 'matches_pattern' to check the match's annotation
-- against a Lua pattern without unpacking it:
if match.matches_pattern(matches[1], 'blockquote') then
  -- second argument is a Lua pattern
  print ("It's either +blockquote or -blockquote!")
end

-- To render the stream of matches in a human-readable form:
parser:render_matches(io.stdout)
-- or as a string
local matches_string = parser:render_matches()

-- After parsing, warnings can also be obtained as a Lua table:
local warnings = parser.warnings

-- To build an AST from the list of matches:
parser:build_ast()

-- The AST is now available as a Lua table, parser.ast
-- It can be modified programatically and any changes
-- you make will be reflected in rendered HTML.

-- To render the AST in human-readable form:
parser:render_ast(io.stdout)
-- or as a string:
local ast_string = parser:render_ast()
-- This function will call 'build_ast' automatically if the
-- AST is not built.

-- To render the AST as an HTML string:
local html = parser:render_html()
-- Or, to send the HTML output to a handle:
parser:render_html(io.stdout)
-- This function will call 'build_ast' automatically if the
-- AST is not built.
```

## The code

The code for djot (excluding the test suite) is standard Lua,
compatible with 5.1--5.4, including luajit. It has no external
dependencies.

`make install` will build the rockspec and install the
library and executable using luarocks. Once installed,
the library can be used by Lua programs, and the executable can
be run using `djot`. `djot -h` will give help output.

If you can't assume that lua or luajit will be installed on
the target machine, you can use `make djotbin` to create a
portable binary that includes luajit and the necessary scripts.
(This assumes you have `luastatic` installed, and `libluajit`
in the `/usr/local` tree.)

`make test` will run the tests, and `make testall` will also
run some tests of pathological cases.

## License

The code and documentation are released under the MIT license.

