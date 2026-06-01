;;; ob-php.el --- Org-Babel support for PHP -*- lexical-binding: t; -*-

(require 'org-macs)
(org-assert-version)

(require 'ob)
(require 'ob-eval)

(defvar org-babel-tangle-lang-exts)
(add-to-list 'org-babel-tangle-lang-exts '("php" . "php"))

(defvar org-babel-default-header-args:php
  '((:results . "output")
    (:exports . "results"))
  "Default header arguments for PHP source blocks.")

(defcustom org-babel-php-command "php"
  "Name of the command to use for executing PHP code."
  :group 'org-babel
  :type 'string)

(defcustom org-babel-php-hline-to "null"
  "Replace hlines in incoming tables with this when translating to PHP."
  :group 'org-babel
  :type 'string)

(defcustom org-babel-php-nil-to 'hline
  "Replace nil in PHP tables with this before returning."
  :group 'org-babel
  :type 'symbol)

(defun org-babel-execute:php (body params)
  "Execute PHP BODY according to PARAMS.
This function is called by `org-babel-execute-src-block'."
  (let* ((result-params (cdr (assq :result-params params)))
         (result-type (cdr (assq :result-type params)))
         (org-babel-php-command (or (cdr (assq :php params)) org-babel-php-command))
         (full-body (org-babel-expand-body:generic
                     body params (org-babel-variable-assignments:php params)))
         (results (org-babel-php-evaluate full-body result-type result-params)))
    (org-babel-reassemble-table
     (org-babel-result-cond result-params
       results
       (org-babel-php-table-or-string results))
     (org-babel-pick-name (cdr (assq :colname-names params))
                          (cdr (assq :colnames params)))
     (org-babel-pick-name (cdr (assq :rowname-names params))
                          (cdr (assq :rownames params))))))

(defun org-babel-prep-session:php (_session _params)
  "Prepare a PHP session.

Org Babel PHP blocks currently do not support sessions."
  (error "Org Babel PHP does not support sessions"))

(defun org-babel-variable-assignments:php (params)
  "Return a list of PHP statements assigning variables from PARAMS."
  (mapcar
   (lambda (pair)
     (format "$%s = %s;" (car pair) (org-babel-php-var-to-php (cdr pair))))
   (org-babel--get-vars params)))

(defun org-babel-php-var-to-php (var)
  "Convert VAR into a string of PHP source code representing VAR."
  (cond
   ((eq var 'hline) org-babel-php-hline-to)
   ((null var) "null")
   ((numberp var) (number-to-string var))
   ((eq var t) "true")
   ((stringp var) (org-babel-php--quote-string var))
   ((and (listp var) (org-babel-php--alist-p var))
    (concat "["
            (mapconcat
             (lambda (cell)
               (format "%s => %s"
                       (org-babel-php-var-to-php (car cell))
                       (org-babel-php-var-to-php (cdr cell))))
             var ", ")
            "]"))
   ((listp var)
    (concat "["
            (mapconcat #'org-babel-php-var-to-php var ", ")
            "]"))
   (t (org-babel-php--quote-string (format "%s" var)))))

(defun org-babel-php--alist-p (value)
  (and (listp value)
       (catch 'not-alist
         (dolist (el value t)
           (unless (consp el) (throw 'not-alist nil))))))

(defun org-babel-php--quote-string (s)
  (concat "'"
          (replace-regexp-in-string
           "['\\\\]"
           (lambda (m) (concat "\\\\" m))
           s
           t t)
          "'"))

(defun org-babel-php-evaluate (body result-type result-params)
  "Evaluate PHP BODY and return results according to RESULT-TYPE and RESULT-PARAMS."
  (let* ((tmp-file (org-babel-temp-file "php-" ".php"))
         (wrapper (org-babel-php--wrap body result-type result-params))
         (command (format "%s %s"
                          org-babel-php-command
                          (org-babel-process-file-name tmp-file))))
    (with-temp-file tmp-file (insert wrapper))
    (org-babel-eval command "")))

(defun org-babel-php--wrap (body result-type _result-params)
  (let ((value? (eq result-type 'value)))
    (concat
     "<?php\n"
     "error_reporting(E_ALL);\n"
     "ini_set('display_errors', '1');\n"
     "ini_set('log_errors', '0');\n"
     "\n"
     (org-babel-php--strip-tags (org-babel-chomp body))
     "\n"
     (when value?
       (concat
        "\n"
        "if (isset($result)) {\n"
        "  if (is_array($result) || is_object($result)) {\n"
        "    echo json_encode($result);\n"
        "  } else {\n"
        "    echo $result;\n"
        "  }\n"
        "}\n"))
     "?>\n")))

(defun org-babel-php--strip-tags (body)
  "Return BODY with any surrounding PHP open/close tags removed.

This allows blocks to be written either as raw PHP statements, or with
explicit `<?php ... ?>` tags, without producing nested tags when wrapped."
  (let ((s body))
    ;; Drop a leading BOM if present.
    (setq s (replace-regexp-in-string "\\`\\ufeff" "" s t t))
    ;; Remove opening tag: allow `<?php` or short `<?`.
    (setq s (replace-regexp-in-string "\\`[[:space:]\n\r\t]*<\\?\\(?:php\\)?[[:space:]\n\r\t]*" "" s))
    ;; Remove closing tag, but only if it's at the end (ignoring whitespace).
    (setq s (replace-regexp-in-string "[[:space:]\n\r\t]*\\?>[[:space:]\n\r\t]*\\'" "" s))
    s))

(defun org-babel-php-table-or-string (results)
  "Convert RESULTS into an appropriate elisp value.
If RESULTS look like an Org table, return it as a table.  Otherwise
return a string."
  (let ((res (org-babel-script-escape results)))
    (if (listp res)
        (mapcar (lambda (el) (if (not el) org-babel-php-nil-to el)) res)
      res)))

(provide 'ob-php)

;;; ob-php.el ends here
