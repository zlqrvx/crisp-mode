;;; crisp-mode.el --- A major mode for interacting with the crisp language  -*- lexical-binding: t; -*-

;; Copyright (C) 2024  Mark Walker

;; Author: Mark Walker;;; crisp-mode.el --- sample major mode for editing crisp. -*- coding: utf-8; lexical-binding: t; -*- <zlqrvx@zlqrvx-laptop>
;; Keywords: languages

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; 

;;; Code:


(defvar crisp-keywords nil "crisp keywords")
(setq crisp-keywords '("defun" "let" "in" "if" "else" "elif"))

;; (defvar crisp-types nil "lsl types")
;; (setq crisp-types '("float" "integer" "key" "list" "rotation" "string" "vector"))

;; (defvar crisp-constants nil "lsl constants")
;; (setq crisp-constants '("ACTIVE" "AGENT" "ALL_SIDES" "ATTACH_BACK"))

;; (defvar crisp-events nil "lsl events")
;; (setq crisp-events '("state_entry" "touch_start" "attach"))

(defvar crisp-functions nil "crisp functions")
(setq crisp-functions '("print" "declare"))

(defvar crisp-fontlock nil "list for font-lock-defaults")
(setq crisp-fontlock
      (let (xkeywords-regex xtypes-regex xconstants-regex xevents-regex)

        ;; generate regex for each category of keywords
        (setq xkeywords-regex (regexp-opt crisp-keywords 'words))
        ;; (setq xtypes-regex (regexp-opt crisp-types 'words))
        ;; (setq xconstants-regex (regexp-opt crisp-constants 'words))
        ;; (setq xevents-regex (regexp-opt crisp-events 'words))
        (setq xfunctions-regex (regexp-opt crisp-functions 'words))

        ;; note: order matters, because once colored, that part won't change. In general, put longer words first
        (list (cons "#.*$" 'font-lock-comment-face)
	      ;; (cons xtypes-regex 'font-lock-type-face)
              ;; (cons xconstants-regex 'font-lock-constant-face)
              ;; (cons xevents-regex 'font-lock-builtin-face)
              (cons xfunctions-regex 'font-lock-function-name-face)
              (cons xkeywords-regex 'font-lock-keyword-face))))

(defvar crisp-cli-file-path "crisp"
  "Path to the program used by `run-crisp'")

(defvar crisp-cli-arguments '()
  "Commandline arguments to pass to `crisp-cli'.")

(defvar crips-mode-map
  (let ((map (nconc (make-sparse-keymap) comint-mode-map)))
    ;; example definition
    (define-key map "\t" 'completion-at-point)
    map)
  "Basic mode map for `run-crisp'.")

(defvar crisp-prompt-regexp "^\\(>\\)"
  "Prompt for `run-crisp'.")

(defvar crisp-buffer-name "*crisp*"
  "Name of the buffer to use for the `run-crisp' comint instance.")

(defvar inferior-crisp-buffer nil "inferior crisp buffer")
(defvar inferior-crisp-process nil "inferior crisp process")

(defun run-crisp ()
  "Run an inferior instance of `crisp-cli' inside Emacs."
  (interactive)
  (let* ((crisp-program crisp-cli-file-path)
         (buffer (get-buffer-create crisp-buffer-name))
         (proc-alive (comint-check-proc buffer))
         (process (get-buffer-process buffer)))
    (setq inferior-crisp-buffer buffer)
    ;; if the process is dead then re-create the process and reset the
    ;; mode.
    (unless proc-alive
      (with-current-buffer buffer
	(setq inferior-crisp-process
	      (comint-exec buffer "Crisp" crisp-program nil crisp-cli-arguments))
        ;; (apply 'make-comint-in-buffer "Crisp" buffer
        ;;        crisp-program nil crisp-cli-arguments)
        (inferior-crisp-mode)))
    ;; Regardless, provided we have a valid buffer, we pop to it.
    (when buffer
      (pop-to-buffer buffer))))

(defun crisp--initialize ()
  "Helper function to initialize Crisp."
  (setq comint-process-echoes t)
  (setq comint-use-prompt-regexp t))

(define-derived-mode inferior-crisp-mode comint-mode "Crisp"
  "Major mode for `run-crisp'.

\\<crisp-mode-map>"
  ;; this sets up the prompt so it matches things like: [foo@bar]
  (setq comint-prompt-regexp crisp-prompt-regexp)
  ;; this makes it read only; a contentious subject as some prefer the
  ;; buffer to be overwritable.
  (setq comint-prompt-read-only t)
  ;; this makes it so commands like M-{ and M-} work.
  (set (make-local-variable 'paragraph-separate) "\\'")
  (set (make-local-variable 'font-lock-defaults) '(crisp-font-lock-keywords t))
  (set (make-local-variable 'paragraph-start) crisp-prompt-regexp))

(add-hook 'inferior-crisp-mode-hook 'crisp--initialize)

(defconst crisp-keywords
  '("assume" "connect" "consistencylevel" "count" "create column family"
    "create keyspace" "del" "decr" "describe cluster" "describe"
    "drop column family" "drop keyspace" "drop index" "get" "incr" "list"
    "set" "show api version" "show cluster name" "show keyspaces"
    "show schema" "truncate" "update column family" "update keyspace" "use")
  "List of keywords to highlight in `crisp-font-lock-keywords'.")

(defvar crisp-font-lock-keywords
  (list
   ;; highlight all the reserved commands.
   `(,(concat "\\_<" (regexp-opt crisp-keywords) "\\_>") . font-lock-keyword-face))
  "Additional expressions to highlight in `crisp-mode'.")


(defun crisp-send-region (beg end)
  "Send current region to the inferior crisp process."
  (interactive "r")
  (let ((string (buffer-substring-no-properties beg end))
	(tmp-file "/tmp/inferior-crisp-tmp.crisp"))
    (with-temp-file tmp-file
      (insert (concat "\n" string))
      (comint-send-string inferior-crisp-process
			  (concat "library(\"" tmp-file "\")" "\n")))
    ;; (with-current-buffer inferior-crisp-buffer
    ;;   (insert-before-markers "\n")
    ;;   (comint-send-string inferior-crisp-process (concat string "\n")))
    (deactivate-mark)
    ;; (delete-file tmp-file)
    ))
  
(defun crisp-send-line (&optional arg)
  "Send current Crisp code line to the inferior Crisp process.
With positive prefix ARG, send that many lines."
  (interactive "P")
  (or arg (setq arg 1))
  (if (> arg 0)
      (save-excursion
	(let (beg end)
	  (beginning-of-line)
	  (setq beg (point))
	  (end-of-line)
	  (setq end (point))
	  (crisp-send-region beg end)))))

(defun crisp-send-buffer ()
  "Send current Crisp code line to the inferior Crisp process.
With positive prefix ARG, send that many lines."
  (interactive)
  (save-excursion
    (let (beg end)
      (goto-char (point-min))
      (setq beg (point))
      (goto-char (point-max))
      (setq end (point))
      (crisp-send-region beg end))))

(defvar crisp-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map "\C-c\C-z" #'run-crisp)
    (define-key map "\C-c\C-c" #'crisp-send-line)
    (define-key map "\C-c\C-r" #'crisp-send-region)
    (define-key map "\C-c\C-l" #'crisp-send-buffer)
    map)
  "Keymap for `crisp-mode'.")

;;;###autoload
(define-derived-mode crisp-mode prog-mode "crisp mode"
  "Major mode for editing crisp code.
Key bindings:
\\{crisp-mode-map}"

  ;; Set comment syntax
  (setq comment-start "#")

  ;; code for syntax highlighting
  (setq font-lock-defaults '((crisp-fontlock))))

(add-to-list 'auto-mode-alist '("\\.crisp\\'" . crisp-mode))



(provide 'crisp-mode)
;;; crisp-mode.el ends here
