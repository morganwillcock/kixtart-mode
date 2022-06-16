;;; kixtart-mode.el --- Major mode for editing KiXtart files -*- lexical-binding: t; -*-

;; Copyright (C) 2022 Morgan Willcock

;; Author: Morgan Willcock <morganwillcock@users.noreply.github.com>
;; Keywords: languages
;; Package-Requires: ((emacs "27.1"))
;; URL: https://github.com/morganwillcock/kixtart-mode
;; Version: 0.1

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; kixtart-mode is a major mode for editing KiXtart script files which
;; implements the following features:

;; - syntax highlighting
;; - indentation
;; - beginning and end of defun
;; - Imenu support
;; - Outline mode support

;; Syntax highlighting is implemented for language keywords, function names,
;; labels, macros, and variables.  Malformed macro names can potentially drop
;; trailing syntax or always evaluate to 0, in such cases the relevant portion
;; of macro names will be highlighted as a warning.

;; Indentation will be applied by determining the number of script-blocks which
;; are open around the current buffer position, where parentheses or the
;; following commands are deemed to open a new or close an existing
;; script-block:

;; | Open       | Close          |
;; |------------+----------------|
;; | DO         | UNTIL          |
;; | CASE       | CASE ENDSELECT |
;; | ELSE       | ENDIF          |
;; | FOR        | NEXT           |
;; | FUNCTION   | ENDFUNCTION    |
;; | IF         | ELSE ENDIF     |
;; | SELECT     | ENDSELECT      |
;; | WHILE      | LOOP           |

;; The indentation offset applied to each subsequent script-block level is
;; determined by the customizable variable `kixtart-indent-offset' combined with
;; the indentation level of the line which opened the current script-block.  The
;; movement function `kixtart-up-script-block' uses the same rules of
;; script-block definition to move point, to the buffer position which opened
;; the current script-block, based on its currently determined script-block
;; level.

;; `beginning-of-defun-function' and `end-of-defun-function' are implemented and
;; should work well for function definitions which appear at the "top-level" of
;; the script.  If FUNCTION commands are not positioned at the beginning of a
;; line, navigation can be improved by remapping the key which would normally
;; call `beginning-of-defun' to call `beginning-of-defun-raw' in its place:

