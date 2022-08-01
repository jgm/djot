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
      prec(3, seq($._space,
                 choice (prec(4, $.emph), prec(2, $.text)))),
      $.emph,
      $.text,
      $._linebreak
    ),

    emph: $ => seq(
      $.emph_open_delim,
      prec.right(4, repeat1($._inlines)),
      $.emph_close_delim
    ),

    emph_open_delim: $ => prec(5,/_/),

    emph_close_delim: $ => prec(6,/_/),

    text: $ => choice(
        $._str,
        $._space),

    _str: $ => /[^ \t_]+/,

    _space: $ => /[ \t]+/,

    _linebreak: $ => /\r?\n/

  }
});
