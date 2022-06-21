;;; kixtart-mode-tests.el --- Tests for kixtart-mode -*- lexical-binding: t; -*-

;;; Commentary:

;; Tests to verify the correct operation of kixtart-mode.

;;; Code:

(require 'ert)
(require 'kixtart-mode)

;;; Tests

(ert-deftest kixtart-mode-indent-command-blocks ()
  "Increase indentation level inside commands which open blocks."
  (with-temp-buffer
    (kixtart-mode)
    (let ((text "Do
    $var = 1
    $var = 2
Until $maybe

For $i = 0 to 10
    $var = $i
Next

For Each $value in $array
    $var = $value
Next

Function
    $var = 1
    $var = 2
EndFunction

If $maybe
    $var = 1
Else
    $var = 2
EndIf

Select
Case $maybe
    $var = 1
Case $sometimes
    $var = 2
EndSelect

While $maybe
    $var = 1
Loop
"))
      (insert text)
      (indent-region (point-min) (point-max))
      (should (equal (buffer-string) text)))))

(ert-deftest kixtart-mode-indent-nested-command-blocks ()
  "Increase indentation level inside nested commands which open blocks."
  (with-temp-buffer
    (kixtart-mode)
    (let ((text "Function
    Do
        $var = 1

        For $i = 0 to 10
            $var = $i

            For Each $value in $array
                $var = 1

                If $maybe
                    $var = 1
                Else
                    Select
                    Case $maybe
                        $var = 1
                    Case $sometimes
                        While $maybe
                            $var = 1
                        Loop

                        $var = 2
                    EndSelect
                EndIf

                $var = $value
            Next
        Next

        $var = 2
    Until $maybe
EndFunction
"))
      (insert text)
      (indent-region (point-min) (point-max))
      (should (equal (buffer-string) text)))))

(ert-deftest kixtart-mode-indent-with-inline-command-blocks ()
  "Indentation level is not affected by inline command blocks."
  (with-temp-buffer
    (kixtart-mode)
    (let ((text "If $sometimes If $maybe
    $var = 1 If $always
        $var = 2
    EndIf
EndIf EndIf
"))
      (insert text)
      (indent-region (point-min) (point-max))
      (should (equal (buffer-string) text)))))

(ert-deftest kixtart-mode-indent-with-parens-inline ()
  "Increase indentation level with parens sharing a line."
  (with-temp-buffer
    (kixtart-mode)
    (let ((text "(1
    2
    3 (4
        5
        6))
"))
      (insert text)
      (indent-region (point-min) (point-max))
      (should (equal (buffer-string) text)))))

(ert-deftest kixtart-mode-indent-with-parens-outline ()
  "Increase indentation level with parens on their own line."
  (with-temp-buffer
    (kixtart-mode)
    (let ((text "(
    1
    2
    3
    (
        4
        5
        6
    )
)
"))
      (insert text)
      (indent-region (point-min) (point-max))
      (should (equal (buffer-string) text)))))

(ert-deftest kixtart-mode-indent-with-parens-mixed ()
  "Increase indentation level with parens in any position."
  (with-temp-buffer
    (kixtart-mode)
    (let ((text "(1
    2
    3
    (
        5
        6)
)
"))
      (insert text)
      (indent-region (point-min) (point-max))
      (should (equal (buffer-string) text)))))

(ert-deftest kixtart-mode-indent-ignores-string-contents ()
  "Indentation level is not affected by string contents."
  (with-temp-buffer
    (kixtart-mode)
    (let ((text "Function
    If $maybe
        $var = 'If $sometimes
If $always'
        $var = 2
    EndIf
EndFunction"))
      (insert text)
      (indent-region (point-min) (point-max))
      (should (equal (buffer-string) text)))))

(ert-deftest kixtart-mode-indent-only-considers-string-start ()
  "Indentation level for a string only applies to its starting point."
  (with-temp-buffer
    (kixtart-mode)
    (let ((text "Function
    If $maybe
        'one
two
three'
    EndIf

    'four
five
six'
EndFunction"))
      (insert text)
      (indent-region (point-min) (point-max))
      (should (equal (buffer-string) text)))))

(ert-deftest kixtart-mode-indent-ignores-single-line-comment ()
  "Indentation level is not affected by a single-line comments."
  (with-temp-buffer
    (kixtart-mode)
    (let ((text "If $maybe
    ; If $sometimes
    $var = 1
EndIf
"))
      (insert text)
      (indent-region (point-min) (point-max))
      (should (equal (buffer-string) text)))))

(ert-deftest kixtart-mode-indent-ignores-multi-line-comment ()
  "Indentation level is not affected a multi-line comment."
  (with-temp-buffer
    (kixtart-mode)
    (let ((text "If $maybe
    /*
    If $sometimes
        $var = 2
    */
    $var = 1
EndIf
"))
      (insert text)
      (indent-region (point-min) (point-max))
      (should (equal (buffer-string) text)))))

(ert-deftest kixtart-mode-parse-with-symbol-boundaries ()
  "Syntax parsing does not truncate names containing symbols."
  (with-temp-buffer
    (kixtart-mode)
    (let ((text "Function Function:1
    $var = 1
EndFunction

$var = 2
"))
      (insert text)
      (indent-region (point-min) (point-max))
      (should (equal (buffer-string) text)))))

(ert-deftest kixtart-mode-mixed-parens-and-commands ()
  "Syntax parsing does not truncate names containing symbols."
  (with-temp-buffer
    (kixtart-mode)
    (let ((text "(
    Do
        $var = 1
    Until $maybe

    (
        If 1
            $var = 1

            Select
            Case $maybe
                (
                    $var = 1
                )
            Case $sometimes
                (
                    $var = 0)
            Case $usually
                ($var = 0
                )
            Case 1
                ($var = 0)
            EndSelect
        Else
            (
                1 +
                2 +
                3
            )
        EndIf
    )

    While (
        $never
    )
        $var = 1
    Loop
)
"))
      (insert text)
      (indent-region (point-min) (point-max))
      (should (equal (buffer-string) text)))))

(ert-deftest kixtart-mode-select-block-no-indent ()
  "Select blocks do not increase the indentation level."
  (with-temp-buffer
    (kixtart-mode)
    (let ((text "Select
;; Select comment.
Case $maybe
    ;; Maybe comment.
    $var = 1
Case $unless
    ;; Unless comment.
Case 1
    ;; Default comment.
    $var = 2
EndSelect
"))
      (insert text)
      (indent-region (point-min) (point-max))
      (should (equal (buffer-string) text)))))

;;; kixtart-mode-tests.el ends here
