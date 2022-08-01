module.exports = grammar({
  name: "djot",

  rules: {
    source_file: $ => repeat(choice(
      $._block,
      $.blankline)),

    blankline: $ => /\r?\n[ \t]\r?\n/,

    _block: $ => choice(
      $._inlines,
      prec(20, $.blankline)
    ),

    _inlines: $ => choice(
      $.emph,
      $.text,
      $._linebreak
    ),

    emph: $ => seq(
      $.emph_open_delim,
      $._inlines,
      $.emph_close_delim
    ),

    emph_open_delim: $ => /_/,

    emph_close_delim: $ => /_/,

    text: $ => prec.right(repeat1(choice(
      $._space,
      $._str))),

    _str: $ => /[^ \t_]+/,

    _space: $ => /[ \t]+/,

    _linebreak: $ => /\r?\n/

  }
});
