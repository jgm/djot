# djot cheatsheet

## Basics

| Markup | Result |
| --- | --- |
| `_italic_` or `{_italic_}` | *italic* |
| `*bold*` or `{*bold*}` | **bold** |
| `` `verbatim/code` `` | `verbatim/code` |
| `H~2~O` | H<sub>2</sub>O |
| `20^th^` | 20<sup>th</sup> |
| `{=highlighted=}` | <mark>highlighted</mark> |
| `{+insert+}` | <ins>insert</ins> |
| `{-delete-}` | <del>delete</del> |

Use triple-backticks for fenced verbatim blocks. If it's a code
block, you may append the language name after the opening backticks
to get syntax highlighting:

~~~~~~
```mylang
func say-hello(nm) {
    print("hello ${nm}!");
}
```
~~~~~~

**Block quote**:

~~~
> Some blockquoted
> content in here.
~~~

**Comments** `{% look like this`\
`and can span multiple lines %}`.

**Emojis**: `:+1:` → 👍, `:smiley:` → 😃 , etc.

**Thematic break** (horizontal line): `***` or `---` on its own line.
Can be longer than three characters, and may contain or be indented
by spaces/tabs.



## Math

Use LaTeX formatting. `` $`p = mv` `` for inline math, and

`` $$`E = K + U` ``

for display math.


## Special Characters

  * `...` → … (ellipsis)
  * `--` → – (an en-dash)
  * `---` → — (an em-dash)
  * Straight quotes (`"foo"`) are converted to curved style (“foo”).
  * Backslash-escape a punctuation character to remove
    its special meaning.
  * Backslash space = non-breaking space.
  * Backslash at end of line = hard line break.

## Links

~~~
<https://example.com>
[read more](https://example.com)
[read this too][foo bar]
[one more link][]
~~~

then later:

~~~
[foo bar]: https://example.com
[one more link]: https://example2.com
~~~

## Images

~~~
![beautiful skyline](clouds.jpg)
![coastal shores][shore]
![lush forests][]

[shore]: the-beach.jpg
[lush forests]: pines.jpg
~~~

## Headings

~~~
# H1
## H2
### H3
~~~

etc.

## Lists

~~~
Itemized list:

 * lions
 * tigers
 * bears
~~~

You can indent your list marker zero or more spaces, using the same
indent for items at same level. If you want a subsequent paragraph to
be part of a list item, indent at least past the list marker.

Like subsequent paragraphs, sublists must be preceded by a blank line
(blank lines are almost always required between block-level elements).
The sublist markers must also be indented at least past the previous
list item's marker.

~~~ 
Another list:

 * First item. This item has a rather long
   line, indented after the line breaks to
   look nice.

 * Second item. This item has a rather long
line too, but without the pretty indent.
 
   Second paragraph of second item.

    - sublist,
    - still in
    - second item.

 * Third item.

Numbered list:

 1. item one
 2. item two
 3. item three

Definition list:

: lions

  Like a C-program, these also have a main.
  
: tigers

  Siberian, Bengal, and Tony the.
  
: bears

  These come in both Teddy and Yogi.
~~~

## Tables

~~~
| Name | Size | Color |
| --- | --- | --- |
| lime | small | green |
| orange | medium | orange |
| grapefruit | large | yellow or pink |
~~~

You can alter the alignment of the cells using colons in the
separator line, and also optionally add spaces to align the cells,
e.g.:

~~~
| Material | Quantity | Catch-phrase  |
| -------- | -------: | :-----------: |
| cotton   |       42 |   Practical!  |
| wool     |       17 |     Warm!     |
| silk     |        4 |    Smooth!    |
~~~


## Footnotes

~~~
The proof is elementary.[^proof]

...

[^proof]: TODO. Haven't figured this out yet.
~~~


## Spans and Divs

~~~
This is [a span]{.some-class #some-id some-key="some val"}.
~~~

and here's a div:

~~~
{.some-class #some-other-id some-key="some val"}
:::
Div content
goes here.
:::
~~~

Note the following shorthand:

~~~
::: warning
Watch out!
:::
~~~

is the same as

~~~
{.warning}
:::
Watch out!
:::
~~~

You can append attributes `_onto any inline_{.greenish}`,
and prefix any block (including just an ordinary paragraph)
with an attribute:

~~~
{.classy}
This paragraph is wearing
a top hat and cuff links.

{source="personal-experience"}
> More than three people on one
> bicycle is *not* recommended.
~~~


## Raw Inline

djot is not HTML-centric. You can add raw content in any format,
inline and in blocks, but it must be explicitly marked:

~~~~~~
We had `<sometag>foos</sometag>`{=html} for dinner.
Then wrapped the leftovers in `\LaTeX`{=latex}.

```{=html}
<video width="320" height="240" controls>
  <source src="movie.mp4" type="video/mp4">
  <source src="movie.ogg" type="video/ogg">
  Your browser does not support the video tag.
</video>
```
~~~~~~
