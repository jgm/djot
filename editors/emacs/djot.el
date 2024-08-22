;;; djot.el              -*- lexical-binding: t -*-

;; Copyright (C) 2024 John MacFarlane

;; Author: John MacFarlane <jgm@berkeley.edu>
;; Keywords: lisp djot
;; Version 0.0.1

;;; Commentary:

;; Major mode for djot, using tree-sitter grammar
;; https://github.com/treeman/tree-sitter-djot

;; This is rudimentary and should be improved in the future.

;;; Code:

;; note: M-x list-faces-display will get you a list of font-lock-X

(defgroup djot-faces nil
  "Faces used in Djot mode"
  :group 'djot
  :group 'faces)

(defface djot-delimiter-face
  '((t :inherit font-lock-delimiter-face))
  "Face for delimiters."
  :group 'djot-faces)

(defface djot-emphasis-face
  '((t :italic t))
  "Face for emphasized text."
  :group 'djot-faces)

(defface djot-strong-face
  '((t :bold t))
  "Face for strongly emphasized text."
  :group 'djot-faces)

(defface djot-heading-face
  '((t :weight bold))
  "Base face for headings."
  :group 'djot-faces)

(defface djot-heading1-face
  '((t :inherit djot-heading-face))
  "Face for level-1 headings."
  :group 'djot-faces)

(defface djot-heading2-face
  '((t :inherit djot-heading-face))
  "Face for level-2 headings."
  :group 'djot-faces)

(defface djot-heading3-face
  '((t :inherit djot-heading-face))
  "Face for level-3 headings."
  :group 'djot-faces)

(defface djot-heading4-face
  '((t :inherit djot-heading-face))
  "Face for level-4 headings."
  :group 'djot-faces)

(defface djot-heading5-face
  '((t :inherit djot-heading-face))
  "Face for level-5 headings."
  :group 'djot-faces)

(defface djot-heading6-face
  '((t :inherit djot-heading-face))
  "Face for level-6 headings."
  :group 'djot-faces)

(defface djot-list-marker-face
  '((t :inherit font-lock-builtin-face))
  "Face for list markers."
  :group 'djot-faces)

(defface djot-verbatim-face
  '((t :inherit fixed-pitch :inherit highlight))
  "Face for verbatim."
  :group 'djot-faces)

(defface djot-attribute-face
  '((t :inherit font-lock-comment-face))
  "Face for attribute."
  :group 'djot-faces)

(defface djot-list-face
  '((t :inherit font-lock-builtin-face))
  "Face for list item markers."
  :group 'djot-faces)

(defface djot-block-quote-face
  '((t :inherit font-lock-builtin-face))
  "Face for block quote sections."
  :group 'djot-faces)

(defface djot-code-block-face
  '((t :inherit djot-verbatim-face))
  "Face for code block."
  :group 'djot-faces)

(defface djot-code-block-language-face
  '((t :inherit font-lock-comment-face))
  "Face for code block language."
  :group 'djot-faces)

(defface djot-span-face
  '((t :inherit font-lock-keyword-face))
  "Face for span."
  :group 'djot-faces)

(defface djot-link-text-face
  '((t :inherit link))
  "Face for link text."
  :group 'djot-faces)

(defface djot-link-destination-face
  '((t :inherit font-lock-type-face))
  "Face for link destination."
  :group 'djot-faces)

(defface djot-reference-face
  '((t :inherit font-lock-type-face))
  "Face for link references."
  :group 'djot-faces)

(defface djot-url-face
  '((t :inherit font-lock-keyword-face))
  "Face for URLs."
  :group 'djot-faces)

(defface djot-math-face
  '((t :inherit font-lock-string-face))
  "Face for math."
  :group 'djot-faces)

(defvar djot-ts-font-lock-rules
  '(
    :language djot
    :override prepend
    :feature verbatim
    ((verbatim
      (verbatim_marker_begin) @djot-delimiter-face
      (content) @djot-verbatim-face
      (verbatim_marker_end) @djot-delimiter-face))

    :language djot
    :override prepend
    :feature emphasis
    ((emphasis
      (emphasis_begin _) @djot-delimiter-face
      (content) @djot-emphasis-face
      (emphasis_end _) @djot-delimiter-face)
     (strong
      (strong_begin _) @djot-delimiter-face
      (content) @djot-strong-face
      (strong_end _) @djot-delimiter-face))

    :language djot
    :override prepend
    :feature math
    ((math
      (math_marker) @djot-delimiter-face
      (math_marker_begin) @djot-delimiter-face
      (content) @djot-math-face
      (math_marker_end) @djot-delimiter-face))

    :language djot
    :override prepend
    :feature span
    ((span) @djot-span-face)

    :language djot
    :override prepend
    :feature div
    ((div_marker_begin) @djot-delimiter-face
     (div_marker_end) @djot-delimiter-face)

    :language djot
    :override prepend
    :feature link
    ((inline_link
      (link_text) @djot-link-text-face
      (inline_link_destination) @djot-link-destination-face)
     (inline_image
      (image_description) @djot-link-text-face
      (inline_link_destination) @djot-link-destination-face)
     (collapsed_reference_link
      (link_text) @djot-link-text-face
      "[]" @djot-link-destination-face)
     (full_reference_link
      (link_text) @djot-link-text-face
      (link_label) @djot-link-destination-face)
     (autolink) @djot-link-text-face
     (link_reference_definition
      (link_label) @djot-reference-face
      (link_destination) @djot-link-destination-face))

    :language djot
    :override t
    :feature block_quote
    ((block_quote
      (content) @djot-block-quote-face)
     (block_quote_marker) @djot-delimiter-face)

    :language djot
    :override t
    :feature attribute
    ((block_attribute _ @djot-attribute-face)
     (inline_attribute _ @djot-attribute-face))

    :language djot
    :override t
    :feature list
    ([ (list_marker_definition)
       (list_marker_dash)
       (list_marker_star)
       (list_marker_task _)
       (list_marker_decimal_period)
       (list_marker_lower_alpha_period)
       (list_marker_lower_roman_period)
       (list_marker_upper_alpha_period)
       (list_marker_upper_roman_period)
       (list_marker_decimal_paren)
       (list_marker_lower_alpha_paren)
       (list_marker_lower_roman_paren)
       (list_marker_upper_alpha_paren)
       (list_marker_upper_roman_paren)
       (list_marker_decimal_parens)
       (list_marker_lower_alpha_parens)
       (list_marker_lower_roman_parens)
       (list_marker_upper_alpha_parens)
       (list_marker_upper_roman_parens)
       ] @djot-list-marker-face)

    :language djot
    :override t
    :feature code_block
    ((code_block
      (code_block_marker_begin) @djot-delimiter-face
      (code) @djot-code-block-face
      (code_block_marker_end) @djot-delimiter-face)
     (code_block
      (language) @djot-code-block-language-face)
     )

    :language djot
    :override t
    :feature heading
    ((heading1
      (marker) @djot-delimiter-face
      (content) @djot-heading1-face)
     (heading2
      (marker) @djot-delimiter-face
      (content) @djot-heading2-face)
     (heading3
      (marker) @djot-delimiter-face
      (content) @djot-heading3-face)
     (heading4
      (marker) @djot-delimiter-face
      (content) @djot-heading4-face)
     (heading5
      (marker) @djot-delimiter-face
      (content) @djot-heading5-face)
     (heading6
      (marker) @djot-delimiter-face
      (content) @djot-heading6-face))
    ))

(defun djot-ts-imenu-node-p (node)
  (string-match-p "^heading" (treesit-node-type node)))

(defun djot-ts-imenu-name-function (node)
  (replace-regexp-in-string "\n\\'" "" (treesit-node-text node)))

(defun djot-ts-setup ()
  "Setup treesit for djot-ts-mode."

  (setq-local treesit-font-lock-settings
              (apply #'treesit-font-lock-rules
                     djot-ts-font-lock-rules))

  (setq-local treesit-font-lock-feature-list
              '((verbatim attribute heading block_quote code_block list)
                (emphasis link math span)))

  (setq-local treesit-simple-imenu-settings
              `((nil ;; "Heading" but there's no point since this is all we do
                 djot-ts-imenu-node-p
                 nil
                 djot-ts-imenu-name-function)))

  (treesit-major-mode-setup))

(define-derived-mode djot-ts-mode text-mode "Djot"
  "Major mode for editing Djot with tree-sitter."

  (setq-local font-lock-defaults nil)
  (when (treesit-ready-p 'djot)
    (treesit-parser-create 'djot)
    (djot-ts-setup)))

(provide 'djot-ts-mode)
;;; djot.el ends here
