;;; ob-d-test.el --- Tests for ob-d.el -*- lexical-binding: t; -*-

(require 'ert)
(require 'ob-d)

(ert-deftest org-babel-d-module-name-sanitizes-invalid-filename-chars ()
  (should (equal "d_3OcMI3"
                 (org-babel-d--module-name "/tmp/babel-XQCtbm/d-3OcMI3.d"))))

(ert-deftest org-babel-d-module-name-prefixes-leading-digits ()
  (should (equal "_123abc"
                 (org-babel-d--module-name "/tmp/123abc.d"))))

(ert-deftest org-babel-d-expand-body-uses-sanitized-module-name ()
  (let ((expanded (org-babel-expand-body:d "writeln(\"Hello\");"
                                           '((:imports . ("std.stdio")))
                                           "/tmp/babel-XQCtbm/d-3OcMI3.d")))
    (should (string-match-p "^module d_3OcMI3;" expanded))
    (should (string-match-p "import std\\.stdio;" expanded))
    (should (string-match-p "void main() {" (replace-regexp-in-string "\n" " " expanded)))))

(ert-deftest org-babel-d-execute-wraps-body-in-main ()
  (skip-unless (executable-find org-babel-d-compiler))
  (should (equal "Hello, World!\n"
                 (org-babel-execute:d "writeln(\"Hello, World!\");"
                                      '((:results . "output"))))))

;;; ob-d-test.el ends here
