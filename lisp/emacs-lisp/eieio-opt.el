;;; eieio-opt.el -- eieio optional functions (debug, printing, speedbar)

;; Copyright (C) 1996, 1998-2003, 2005, 2008-2015 Free Software
;; Foundation, Inc.

;; Author: Eric M. Ludlam <zappo@gnu.org>
;; Keywords: OO, lisp
;; Package: eieio

;; This file is part of GNU Emacs.

;; GNU Emacs is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; GNU Emacs is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:
;;
;;   This contains support functions to eieio.  These functions contain
;; some small class browser and class printing functions.
;;

(require 'eieio)
(require 'find-func)
(require 'speedbar)
(require 'help-mode)

;;; Code:
;;;###autoload
(defun eieio-browse (&optional root-class)
  "Create an object browser window to show all objects.
If optional ROOT-CLASS, then start with that, otherwise start with
variable `eieio-default-superclass'."
  (interactive (if current-prefix-arg
		   (list (read (completing-read "Class: "
						(eieio-build-class-alist)
						nil t)))
		 nil))
  (if (not root-class) (setq root-class 'eieio-default-superclass))
  (cl-check-type root-class class)
  (display-buffer (get-buffer-create "*EIEIO OBJECT BROWSE*") t)
  (with-current-buffer (get-buffer "*EIEIO OBJECT BROWSE*")
    (erase-buffer)
    (goto-char 0)
    (eieio-browse-tree root-class "" "")
    ))

(defun eieio-browse-tree (this-root prefix ch-prefix)
  "Recursively draw the children of the given class on the screen.
Argument THIS-ROOT is the local root of the tree.
Argument PREFIX is the character prefix to use.
Argument CH-PREFIX is another character prefix to display."
  (cl-check-type this-root class)
  (let ((myname (symbol-name this-root))
	(chl (eieio--class-children (eieio--class-v this-root)))
	(fprefix (concat ch-prefix "  +--"))
	(mprefix (concat ch-prefix "  |  "))
	(lprefix (concat ch-prefix "     ")))
    (insert prefix myname "\n")
    (while (cdr chl)
      (eieio-browse-tree (car chl) fprefix mprefix)
      (setq chl (cdr chl)))
    (if chl
	(eieio-browse-tree (car chl) fprefix lprefix))
    ))

;;; CLASS COMPLETION / DOCUMENTATION

;;;###autoload
(defun eieio-help-class (class)
  "Print help description for CLASS.
If CLASS is actually an object, then also display current values of that object."
  ;; Header line
  (prin1 class)
  (insert " is a"
	  (if (eieio--class-option (eieio--class-v class) :abstract)
	      "n abstract"
	    "")
	  " class")
  (let ((location (find-lisp-object-file-name class 'eieio-defclass)))
    (when location
      (insert " in `")
      (help-insert-xref-button
       (help-fns-short-filename location)
       'eieio-class-def class location 'eieio-defclass)
      (insert "'")))
  (insert ".\n")
  ;; Parents
  (let ((pl (eieio-class-parents class))
	cur)
    (when pl
      (insert " Inherits from ")
      (while (setq cur (pop pl))
	(setq cur (eieio--class-symbol cur))
	(insert "`")
	(help-insert-xref-button (symbol-name cur)
				 'help-function cur)
	(insert (if pl "', " "'")))
      (insert ".\n")))
  ;; Children
  (let ((ch (eieio-class-children class))
	cur)
    (when ch
      (insert " Children ")
      (while (setq cur (pop ch))
	(insert "`")
	(help-insert-xref-button (symbol-name cur)
				 'help-function cur)
	(insert (if ch "', " "'")))
      (insert ".\n")))
  ;; System documentation
  (let ((doc (documentation-property class 'variable-documentation)))
    (when doc
      (insert "\n" doc "\n\n")))
  ;; Describe all the slots in this class.
  (eieio-help-class-slots class)
  ;; Describe all the methods specific to this class.
  (let ((generics (eieio-all-generic-functions class)))
    (when generics
      (insert (propertize "Specialized Methods:\n\n" 'face 'bold))
      (dolist (generic generics)
        (insert "`")
        (help-insert-xref-button (symbol-name generic) 'help-function generic)
        (insert "'")
	(pcase-dolist (`(,qualifiers ,args ,doc)
                       (eieio-method-documentation generic class))
          (insert (format " %s%S\n" qualifiers args)
                  (or doc "")))
	(insert "\n\n")))))

(defun eieio-help-class-slots (class)
  "Print help description for the slots in CLASS.
Outputs to the current buffer."
  (let* ((cv (eieio--class-v class))
	 (docs   (eieio--class-public-doc cv))
	 (names  (eieio--class-public-a cv))
	 (deflt  (eieio--class-public-d cv))
	 (types  (eieio--class-public-type cv))
	 (publp (eieio--class-public-printer cv))
	 (i      0)
	 (prot   (eieio--class-protection cv))
	 )
    (insert (propertize "Instance Allocated Slots:\n\n"
			'face 'bold))
    (while names
      (insert
       (concat
	(when (car prot)
	  (propertize "Private " 'face 'bold))
	(propertize "Slot: " 'face 'bold)
	(prin1-to-string (car names))
	(unless (eq (aref types i) t)
	  (concat "    type = "
		  (prin1-to-string (aref types i))))
	(unless (eq (car deflt) eieio-unbound)
	  (concat "    default = "
		  (prin1-to-string (car deflt))))
	(when (car publp)
	  (concat "    printer = "
		  (prin1-to-string (car publp))))
	(when (car docs)
	  (concat "\n  " (car docs) "\n"))
	"\n"))
      (setq names (cdr names)
	    docs (cdr docs)
	    deflt (cdr deflt)
	    publp (cdr publp)
	    prot (cdr prot)
	    i (1+ i)))
    (setq docs  (eieio--class-class-allocation-doc cv)
	  names (eieio--class-class-allocation-a cv)
	  types (eieio--class-class-allocation-type cv)
	  i     0
	  prot  (eieio--class-class-allocation-protection cv))
    (when names
      (insert (propertize "\nClass Allocated Slots:\n\n" 'face 'bold)))
    (while names
      (insert
       (concat
	(when (car prot)
	  "Private ")
	"Slot: "
	(prin1-to-string (car names))
	(unless (eq (aref types i) t)
	  (concat "    type = "
		  (prin1-to-string (aref types i))))
	(condition-case nil
	    (let ((value (eieio-oref class (car names))))
	      (concat "   value = "
		      (prin1-to-string value)))
	  (error nil))
	(when (car docs)
	  (concat "\n\n " (car docs) "\n"))
	"\n"))
      (setq names (cdr names)
	    docs (cdr docs)
	    prot (cdr prot)
	    i (1+ i)))))

(defun eieio-build-class-alist (&optional class instantiable-only buildlist)
  "Return an alist of all currently active classes for completion purposes.
Optional argument CLASS is the class to start with.
If INSTANTIABLE-ONLY is non nil, only allow names of classes which
are not abstract, otherwise allow all classes.
Optional argument BUILDLIST is more list to attach and is used internally."
  (let* ((cc (or class 'eieio-default-superclass))
	 (sublst (eieio--class-children (eieio--class-v cc))))
    (unless (assoc (symbol-name cc) buildlist)
      (when (or (not instantiable-only) (not (class-abstract-p cc)))
        ;; FIXME: Completion tables don't need alists, and ede/generic.el needs
        ;; the symbols rather than their names.
	(setq buildlist (cons (cons (symbol-name cc) 1) buildlist))))
    (dolist (elem sublst)
      (setq buildlist (eieio-build-class-alist
		       elem instantiable-only buildlist)))
    buildlist))

(defvar eieio-read-class nil
  "History of the function `eieio-read-class' prompt.")

(defun eieio-read-class (prompt &optional histvar instantiable-only)
  "Return a class chosen by the user using PROMPT.
Optional argument HISTVAR is a variable to use as history.
If INSTANTIABLE-ONLY is non nil, only allow names of classes which
are not abstract."
  (intern (completing-read prompt (eieio-build-class-alist nil instantiable-only)
			   nil t nil
			   (or histvar 'eieio-read-class))))

(defun eieio-read-subclass (prompt class &optional histvar instantiable-only)
  "Return a class chosen by the user using PROMPT.
CLASS is the base class, and completion occurs across all subclasses.
Optional argument HISTVAR is a variable to use as history.
If INSTANTIABLE-ONLY is non nil, only allow names of classes which
are not abstract."
  (intern (completing-read prompt
			   (eieio-build-class-alist class instantiable-only)
			   nil t nil
			   (or histvar 'eieio-read-class))))

;;; METHOD COMPLETION / DOC

(define-button-type 'eieio-class-def
  :supertype 'help-function-def
  'help-echo (purecopy "mouse-2, RET: find class definition"))

(defconst eieio--defclass-regexp "(defclass[ \t\r\n]+%s[ \t\r\n]+")
(with-eval-after-load 'find-func
  (defvar find-function-regexp-alist)
  (add-to-list 'find-function-regexp-alist
               `(eieio-defclass . eieio--defclass-regexp)))

;;;###autoload
(defun eieio-help-constructor (ctr)
  "Describe CTR if it is a class constructor."
  (when (class-p ctr)
    (erase-buffer)
    (let ((location (find-lisp-object-file-name ctr 'eieio-defclass))
	  (def (symbol-function ctr)))
      (goto-char (point-min))
      (prin1 ctr)
      (insert (format " is an %s object constructor function"
		      (if (autoloadp def)
			  "autoloaded"
			"")))
      (when (and (autoloadp def)
		 (null location))
	(setq location
	      (find-lisp-object-file-name ctr def)))
      (when location
	(insert " in `")
	(help-insert-xref-button
	 (help-fns-short-filename location)
	 'eieio-class-def ctr location 'eieio-defclass)
	(insert "'"))
      (insert ".\nCreates an object of class " (symbol-name ctr) ".")
      (goto-char (point-max))
      (if (autoloadp def)
	  (insert "\n\n[Class description not available until class definition is loaded.]\n")
	(save-excursion
	  (insert (propertize "\n\nClass description:\n" 'face 'bold))
	  (eieio-help-class ctr))
	))))

(defun eieio--specializers-apply-to-class-p (specializers class)
  "Return non-nil if a method with SPECIALIZERS applies to CLASS."
  (let ((applies nil))
    (dolist (specializer specializers)
      (if (memq (car-safe specializer) '(subclass eieio--static))
          (setq specializer (nth 1 specializer)))
      ;; Don't include the methods that are "too generic", such as those
      ;; applying to `eieio-default-superclass'.
      (and (not (memq specializer '(t eieio-default-superclass)))
           (class-p specializer)
           (child-of-class-p class specializer)
           (setq applies t)))
    applies))

(defun eieio-all-generic-functions (&optional class)
  "Return a list of all generic functions.
Optional CLASS argument returns only those functions that contain
methods for CLASS."
  (let ((l nil))
    (mapatoms
     (lambda (symbol)
       (let ((generic (and (fboundp symbol) (cl--generic symbol))))
         (and generic
	      (catch 'found
		(if (null class) (throw 'found t))
		(dolist (method (cl--generic-method-table generic))
		  (if (eieio--specializers-apply-to-class-p
		       (cl--generic-method-specializers method) class)
		      (throw 'found t))))
	      (push symbol l)))))
    l))

(defun eieio-method-documentation (generic class)
  "Return info for all methods of GENERIC applicable to CLASS.
The value returned is a list of elements of the form
\(QUALIFIERS ARGS DOC)."
  (let ((generic (cl--generic generic))
        (docs ()))
    (when generic
      (dolist (method (cl--generic-method-table generic))
        (when (eieio--specializers-apply-to-class-p
               (cl--generic-method-specializers method) class)
          (push (cl--generic-method-info method) docs))))
    docs))

;;; METHOD STATS
;;
;; Dump out statistics about all the active methods in a session.
(defun eieio-display-method-list ()
  "Display a list of all the methods and what features are used."
  (interactive)
  (let* ((meth1 (eieio-all-generic-functions))
	 (meth (sort meth1 (lambda (a b)
			     (string< (symbol-name a)
				      (symbol-name b)))))
	 (buff (get-buffer-create "*EIEIO Method List*"))
	 (methidx 0)
	 (standard-output buff)
	 (slots '(method-static
		  method-before
		  method-primary
		  method-after
		  method-generic-before
		  method-generic-primary
		  method-generic-after))
	 (slotn '("static"
		  "before"
		  "primary"
		  "after"
		  "G bef"
		  "G prim"
		  "G aft"))
	 (idxarray (make-vector (length slots) 0))
	 (primaryonly 0)
	 (oneprimary 0)
	 )
    (switch-to-buffer-other-window buff)
    (erase-buffer)
    (dolist (S slotn)
      (princ S)
      (princ "\t")
      )
    (princ "Method Name")
    (terpri)
    (princ "--------------------------------------------------------------------")
    (terpri)
    (dolist (M meth)
      (let ((mtree (get M 'eieio-method-tree))
	    (P nil) (numP)
	    (!P nil))
	(dolist (S slots)
	  (let ((num (length (aref mtree (symbol-value S)))))
	    (aset idxarray (symbol-value S)
		  (+ num (aref idxarray (symbol-value S))))
	    (prin1 num)
	    (princ "\t")
	    (when (< 0 num)
	      (if (eq S 'method-primary)
		  (setq P t numP num)
		(setq !P t)))
	    ))
	;; Is this a primary-only impl method?
	(when (and P (not !P))
	  (setq primaryonly (1+ primaryonly))
	  (when (= numP 1)
	    (setq oneprimary (1+ oneprimary))
	    (princ "*"))
	  (princ "* ")
	  )
	(prin1 M)
	(terpri)
	(setq methidx (1+ methidx))
	)
      )
    (princ "--------------------------------------------------------------------")
    (terpri)
    (dolist (S slots)
      (prin1 (aref idxarray (symbol-value S)))
      (princ "\t")
      )
    (prin1 methidx)
    (princ " Total symbols")
    (terpri)
    (dolist (S slotn)
      (princ S)
      (princ "\t")
      )
    (terpri)
    (terpri)
    (princ "Methods Primary Only: ")
    (prin1 primaryonly)
    (princ "\t")
    (princ (format "%d" (* (/ (float primaryonly) (float methidx)) 100)))
    (princ "% of total methods")
    (terpri)
    (princ "Only One Primary Impl: ")
    (prin1 oneprimary)
    (princ "\t")
    (princ (format "%d" (* (/ (float oneprimary) (float primaryonly)) 100)))
    (princ "% of total primary methods")
    (terpri)
    ))

;;; SPEEDBAR SUPPORT
;;

(defvar eieio-class-speedbar-key-map nil
  "Keymap used when working with a project in speedbar.")

(defun eieio-class-speedbar-make-map ()
  "Make a keymap for EIEIO under speedbar."
  (setq eieio-class-speedbar-key-map (speedbar-make-specialized-keymap))

  ;; General viewing stuff
  (define-key eieio-class-speedbar-key-map "\C-m" 'speedbar-edit-line)
  (define-key eieio-class-speedbar-key-map "+" 'speedbar-expand-line)
  (define-key eieio-class-speedbar-key-map "-" 'speedbar-contract-line)
  )

(if eieio-class-speedbar-key-map
    nil
  (if (not (featurep 'speedbar))
      (add-hook 'speedbar-load-hook (lambda ()
				      (eieio-class-speedbar-make-map)
				      (speedbar-add-expansion-list
				       '("EIEIO"
					 eieio-class-speedbar-menu
					 eieio-class-speedbar-key-map
					 eieio-class-speedbar))))
    (eieio-class-speedbar-make-map)
    (speedbar-add-expansion-list '("EIEIO"
				   eieio-class-speedbar-menu
				   eieio-class-speedbar-key-map
				   eieio-class-speedbar))))

(defvar eieio-class-speedbar-menu
  ()
  "Menu part in easymenu format used in speedbar while in `eieio' mode.")

(defun eieio-class-speedbar (_dir-or-object _depth)
  "Create buttons in speedbar that represents the current project.
DIR-OR-OBJECT is the object to expand, or nil, and DEPTH is the
current expansion depth."
  (when (eq (point-min) (point-max))
    ;; This function is only called once, to start the whole deal.
    ;; Create and expand the default object.
    (eieio-class-button 'eieio-default-superclass 0)
    (forward-line -1)
    (speedbar-expand-line)))

(defun eieio-class-button (class depth)
  "Draw a speedbar button at the current point for CLASS at DEPTH."
  (cl-check-type class class)
  (let ((subclasses (eieio--class-children (eieio--class-v class))))
    (if subclasses
	(speedbar-make-tag-line 'angle ?+
				'eieio-sb-expand
				class
				(symbol-name class)
				'eieio-describe-class-sb
				class
				'speedbar-directory-face
				depth)
      (speedbar-make-tag-line 'angle ?  nil nil
			      (symbol-name class)
			      'eieio-describe-class-sb
			      class
			      'speedbar-directory-face
			      depth))))

(defun eieio-sb-expand (text class indent)
  "For button TEXT, expand CLASS at the current location.
Argument INDENT is the depth of indentation."
  (cond ((string-match "+" text)	;we have to expand this file
	 (speedbar-change-expand-button-char ?-)
	 (speedbar-with-writable
	   (save-excursion
	     (end-of-line) (forward-char 1)
	     (let ((subclasses (eieio--class-children (eieio--class-v class))))
	       (while subclasses
		 (eieio-class-button (car subclasses) (1+ indent))
		 (setq subclasses (cdr subclasses)))))))
	((string-match "-" text)	;we have to contract this node
	 (speedbar-change-expand-button-char ?+)
	 (speedbar-delete-subblock indent))
	(t (error "Ooops...  not sure what to do")))
  (speedbar-center-buffer-smartly))

(defun eieio-describe-class-sb (_text token _indent)
  "Describe the class TEXT in TOKEN.
INDENT is the current indentation level."
  (dframe-with-attached-buffer
   (describe-function token))
  (dframe-maybee-jump-to-attached-frame))

(provide 'eieio-opt)

;; Local variables:
;; generated-autoload-file: "eieio.el"
;; End:

;;; eieio-opt.el ends here
