# Changelog

All notable changes to the [djot](https://djot.net) markup language specification
will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Spec Changes

- Exclude footnote references from auto-generated heading IDs.
- Clarify heading ID excludes non-textual elements (symbols, footnotes).
- Clarify inline precedence for verbatims (#345).
- Fix whitespace in negative character classes (#331).
- Clarify that multiline block attributes are allowed in all contexts (#272).
- Clarify that URLs in reference definitions can't contain internal whitespace.

### Documentation

- Add note on MIME type for `.djot` files.
- Say that `.djot` and `.dj` may both be used as extensions.
- Clarify stability guarantees (#241).

### Ecosystem

- Add zjot (Zig) implementation.
- Add djot-php (PHP) implementation (#353).
- Add WordPress plugin for djot-php (#356).
- Add JetBrains IDEs plugin.
- Add Helix editor support (#335).
- Add link to implementations benchmarks (#329).
- Add Djockey tool.
- Add Emacs djot.el and Treesitter support.
- Add Go implementation (#266).
- Add Rust implementation (#206).
- Note that reference implementation is now djot.js (JavaScript).

### Fixed

- Fix djot.el syntax highlighting.

## [0.2.0] - 2023-01-03

### Breaking Changes

- Changed emoji syntax to generic "symbol" (`:emoji:` -> `:symbol:`).
- Changed list annotations to use `|` instead of `[..]` (aligned with djot.js).
- Changed `list_style` to `style` for consistency with djot.js.
- Heading syntax changes: allow repeated `#` on multiline continuation lines; trailing `#` characters are no longer ignored.

### Spec Changes

- Auto-identifiers now exclude certain inline elements.
- Math elements no longer have children nodes.
- Allow attributes to attach to footnote elements (#118).
- Allow one-character bare class name in fenced div.
- Allow underscores and hyphens in class name after fenced div.
- Allow display math to be escaped.
- Disallow match between `{_` opener and `_` closer.
- Don't allow a fenced div closer inside a code block.
- Add hierarchical sections to the AST.
- Whitespace is optional around language specifier in code blocks.

### Fixed

- Fix parsing of empty inline attributes (#93).
- Fix parsing of `{1--}` and improved handling of inline `-` (#104).
- Fix issue with empty div (#96).
- Fix parsing bug with failed tables (#106).
- Fix table parsing with escaped `|` (#111).
- Fix quoted block attributes spanning multiple lines.
- Fix multiline block attributes inside block quotes.
- Fix two bugs in HTML footnote rendering.
- Fix bug in tight/loose list determination.
- Fix endpos for headings.
- Fix minor bug in reparse_attributes.

### Added

- Add filter system for AST transformation.
- Add `djot.version` export.
- Add long options and `--version` to CLI.
- Add man page for djot CLI.
- Document table caption syntax (#28).

### Documentation

- Add note about `.dj` extension (#156).
- Add simpler table examples (#155).
- Extensive API documentation improvements.

## [0.1.0] - 2022-07-30

Initial release of the djot markup language specification.

### Features

- Block elements: paragraphs, headings, code blocks, lists, block quotes,
  thematic breaks, tables, divs, raw blocks.
- Inline elements: emphasis, strong, links, images, code spans, math,
  smart punctuation, emoji, spans, raw inlines.
- Attributes on both block and inline elements.
- Reference links and footnotes.
- Lua reference implementation with HTML renderer.

### Documentation

- Initial syntax specification (`syntax.md`).
- Lua library documentation.
- Playground for interactive testing.

[Unreleased]: https://github.com/jgm/djot/compare/0.2.0...HEAD
[0.2.0]: https://github.com/jgm/djot/compare/0.1.0...0.2.0
[0.1.0]: https://github.com/jgm/djot/releases/tag/0.1.0
