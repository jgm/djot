# Changelog

## 0.1 (2022-07-30)

  * Initial release.

## 0.2 (2022-12-05)

  * Change heading syntax (#91).
    
    - Multiline headings may repeat the `#` characters at the
      start of the line, for a clearer visual appearance.
    
      ```
      ## This is a single, multiline
      ## level-2 heading!
      ```
    - We no longer ignore strings of `#` characters at the end of
      the line, as Markdown does.  This feature adds complexity and
      it is hardly ever used in Markdown.

  * Disallow match between `{_` opener and `_` closer (#119).
    In general, openers and closers that are explicitly marked
    using `{` can only match each other, and unmarked openers/closers
    can only match each other.

  * Add note permitting nesting limits (#100).

  * Update docs for thematic breaks (#46). They require three or more
    `*` or `-` characters; previously the docs said four or more.

  * Ignore spaces/tabs before a backslash that marks a hard line break (#3).

  * Allow spaces or tabs between backslash and newline for a hard
    line break (#3).

  * Create cheatsheet.md (#39)

  * Add Quickstart for Markdown users.

  * Improve vim syntax file:

    - Highlight blockquote leader `>`.
    - Autolinks (#81).
    - Comments highlighting.
    - Fix code blocks (#37).
    - Fix raw attribute.
    - Fix whitespace in negative charclasses (#331).

## [Unreleased]

  * Whitespace is optional around language specifier.

  * Add simpler table examples (#155).

  * Exclude footnote references from auto-generated heading IDs
    Clarify that footnote references in headings should be excluded
    when generating auto-identifiers. For example, `# Introduction[^1]`
    should generate the identifier "Introduction", not "Introduction1"
    (#349).

  * Clarify inline precedence for verbatims (#345).

  * Clarify that multiline block attributes are allowed,
    but subsequent lines must be indented.

  * Clarify stability guarantees (#241).

  * Document table caption syntax (#28).

  * Match reference text with example (#244).

  * Fix typos in syntax.md (#272, #237, #230, #273).

  * Update documentation to reflect the emoji -> symbol shift (#112).

  * Clarify that URLs in reference definitions can't contain internal
    whitespace. Motivation:  if they write
    ```
    [foo]: bar baz bim
    ```
    then it's likely intended as a regular paragraph.  Whitespace in
    URLs should be encoded e.g. as `%20` or `+`.

  * Add note on MIME type (#362).

  * Say that .djot and .dj may both be used as extensions (#156, #364).
    Support both in the vim ftdetect.

  * Add emacs/djot.el.

  * Note that current development is focused on djot.js.

  * Move all the Lua code to new djot.lua repository.

  * README: Add tooling section to highlight djot tools for editors
    (#311, #356).

  * Add a link to implmentations benchmarks in the README.md (#329).

  * List implementations in Zig, PHP (#353), Prolog, Rust (#206), Go (#266).

  * Web: Added link to pronunciation wav, another pandoc example.

  * Update title in index.html (#168)

  * Use the JavaScript reference implementation, not the Lua one
    to generate expected output in syntax.html.

