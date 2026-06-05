;;; ob-d.el --- Org-Babel support for D -*- lexical-binding: t; -*-

(require 'org-macs)
(org-assert-version)

(require 'ob)
(require 'ob-eval)

(defvar org-babel-tangle-lang-exts)
(add-to-list 'org-babel-tangle-lang-exts '("d" . "d"))

(defvar org-babel-default-header-args:d
  '((:results . "output")
    (:exports . "results"))
  "Default header arguments for D source blocks.")

(defcustom org-babel-d-command "dmd"
  "Name of the command to use for executing D code."
  :group 'org-babel
  :type 'string)

(defcustom org-babel-d-hline-to "null"
  "Replace hlines in incoming tables with this when translating to D."
  :group 'org-babel
  :type 'string)

(defcustom org-babel-d-nil-to 'hline
  "Replace nil in D tables with this before returning."
  :group 'org-babel
  :type 'symbol)

(defun org-babel-execute:d (body params)
  "Execute D BODY according to PARAMS.
This function is called by `org-babel-execute-src-block'."
  (let* ((result-params (cdr (assq :result-params params)))
         (result-type (cdr (assq :result-type params)))
         (org-babel-d-command (or (cdr (assq :d params)) org-babel-d-command))
         (full-body (org-babel-expand-body:generic
                     body params (org-babel-variable-assignments:d params)))
         (results (org-babel-d-evaluate full-body result-type result-params)))
    (org-babel-reassemble-table
     (org-babel-result-cond result-params
       results
       (org-babel-d-table-or-string results))
     (org-babel-pick-name (cdr (assq :colname-names params))
                          (cdr (assq :colnames params)))
     (org-babel-pick-name (cdr (assq :rowname-names params))
                          (cdr (assq :rownames params))))))

(defun org-babel-prep-session:d (_session _params)
  "Prepare a D session.

Org Babel D blocks currently do not support sessions."
  (error "Org Babel D does not support sessions"))

(defun org-babel-variable-assignments:d (params)
  "Return a list of D statements assigning variables from PARAMS."
  (mapcar
   (lambda (pair)
     (format "auto %s = %s;" (car pair) (org-babel-d-var-to-d (cdr pair))))
   (org-babel--get-vars params)))

(defun org-babel-d-var-to-d (var)
  "Convert VAR into a string of D source code representing VAR."
  (cond
   ((eq var 'hline) org-babel-d-hline-to)
   ((null var) "null")
   ((numberp var) (number-to-string var))
   ((eq var t) "true")
   ((stringp var) (org-babel-d--quote-string var))
   ((and (listp var) (org-babel-d--alist-p var))
    (concat "["
            (mapconcat
             (lambda (cell)
               (format "%s: %s"
                       (org-babel-d-var-to-d (car cell))
                       (org-babel-d-var-to-d (cdr cell))))
             var ", ")
            "]"))
   ((listp var)
    (concat "["
            (mapconcat #'org-babel-d-var-to-d var ", ")
            "]"))
   (t (org-babel-d--quote-string (format "%s" var)))))

(defun org-babel-d--alist-p (value)
  (and (listp value)
       (catch 'not-alist
         (dolist (el value t)
           (unless (consp el) (throw 'not-alist nil))))))

(defun org-babel-d--quote-string (s)
  (concat "\""
          (replace-regexp-in-string
           "[\"\\\\\n\r\t]"
           (lambda (m)
             (pcase m
               ("\n" "\\n")
               ("\r" "\\r")
               ("\t" "\\t")
               (_ (concat "\\" m))))
           s
           t t)
          "\""))

(defun org-babel-d-evaluate (body result-type _result-params)
  "Evaluate D BODY and return results according to RESULT-TYPE."
  (let* ((tmp-file (org-babel-temp-file "d-" ".d"))
         (wrapper (org-babel-d--wrap body result-type))
         (command (format "%s -run %s"
                          org-babel-d-command
                          (org-babel-process-file-name tmp-file))))
    (with-temp-file tmp-file (insert wrapper))
    (org-babel-eval command "")))

(defun org-babel-d--wrap (body result-type)
  (let ((value? (eq result-type 'value)))
    (concat
     "import std.stdio;\n"
     "\n"
     "void main() {\n"
     (org-babel-d--indent (org-babel-chomp body) 2)
     "\n"
     (when value?
       (concat
        "\n"
        "  static if (__traits(compiles, result)) {\n"
        "    write(result);\n"
        "  }\n"))
     "}\n")))

(defun org-babel-d--indent (body spaces)
  "Indent each line of BODY by SPACES."
  (let ((prefix (make-string spaces ?\s)))
    (mapconcat
     (lambda (line) (concat prefix line))
     (split-string body "\n" nil)
     "\n")))

(defun org-babel-d-table-or-string (results)
  "Convert RESULTS into an appropriate elisp value.
If RESULTS look like an Org table, return it as a table. Otherwise
return a string."
  (let ((res (org-babel-script-escape results)))
    (if (listp res)
        (mapcar (lambda (el) (if (not el) org-babel-d-nil-to el)) res)
      res)))

(provide 'ob-d)

;;; ob-d.el ends here
