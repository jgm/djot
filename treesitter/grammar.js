module.exports = grammar({
  name: "djot",

  rules: {
    source_file: $ => repeat(choice(
      $._block,
      $.blankline)),

    blankline: $ => /[ \t]\r?\n/,

    _block: $ => choice(
      $.paragraph
    ),

    paragraph: $ => prec.right(repeat1($._inline)),

    _inline: $ => choice(
      $.str,
      $.space,
      $.softbreak
    ),

    str: $ => /[^ \t]+/,

    space: $ => /[ \t]+/,

    softbreak: $ => /\r?\n/

  }
});