;; (add-hook 'kixtart-mode-hook
;;           (lambda ()
;;             (local-set-key [remap beginning-of-defun]
;;                            'beginning-of-defun-raw)))

;; `imenu' will list the names of all defined function as top level menu entries
;; as well as a single "/Labels" sub-menu entry which lists all defined label
;; names.

;; `outline-mode' settings borrow some conventions from the built-in Lisp mode
;; and will determine outline levels by looking for 3 or more ';' characters
;; appearing at the start of a line, followed by at least 1 whitespace
;; character.  ";;;" represents an outline level depth of 1.  Depth is increased
;; by 1 for every additional ';' character.  FUNCTION commands which appear at
;; the start of a line will define additional outline levels at the maximum
;; depth.

;; Note: Since the KiXtart language does not mandate any structured use of lines
;; this presents some challenges to line based parsing.  Currently both syntax
;; highlighting and Imenu entries for function names require the function name
;; to be declared on the same line as the FUNCTION command.

;;; Code:

(require 'imenu)
(eval-when-compile
  (require 'rx))

;;;; Customization

(defgroup kixtart nil
  "Major mode for editing KiXtart files."
  :tag "KiXtart"
  :link '(emacs-commentary-link "kixtart-mode")
  :group 'languages
  :prefix "kixtart-")

(defcustom kixtart-indent-offset 4
  "Specifies the indentation offset applied by `kixtart-indent-line'.
Lines determined to be within script-blocks are indented by this
number of columns per script-block level."
  :type 'integer)

;;;; Search patterns

(defmacro kixtart-rx (&rest regexps)
  "Extended version of `rx' for translation of form REGEXPS."
  `(rx-let ((command
             (or ??
                 (seq symbol-start
                      (or "beep" "big" "break" "call" "case" "cd" "cls" "color"
                          "cookie1" "copy" "debug" "del" "dim" "display" "do"
                          "each" "else" "endfunction" "endif" "endselect" "exit"
                          "flushkb" "for" "function" "get" "gets" "global" "go"
                          "gosub" "goto" "if" "include" "loop" "md" "move"
                          "next" "password" "play" "quit" "rd" "redim" "return"
                          "run" "select" "set" "setl" "setm" "settime" "shell"
                          "sleep" "small" "until" "use" "while")
                      symbol-end)))
            (command-endfunction
             (seq symbol-start "endfunction" symbol-end))
            (command-function
             (seq symbol-start "function" symbol-end))
            (function
             (seq symbol-start
                  (or "abs" "addkey" "addprinterconnection" "addprogramgroup"
                      "addprogramitem" "asc" "ascan" "at" "backupeventlog" "box"
                      "cdbl" "chr" "cint" "cleareventlog" "close"
                      "comparefiletimes" "createobject" "cstr" "dectohex"
                      "delkey" "delprinterconnection" "delprogramgroup"
                      "delprogramitem" "deltree" "delvalue" "dir" "enumgroup"
                      "enumipinfo" "enumkey" "enumlocalgroup" "enumvalue"
                      "execute" "exist" "existkey" "expandenvironmentvars" "fix"
                      "formatnumber" "freefilehandle" "getcommandline"
                      "getdiskspace" "getfileattr" "getfilesize" "getfiletime"
                      "getfileversion" "getobject" "iif" "ingroup" "instr"
                      "instrrev" "int" "isdeclared" "join" "kbhit" "keyexist"
                      "lcase" "left" "len" "loadhive" "loadkey" "logevent"
                      "logoff" "ltrim" "memorysize" "messagebox" "open"
                      "readline" "readprofilestring" "readtype" "readvalue"
                      "redirectoutput" "replace" "right" "rnd" "round" "rtrim"
                      "savekey" "sendkeys" "sendmessage" "setascii" "setconsole"
                      "setdefaultprinter" "setfileattr" "setfocus" "setoption"
                      "setsystemstate" "settitle" "setwallpaper"
                      "showprogramgroup" "shutdown" "sidtoname" "split" "srnd"
                      "substr" "trim" "ubound" "ucase" "unloadhive" "val"
                      "vartype" "vartypename" "writeline" "writeprofilestring"
                      "writevalue")
                  symbol-end))
            (function-def
             ;; Function names cannot start with a character which wrongly
             ;; identifies the name as a label, macro, or variable.
             (seq command-function
                  (1+ whitespace)
                  (group
                   (seq (1+ (intersection user-chars (not (char ?$ ?: ?@))))
                        (0+ user-chars)))))
            (label
             (seq symbol-start ?: (1+ user-chars)))
            (macro
             ;; The real parser seems to silently discard the trailing part of a
             ;; macro name if the leading part matches an actual macro name.
             ;; Match groups are used so that the trailing part of the name can
             ;; be fontified as a warning.
             (seq (group
                   (seq ?@
                        (or "address" "build" "color" "comment" "cpu" "crlf"
                            "csd" "curdir" "date" "day" "domain" "dos" "error"
                            "fullname" "homedir" "homedrive" "homeshr"
                            "hostname" "inwin" "ipaddress0" "ipaddress1"
                            "ipaddress2" "ipaddress3" "kix" "lanroot" "ldomain"
                            "ldrive" "lm" "logonmode" "longhomedir" "lserver"
                            "maxpwage" "mdayno" "mhz" "month" "monthno" "msecs"
                            "onwow64" "pid" "primarygroup" "priv" "productsuite"
                            "producttype" "programfilesx86" "pwage" "ras"
                            "result" "rserver" "scriptdir" "scriptexe"
                            "scriptname" "serror" "sid" "site" "startdir"
                            "syslang" "ticks" "time" "tssession" "userid"
                            "userlang" "wdayno" "wksta" "wuserid" "ydayno"
                            "year")))
                  (group
                   (0+ user-chars))))
            (macro-format
             ;; Match anything which has the appearance of a macro.  An unknown
             ;; macro will evaluate to 0 so a late match against this pattern
             ;; allows the full macro syntax to be fontified as a warning.
             (seq ?@ (1+ user-chars)))
            (outline
             (or command-function
                 (seq (>= 3 (syntax \<)) (1+ whitespace))))
            (script-block-close
             (seq symbol-start
                  (or "case" "else" "endif" "endfunction" "endif" "endselect"
                      "loop" "next" "until")
                  symbol-end))
            (script-block-open
             (seq symbol-start
                  (or "do" "case" "else" "for" "function" "if" "select" "while")
                  symbol-end))
            (user-chars
             ;; Valid characters for user defined names (functions, labels,
             ;; variables) are effectively defined by which characters in the
             ;; printable ASCII range have not been used for other purposes.
             (or (char (?0 . ?9))
                 (char (?a . ?z))
                 (char ?! ?# ?% ?: ?\\ ?_ ?` ?{ ?})))
            (variable
             ;; "$" is a valid variable name and all but the last $ character in
             ;; a repeated sequence will be evaluated as values.

             ;;   "$ = 1" assigns 1 to the variable $
             ;;  "$$ = 2" evaluates $ and then assigns it a new value of 2
             ;; "$$$ = 3" evaluates $ twice and then assigns it a new value of 3
             (seq ?$ (0+ user-chars))))
     (rx ,@regexps)))

;;;; Utility

(defun kixtart--in-comment-or-string-p (&optional ppss)
  "Return a non-nil value when inside a comment or string.
Prefer existing parser state PPSS over calling `syntax-ppss'"
  (nth 8 (or ppss (syntax-ppss))))

(defun kixtart--paren-depth (&optional ppss)
  "Return the current parentheses depth.
Prefer existing parser state PPSS over calling `syntax-ppss'."
  (car (or ppss (syntax-ppss))))

(defun kixtart--match-string-as-token ()
  "Return the current `match-string' data as a syntax token."
  (intern-soft (concat "kixtart-"
                       (downcase (match-string-no-properties 0))
                       "-t")))

;;;; Motion

(defun kixtart-beginning-of-defun (&optional arg)
  "Move backwards to the beginning of a function definition.
With ARG, do it that many times.  Negative ARG means move
forwards to the ARGth following beginning of defun.

If search is successful, return t.  Success is defined to be any
successful match in ARG attempts to move.  Point ends up at the
beginning of the line where the search succeeded.  Otherwise,
return nil."
  (interactive "^p")
  (unless arg (setq arg 1))
  (let* ((forwards (< arg 0))
         (search-fn (if forwards #'re-search-forward #'re-search-backward))
         (inc-fn (if forwards #'1+ #'1-))
         (match-pos nil))
    (save-excursion
      ;; Ensure that searching forwards doesn't match the current position.
      (when (and forwards (looking-at-p (kixtart-rx command-function)))
        (forward-char 8))
      ;; Search for the arg-th FUNCTION command in the given direction.
      (while (and (not (zerop arg))
                  (funcall search-fn (kixtart-rx command-function) nil t)
                  (or (kixtart--in-comment-or-string-p)
                      (setq arg (funcall inc-fn arg) match-pos (point))))))
    ;; Ensure point is at the beginning of the match.
    (when match-pos
      (goto-char (if forwards (- match-pos 8) match-pos)))
    (not (null match-pos))))

(defun kixtart-end-of-defun ()
  "Move forwards to the end of a function definition."
  (let ((match-pos nil))
    (save-excursion
      (while (and (re-search-forward (kixtart-rx command-endfunction) nil t)
                  (or (kixtart--in-comment-or-string-p)
                      (not (setq match-pos (point)))))))
    (when match-pos
      (goto-char match-pos))
    (not (null match-pos))))

(defun kixtart-up-script-block ()
  "Move point to the opening of the current script-block.
Returns the symbol representing the command which opened the
script-block or nil if no script-block opening command was
found."
  (interactive)
  ;; Move out of strings and comments.
  (while (kixtart--in-comment-or-string-p)
    (backward-up-list nil t t))
  ;; Search backwards matching pairs of script-block defining keyword tokens.
  (let ((parse-sexp-ignore-comments t)
        (block-end nil)
        (block-start nil))
    (condition-case nil
        (while (and (not (bobp))
                    (null block-start))
          (forward-sexp -1)
          (cond ((looking-at (kixtart-rx script-block-open))
                 (let ((open-token (kixtart--match-string-as-token)))
                   ;; Try to match this current script-block opening token with
                   ;; the most recently seen script-block closing token.
                   (unless (pcase `(,open-token ,(car block-end))
                             ;; No script-block close.
                             (`(,_ nil))
                             ;; Ignore "CASE" and "ELSE" since they effectively
                             ;; close and re-open a script-block.
                             (`(,(or 'kixtart-case-t 'kixtart-else-t) ,_) t)
                             ;; Matching token pairs.
                             ((or '(kixtart-do-t       kixtart-until-t)
                                  '(kixtart-for-t      kixtart-next-t)
                                  '(kixtart-function-t kixtart-endfunction-t)
                                  `(kixtart-if-t       ,(or 'kixtart-else-t
                                                            'kixtart-endif-t))
                                  '(kixtart-select-t   kixtart-endselect-t)
                                  '(kixtart-while-t    kixtart-loop-t))
                              (pop block-end)))
                     (setq block-start open-token))))
                ((looking-at (kixtart-rx script-block-close))
                 (push (kixtart--match-string-as-token) block-end))))
      (scan-error
       (backward-up-list nil t t)))
    block-start))

;;;; Indentation

(defun kixtart--new-indent ()
  "Return the calculated indentation level for the current line."
  (save-excursion
    (back-to-indentation)
    (let ((ppss (syntax-ppss)))
      (if (kixtart--in-comment-or-string-p ppss)
          (current-column)
        (let ((paren-depth (kixtart--paren-depth ppss))
              (paren-close (looking-at-p "\\s)"))
              (line-token (and (looking-at (kixtart-rx script-block-close))
                               (kixtart--match-string-as-token)))
              ;; Move to the position where the current script-block was opened
              ;; and get the token which opened it.
              (open-with (kixtart-up-script-block)))
          (+ (current-indentation)
             (* kixtart-indent-offset
                (+
                 ;; Remove indentation which was already applied to the buffer
                 ;; position by opening parenthesis.
                 (- (kixtart--paren-depth))
                 ;; Add indentation based on parentheses.
                 (max 0 (if paren-close (1- paren-depth) paren-depth))
                 ;; Add indentation based on matching script-block tokens.
                 (pcase `(,open-with ,line-token)
                   ;; No script-block open.
                   (`(nil ,_) 0)
                   ;; A script-block open without a script-block close.
                   (`(,_ nil) 1)
                   ;; Matching token pairs. "CASE" tokens always match so that
                   ;; "CASE" and "ENDSELECT" will align with their "SELECT".
                   ((or `(,_ kixtart-case-t)
                        '(kixtart-do-t       kixtart-until-t)
                        '(kixtart-case-t     kixtart-endselect-t)
                        '(kixtart-else-t     kixtart-endif-t)
                        '(kixtart-for-t      kixtart-next-t)
                        '(kixtart-function-t kixtart-endfunction-t)
                        `(kixtart-if-t       ,(or 'kixtart-else-t
                                                  'kixtart-endif-t))
                        '(kixtart-select-t   kixtart-endselect-t)
                        '(kixtart-while-t    kixtart-loop-t))
                    0)
                   ;; Default to increasing the indentation.
                   (_ 1))))))))))

(defun kixtart-indent-line ()
  "Indent the current line to match the script-block level."
  (let ((new-indent (kixtart--new-indent)))
    (if (= new-indent (current-indentation))
        'noindent
      (indent-line-to new-indent))))

;;;; Outline mode

(defun kixtart-outline-level ()
  "Return the depth for the current outline heading."
  (if (looking-at-p (kixtart-rx command-function))
      most-positive-fixnum
    (save-excursion
      (forward-same-syntax)
      (- (current-column) 2))))

;;;; Keymap

(defvar kixtart-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "C-c C-j") 'imenu)
    (define-key map (kbd "C-c C-u") 'kixtart-up-script-block)
    map))

;;;; Syntax table

;; Note that the ? character is left as punctuation even though it is
;; technically a command.  This seems to best represent how the original parser
;; works.  "?:mylabel", "?myfunction", "?command", "?$var=1" are all valid.

(defconst kixtart-mode-syntax-table
  (let ((table (make-syntax-table)))
    ;; Add ' for string-quotes.
    (modify-syntax-entry ?' "\"" table)
    ;; Set line comment start and end.
    (modify-syntax-entry ?\; "\<" table)
    (modify-syntax-entry ?\n ">" table)
    ;; Set block comment open and close.  Nesting is not supported.
    (modify-syntax-entry ?\/ ". 14b" table)
    (modify-syntax-entry ?\* ". 23b" table)
    ;; Set punctuation.  The numeric operators * / ^ and ~ are already set.
    (modify-syntax-entry ?\+ "." table)
    (modify-syntax-entry ?\- "." table)
    (modify-syntax-entry ?\= "." table)
    (modify-syntax-entry ?\< "." table)
    (modify-syntax-entry ?\> "." table)
    (modify-syntax-entry ?\& "." table)
    (modify-syntax-entry ?\| "." table)
    ;; Set allowed symbol constituents.
    (modify-syntax-entry ?\! "_" table)
    (modify-syntax-entry ?\# "_" table)
    (modify-syntax-entry ?\$ "_" table)
    (modify-syntax-entry ?\% "_" table)
    (modify-syntax-entry ?\: "_" table)
    (modify-syntax-entry ?\@ "_" table)
    (modify-syntax-entry ?\\ "_" table)
    (modify-syntax-entry ?\_ "_" table)
    (modify-syntax-entry ?\` "_" table)
    (modify-syntax-entry ?\{ "_" table)
    (modify-syntax-entry ?\} "_" table)
    table))

;;;; Mode

;;;###autoload
(define-derived-mode kixtart-mode prog-mode "KiXtart Mode"
  "Major mode for editing KiXtart files."
  (setq mode-name "KiXtart")
  (setq-local comment-start ";")
  (setq-local font-lock-defaults
              `(((,(kixtart-rx macro)        2 font-lock-warning-face)
                 (,(kixtart-rx macro)        1 font-lock-type-face)
                 (,(kixtart-rx macro-format) . font-lock-warning-face)
                 (,(kixtart-rx function-def) 1 font-lock-function-name-face)
                 (,(kixtart-rx function)     . font-lock-builtin-face)
                 (,(kixtart-rx command)      . font-lock-keyword-face)
                 (,(kixtart-rx label)        . font-lock-constant-face)
                 (,(kixtart-rx variable)     . font-lock-variable-name-face))
                nil t))
  (setq-local beginning-of-defun-function 'kixtart-beginning-of-defun)
  (setq-local end-of-defun-function 'kixtart-end-of-defun)
  (setq-local indent-line-function 'kixtart-indent-line)
  (setq-local outline-level #'kixtart-outline-level)
  (setq-local outline-regexp (kixtart-rx outline))
  (setq imenu-create-index-function 'imenu-default-create-index-function)
  (setq imenu-generic-expression `((nil ,(kixtart-rx function-def) 1)
                                   ("/Labels" ,(kixtart-rx label) 0))))

;;;###autoload
(add-to-list 'auto-mode-alist '("\\.kix\\'" . kixtart-mode))

(provide 'kixtart-mode)
;;; kixtart-mode.el ends here
