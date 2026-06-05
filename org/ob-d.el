;;; ob-d.el --- Babel Functions for D -*- lexical-binding: t; -*-

(require 'ob)
(require 'org-macs)

(defgroup org-babel-d nil
  "Org Babel support for D."
  :group 'org-babel)

(defcustom org-babel-d-compiler "ldc2"
  "Command used to compile D source code."
  :group 'org-babel-d
  :type 'string)

(defvar org-babel-default-header-args:d '())

(add-to-list 'org-babel-tangle-lang-exts '("d" . "d"))

(defun org-babel-execute:d (body params)
  "Execute D BODY according to PARAMS."
  (let* ((src-file (org-babel-temp-file "ob_d_" ".d"))
         (bin-file (org-babel-temp-file "ob_d_bin_" org-babel-exeext))
         (cmdline (cdr (assq :cmdline params)))
         (flags (cdr (assq :flags params)))
         (full-body (org-babel-expand-body:d body params src-file)))
    (with-temp-file src-file
      (insert full-body))
    (org-babel-eval
     (format "%s -of=%s %s %s"
             org-babel-d-compiler
             (org-babel-process-file-name bin-file)
             (mapconcat #'identity
                        (delq nil (if (listp flags) flags (list flags)))
                        " ")
             (org-babel-process-file-name src-file))
     "")
    (org-babel-eval
     (concat
      (org-babel-process-file-name bin-file)
      (if cmdline (concat " " cmdline) ""))
     "")))

(defun org-babel-expand-body:d (body params &optional src-file)
  "Expand D BODY according to PARAMS.
When SRC-FILE is non-nil, derive the module name from it."
  (let* ((imports (cdr (assq :imports params)))
         (imports (if (stringp imports) (split-string imports) imports))
         (module-name (org-babel-d--module-name src-file)))
    (mapconcat
     #'identity
     (delq
      nil
      (list
       (format "module %s;" module-name)
       (mapconcat (lambda (imp) (format "import %s;" imp))
                  (delete-dups (append imports '("std.stdio")))
                  "\n")
       (org-babel-d--ensure-main body)))
     "\n\n")))

(defun org-babel-d--module-name (&optional src-file)
  "Return a valid D module name for SRC-FILE."
  (let* ((base (file-name-base (or src-file buffer-file-name "ob_d_tmp")))
         (name (replace-regexp-in-string "[^[:alnum:]_]" "_" base)))
    (if (string-match-p "\\`[[:digit:]]" name)
        (concat "_" name)
      name)))

(defun org-babel-d--ensure-main (body)
  "Wrap BODY in `main' if needed."
  (if (string-match-p "^[[:space:]\n\r]*\\(void\\|int\\)[[:space:]\n\r]+main[[:space:]]*(" body)
      body
    (format "void main() {\n%s\n}" body)))

(provide 'ob-d)

;;; ob-d.el ends here
