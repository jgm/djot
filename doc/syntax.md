# Djot syntax reference

## Inline syntax

### Precedence

Most inline syntax is defined by opening and closing delimiters that
surround inline content, defining it as emphasized, or as link text, for
example. The basic principle governing “precedence” for inline
containers is that the first opener that gets closed takes precedence.
Containers can’t overlap, so once an opener gets closed, any potential
openers between the opener and the closer get marked as regular text and
can no longer open inline syntax. For example, in

    _This is *regular_ not strong* emphasis

the regular emphasis opened by the first `_` gets closed by the second
`_`, at which point the first `*` is no longer eligible to open strong
emphasis. But in

    *This is _strong* not regular_ emphasis

it goes just the opposite way.

Similarly,

    [Link *](url)*

contains a link, while

    *Emphasis [*](url)

does not (because the strong emphasis closes over the `[` delimiter).

Although overlapping containers are ruled out, *nested* containers are
fine:

    _This is *strong within* regular emphasis_

In cases of ambiguity, `{` and `}` may be used to mark delimiters as
openers or closers. Thus `{_` behaves like `_` but can *only* open
emphasis, while `_}` behaves like `_` but can *only* close emphasis:

    {_Emphasized_}
    _}not emphasized{_

Explicitly marked closers can only match explicitly marked
openers, and non-marked closers can only match non-marked
openers (so, for example, `{_hi_`) doesn't produce emphasis).

When there are multiple openers that might be matched with a
given closer, the closest one is used.  For example:

    *not strong *strong*

### Ordinary text

Anything that isn’t given a special meaning is parsed as literal text.

All ASCII punctuation characters (even those that have no special
meaning in djot) may be backslash-escaped. Thus, `\*` includes a
literal `*` character. Backslashes before characters other than ASCII
punctuation characters are just treated as literal backslashes, with the
following exceptions:

- Backslash before a newline (or before spaces or tabs followed
  by a newline) is parsed as a hard line break.  Spaces and tab
  characters before the backslash are ignored in this case.
- Backslash before a space is parsed as a nonbreaking space.

### Link

There are two kinds of links, *inline* links and *reference* links.

Both kinds start with the link text (which may contain arbitrary inline
formatting) inside `[` … `]` delimiters.

*Inline links* then contain the link destination (URL) in parentheses.
There should be no space between the `]` at the end of the link text and
the open `(` defining the link destination.

    [My link text](http://example.com)

The URL may be split over multiple lines; in that case, the line breaks
and any leading and trailing space is ignored, and the lines are
concatenated together.

    [My link text](http://example.com?product_number=234234234234
    234234234234)

*Reference links* use a reference label in square brackets, instead of a
destination in parentheses. This must come immediately after the link
text:

    [My link text][foo bar]

    [foo bar]: http://example.com

The reference label should be defined somewhere in the document: see
[Reference link definition], below. However, the parsing of the
link is “local” and does not depend on whether the label is
defined:

    [foo][bar]

If the label is empty, then the link text will be taken to be the
reference label as well as the link text:

    [My link text][]

    [My link text]: /url

### Image

Images work just like links, but have a `!` prefixed. As with links,
both inline and reference variants are possible.

    ![picture of a cat](cat.jpg)

    ![picture of a cat][cat]

    ![cat][]

    [cat]: feline.jpg

### Autolink

A URL or email address that is enclosed in `<`…`>` will be hyperlinked.
The content between pointy braces is treated literally
(backslash-escapes may not be used).

    <https://pandoc.org/lua-filters>
    <me@example.com>

The URL or email address may not contain a newline.

### Verbatim

Verbatim content begins with a string of consecutive backtick characters
(`` ` ``) and ends with an equal-lengthed string of consecutive backtick
characters.

    ``Verbatim with a backtick` character``
    `Verbatim with three backticks ``` character`

Material between the backticks is treated as verbatim text (backslash
escapes don’t work there).

If the content starts or ends with a backtick character, a single space
is removed between the opening or closing backticks and the content.

    `` `foo` ``

If the text to be parsed as inline ends before a closing backtick string
is encountered, the verbatim text extends to the end.

    `foo bar

### Emphasis/strong

Emphasized inline content is delimited by `_` characters. Strong
emphasis is delimited by `*` characters.

    _emphasized text_

    *strong emphasis*

A `_` or `*` can open emphasis only if it is not directly followed by
whitespace. It can close emphasis only if it is not directly preceded by
whitespace, and only if there are some characters besides the delimiter
character between the opener and the closer.

    _ Not emphasized (spaces). _

    ___ (not an emphasized `_` character)

Emphasis can be nested:

    __emphasis inside_ emphasis_

Curly braces may be used to force interpretation of a `_` or `*` either
as an opener or as a closer.

    {_ this is emphasized, despite the spaces! _}

### Highlighted

Inline content between `{=` and `=}` will be treated as highlighted text
(in HTML, `<mark>`). Note that the `{` and `}` are mandatory.

    This is {=highlighted text=}.

### Super/subscript

Superscript is delimited by `^` characters, subscript by `~`.

    H~2~O and djot^TM^

Curly braces may be used, but are not required:

    H{~one two buckle my shoe~}O

### Insert/delete

To mark inline text as inserted, use `{+` and `+}`. To mark it as
deleted, use `{-` and `-}`. The `{` and `}` are mandatory.

    My boss is {-mean-}{+nice+}.

### Smart punctuation

Straight double quotes (`"`) and single quotes (`'`) are parsed as curly
quotes. Djot is pretty good about figuring out from context which
direction of quote is needed.

    "Hello," said the spider.
    "'Shelob' is my name."

However, its heuristics can be overridden by
using curly braces to mark a quote as an opener `{"` or a closer `"}`:

    '}Tis Socrates' season to be jolly!

If you want a straight quote, use a backslash-escape:

    5\'11\"

A sequence of three periods is parsed as *ellipses*.

A sequence of three hyphens is parsed as an *em-dash*.

A sequence of two hyphens is parsed as an *en-dash*.

    57--33 oxen---and no sheep...

Longer sequences of hyphens are divided into em-dashes, en-dashes, and
hyphens; uniformly, if possible, and preferring em-dashes, when
uniformity can be achieved either way. (So, 4 hyphens become two
en-dashes, while 6 hyphens become two em-dashes).

    a----b c------d

### Math

To include LaTeX math, put the math in a verbatim span and prefix it
with `$` (for inline math) or `$$` (for display math):

    Einstein derived $`e=mc^2`.
    Pythagoras proved
    $$` x^n + y^n = z^n `

### Footnote reference

A footnote reference is `^` + the reference label in square brackets.

    Here is the reference.[^foo]

    [^foo]: And here is the note.

See [Footnote], below, for the syntax of the footnote itself.

### Line break

Line breaks in inline content are treated as “soft” breaks; they may be
rendered as spaces, or (in contexts where newlines are treated
semantically like spaces, such as HTML) as newlines.

To get a hard line break (of the sort represented by HTML’s `<br>`), use
backslash + newline:

    This is a soft
    break and this is a hard\
    break.

### Comment

Material between two `%` characters in an attribute will be ignored and
treated as a comment. This allows comments to be added to attributes:

    {#ident % later we'll add a class %}

But it also serves as a general way to add comments. Just use an
attribute specifier that contains only a comment:

    Foo bar {% This is a comment, spanning
    multiple lines %} baz.

### Symbols

Surrounding a word with `:` signs creates a "symbol," which by
default is just rendered literally but may be treated specially
by a filter.  (For example, a filter could convert symbols to
emojis. But this is not built into djot.)

    My reaction is :+1: :smiley:.

### Raw inline

Raw inline content in any format may be included using a verbatim span
followed by `{=FORMAT}`:

    This is `<?php echo 'Hello world!' ?>`{=html}.

This content is intended to be passed through verbatim when rendering
the designated format, but ignored otherwise.

### Span

Text in square brackets that is not a link or image and is followed
immediately by an attribute is treated as a generic span.

    It can be helpful to [read the manual]{.big .red}.

### Inline attributes

Attributes are put inside curly braces and must *immediately follow* the
inline element to which they are attached (with no intervening
whitespace).

Inside the curly braces, the following syntax is possible:

- `.foo` specifies `foo` as a class. Multiple classes may be given in
  this way; they will be combined.
- `#foo` specifies `foo` as an identifier. An element may have only one
  identifier; if multiple identifiers are given, the last one is used.
- `key="value"` or `key=value` specifies a key-value attribute. Quotes
  are not needed when the value consists entirely of ASCII alphanumeric
  characters or `_` or `:` or `-`. Backslash escapes may be used inside
  quoted values.
- `%` begins a comment, which ends with the next `%` or the end of the
  attribute (`}`).

Attribute specifiers may contain line breaks.

Example:

    An attribute on _emphasized text_{#foo
    .bar .baz key="my value"}

Attribute specifiers may be “stacked,” in which case they will be
combined. Thus,

    avant{lang=fr}{.blue}

is the same as

    avant{lang=fr .blue}

## Block syntax

As in commonmark, block structure can be discerned prior to inline
parsing and takes priority over inline structure.

Indeed, blocks can be parsed line by line with no backtracking. The
contribution a line makes to block-level structure never depends on a
future line.

Indentation is only significant for list item or footnote nesting.

Block-level items should be separated from one another by blank lines.
There are some cases in which two block-level elements can be
adjacent—e.g., a thematic break or fenced code block can be directly
followed by a paragraph. Indeed, the possibility of line-by-line parsing
precludes requiring a blank line after a block-level element. But for
readability, we recommend *always* separating block-level elements by
blank lines. Paragraphs can never be interrupted by other block-level
elements, and must always end with a blank line (or the end of the
document or containing element).

### Paragraph

A paragraph is a sequence of nonblank lines that does not meet the
condition for being one of the other block-level elements. The textual
content is parsed as a sequence of inline elements. Newlines are treated
as soft breaks and interpreted like spaces in formatted output. A
paragraph ends with a blank line or the end of the document.

### Heading

A heading starts with a sequence of one or more `#` characters,
followed by whitespace.  The number of `#` characters defines
the heading level.  The following text is parsed as inline content.

```
## A level _two_ heading!
```

The heading text may spill over onto following lines, which may
also be preceded by the same number of `#` characters (but
these can also be left off).

The heading ends when a blank line (or the end of the document
or enclosing container) is encountered.

```
# A heading that
# takes up
# three lines

A paragraph, finally
```

```
# A heading that
takes up
three lines

A paragraph, finally.
```

### Block quote

A block quote is a sequence of lines, each of which begins with `>`,
followed either by a space or by the end of the line. The contents of
the block quote (minus initial `>`) are parsed as block-level content.

    > This is a block quote.
    >
    > 1. with a
    > 2. list in it.

As in Markdown, it is possible to “lazily” omit the `>` prefixes from
regular paragraph lines inside the block quote, except in front of the
first line of a paragraph:

    > This is a block
    quote.

### List item

A list item consists of a list marker followed by a space (or a newline)
followed by one or more lines, indented relative to the list marker. For
example:

    1.  This is a
     list item.

     > containing a block quote

Indentation may be “lazily” omitted on paragraph lines following the
first line of a paragraph:

    1.  This is a
    list item.

      Second paragraph under the
    list item.

The following basic types of list markers are available:

| Marker  | List type                                                |
|---------|----------------------------------------------------------|
| `-`     | bullet                                                   |
| `+`     | bullet                                                   |
| `*`     | bullet                                                   |
| `1.`    | ordered, decimal-enumerated, followed by period          |
| `1)`    | ordered, decimal-enumerated, followed by parenthesis     |
| `(1)`   | ordered, decimal-enumerated, enclosed in parentheses     |
| `a.`    | ordered, lower-alpha-enumerated, followed by period      |
| `a)`    | ordered, lower-alpha-enumerated, followed by parenthesis |
| `(a)`   | ordered, lower-alpha-enumerated, enclosed in parentheses |
| `A.`    | ordered, upper-alpha-enumerated, followed by period      |
| `A)`    | ordered, upper-alpha-enumerated, followed by parenthesis |
| `(A)`   | ordered, upper-alpha-enumerated, enclosed in parentheses |
| `i.`    | ordered, lower-roman-enumerated, followed by period      |
| `i)`    | ordered, lower-roman-enumerated, followed by parenthesis |
| `(i)`   | ordered, lower-roman-enumerated, enclosed in parentheses |
| `I.`    | ordered, upper-roman-enumerated, followed by period      |
| `I)`    | ordered, upper-roman-enumerated, followed by parenthesis |
| `(I)`   | ordered, upper-roman-enumerated, enclosed in parentheses |
| `:`     | definition                                               |
| `- [ ]` | task                                                     |

Ordered list markers can use any number in the series: thus, `(xix)` and
`v)` are both valid lower-roman-enumerated markers, and `v)` is *also* a
valid lower-alpha-enumerated marker.

#### Task list item

A bullet list item that begins with `[ ]`, `[X]`, or `[x]` followed by a
space is a task list item, either unchecked (`[ ]`) or checked (`[X]` or
`[x]`).

#### Definition list item

In a definition list item, the first line or lines after the `:` marker
is parsed as inline content and taken to be the *term* defined. Any
further blocks included in the item are assumed to be the *definition*.

    : orange

      A citrus fruit.

### List

A list is simply a sequence of list items of the same type (where each
line in the table above defines a type). Note that changing ordered list
style or bullet will stop one list and start a new one.
Hence the following list items get grouped into four distinct lists:

    i) one
    i. one (style change)
    + bullet
    * bullet (style change)

Sometimes list items are ambiguous as to type. In this case the
ambiguity will be resolved in such a way as to continue the list, if
possible. For example, in

    i. item
    j. next item

the first item is ambiguous between lower-roman-enumerated and
lower-alpha-enumerated. But only the latter interpretation works for the
next item, so we prefer the reading that allows us to have one
continuous list rather than two separate ones.

The start number of an ordered list will be determined by the number of
its first item. The numbers of subsequent items are irrelevant.

    5) five
    8) six

A list is classed as *tight* if it does not contain blank lines between
items, or between blocks inside an item. Blank lines at the start or end
of a list do not count against tightness.

    - one
    - two

      - sub
      - sub

A list that is not tight is *loose*. The intended significance
of this distinction is that tight lists should be rendered with
less space between items.

    - one

    - two


### Code block

A code block starts with a line of three or more consecutive backticks,
optionally followed by a language specifier, but nothing else. (The language
specifier may optionally be preceded and/or followed by whitespace.)
The code block ends with a line of backticks equal or greater in length to the
opening backtick “fence,” or the end of the document or enclosing block,
if no such line is encountered. Its contents are interpreted as verbatim
text. If the contents contain a line of backticks, be sure to select a
longer string of backticks to use as the “fence”:

    ````
    This is how you do a code block:

    ``` ruby
    x = 5 * 6
    ```
    ````

Here is an example of a code block that is implicitly closed when its
parent container is closed;

    > ```
    > code in a
    > block quote

    Paragraph.

### Thematic break

A line containing three or more `*` or `-` characters, and nothing else
(except spaces or tabs) is treated is a thematic break (`<hr>` in HTML).
Unlike in Markdown, a thematic break may be indented:

    Then they went to sleep.

          * * * *

    When they woke up, ...

### Raw block

A code block with `=FORMAT` where the language specification would
normally go is interpreted as raw content in `FORMAT` and will be passed
through verbatim to output in that format. For example:

    ``` =html
    <video width="320" height="240" controls>
      <source src="movie.mp4" type="video/mp4">
      <source src="movie.ogg" type="video/ogg">
      Your browser does not support the video tag.
    </video>
    ```

### Div

A div begins with a line of three or more consecutive colons, optionally
followed by white space and a class name (but nothing else). It ends
with a line of consecutive colons at least as long as the opening fence,
or with the end of the document or containing block.

The contents of a div are interpreted as block-level content.

    ::: warning
    Here is a paragraph.

    And here is another.
    :::

### Pipe table

A pipe table consists of a sequence of *rows*. Each row starts and ends
with a pipe character (`|`) and contains one or more *cells* separated
by pipe characters:

    | 1 | 2 |

A *separator line* is a row in which every cell consists of a sequence
of one of more `-` characters, optionally prefixed and/or suffixed by a
`:` character.

When a separator line is encountered, the previous row is treated as a
header, and alignments on that row and any subsequent rows are
determined by the separator line (until a new header is found). The
separator line itself does not contribute a row to the parsed table.

    | fruit  | price |
    |--------|------:|
    | apple  |     4 |
    | banana |    10 |

Column alignments are determined by the separator line in the following
way:

- if the line of `-` begins with a `:` and does not end with one, the
  column is left-aligned
- if it ends with `:` and does not begin with one, the column is
  right-aligned
- if it both begins and ends with `:`, the column is center-aligned
- if it neither begins nor ends with `:`, the column is default-aligned

Here is an example:

    | a  |  b |
    |----|:--:|
    | 1  | 2  |
    |:---|---:|
    | 3  | 4  |

Here the row with `a` and `b` is a header, with the left column
default-aligned and the right column center-aligned. The next real row,
containing `1` and `2`, is also a header, in which the left column is
left-aligned and the right column is right-aligned. This alignment is
also applied to the row that follows, containing `3` and `4`.

A table need not have a header: just omit any separator lines, or (if
you need to specify column alignments) *begin* with a separator line:

    |:--|---:|
    | x | 2  |

Contents of table cells are parsed as inlines. Block-level content is
not possible in pipe table cells.

Djot is smart enough to recognize backslash-escaped pipes and pipes in
verbatim spans; these do not count as cell separators:

    | just two \| `|` | cells in this table |

You can attach a caption to a table using the following syntax:

    ^ This is the caption.  It can contain _inline formatting_
      and can extend over multiple lines, provided they are
      indented relative to the `^`.

The caption can come directly after the table, or there can
be an intervening blank line.

### Reference link definition

A reference link definition consists of the reference label in square
brackets, followed by a colon, followed by whitespace (or a newline) and
the URL. The URL may be split over multiple lines (in which case the
lines will be concatenated, with any leading or trailing space removed).
None of the chunks of the URL may contain internal whitespace.

    [google]: https://google.com

    [product page]: http://example.com?item=983459873087120394870128370
      0981234098123048172304

No case normalization is done on reference labels, a reference defined
as `[link]` cannot be used as `[Link]`, as it can in Markdown.

Attributes on reference definitions get transferred to the link:

    {title=foo}
    [ref]: /url

    [ref][]

produces a link with text “ref”, URL `/url`, and title “foo”. However,
if the same attribute is defined on both a link and a reference
definition, the attribute on the link overrides the one on the reference
definition.

    {title=foo}
    [ref]: /url

    [ref][]{title=bar}

Here we get a link with title “bar”.

### Footnote

A footnote consists of a footnote reference followed by a colon followed
by the contents of the note, indented to any column beyond the column in
which the reference starts. The contents of the note are parsed as
block-level content.

    Here's the reference.[^foo]

    [^foo]: This is a note
      with two paragraphs.

      Second paragraph.

      > a block quote in the note.

As with block quotes and list items, subsequent lines in paragraphs can
“lazily” omit the indentation:

    Here's the reference.[^foo]

    [^foo]: This is a note
    with two paragraphs.

      Second paragraph must
    be indented, at least in the first line.

### Block attributes

To attach attributes to a block-level element, put the attributes on the
line immediately before the block. Block attributes have the same syntax
as inline attributes, but if they don't fit on one line, subsequent lines
must be indented. Repeated attribute specifiers can be used, and
the attributes will accumulate.

    {#water}
    {.important .large}
    Don't forget to turn off the water!

    {source="Iliad"}
    > Sing, muse, of the wrath of Achilles

### Links to headings

Identifiers are added automatically to any headings that
do not have explicit identifiers attached to them.
The identifier is formed by taking the textual content of
the heading, removing punctuation (other than `_` and `-`),
replacing spaces with `-`, and if necessary for uniqueness,
adding a numerical suffix.

```
## My heading + auto-identifier
```

However, for the most part you do not need to know the
identifiers that are assigned to headings, because
implicit link references are created for all headings.
Thus, to link to a heading titled "Epilogue" in the same
document, one can simply use a reference link:

```
See the [Epilogue][].

    * * * *

# Epilogue
```

## Nesting limits

Conforming implementations can impose reasonable limits on
nesting to avoid stack overflows or other issues.
Few realistic documents will need more than, say, 12 levels
of nesting, so a limit of 512 should be perfectly safe.
