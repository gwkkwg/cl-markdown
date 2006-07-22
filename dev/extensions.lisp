(in-package #:cl-markdown)

;; {f a0 .. an} 
;; -> eval f a0 .. an  -- where ai are strings
;; -> returns string that is inserted into document
;; -> or nil (cound do insertions itself)

;; no recursive function embeddings {date-stamp {today}}
;; keywords handled separately?

;; could use a macro
;;
;; to specify a name, arguments, etc and use that to parse. and export


(defun today ()
  (format-date "%e %B %Y" (get-universal-time)))

(defun now ()
  (format *output-stream* "~a" (format-date "%H:%M" (get-universal-time)))
  nil)

;;; ---------------------------------------------------------------------------

;; needs to add names and links too
(defun table-of-contents (phase &rest args)
  (bind ((arg1 (ignore-errors (read-from-string (string-upcase (first args)))))
         (arg2 (ignore-errors (parse-integer (second args))))
         (depth (and arg1 (eq arg1 :depth) arg2)))
    (ecase phase 
      (:parse
       (push (lambda (document)
               (add-anchors document :depth depth))
             (item-at-1 (properties *current-document*) :cleanup-functions))
       nil) 
      (:render
       (bind ((headers (collect-elements (chunks *current-document*)
                                         :filter (lambda (x) (header-p x :depth depth)))))
         (when headers
           (format *output-stream* "<div class='table-of-contents'>")
           (iterate-elements headers
                             (lambda (header)
                               (bind (((index level text)
                                       (item-at-1 (properties header) :anchor)))
                                 (format *output-stream* "<a href='#~a' title='~a'>"
                                         (make-ref index level text)
                                         (or text ""))
                                 (render-to-html header)
                                 (format *output-stream* "</a>"))))
           (format *output-stream* "</div>")))))))

;;; ---------------------------------------------------------------------------

(defun make-ref (index level text)
  (declare (ignore text))
  (format nil "~(~a-~a~)" level index))

;;; ---------------------------------------------------------------------------

(defun add-anchors (document &key depth)
  (let* ((index -1)
         (header-level nil)
         (header-indexes (nreverse
                          (collect-elements
                           (chunks document)
                           :transform
                           (lambda (chunk) 
                             (setf (item-at-1 (properties chunk) :anchor)
                                   (list index header-level
                                         (first-item (lines chunk)))))
                           :filter 
                           (lambda (chunk)
                             (incf index) 
                             (setf header-level
                                   (header-p chunk :depth depth)))))))
    (iterate-elements 
     header-indexes
     (lambda (datum)
       (bind (((index level text) datum)
              (ref (make-ref index level text)))
         (anchor :parse `(,ref ,text))
         (insert-item-at 
          (chunks document)
          (make-instance 'chunk 
            :lines `((eval anchor (,ref) nil t)))
          index))))))
    
#+(or)
(let ((*current-document* ccl:!))
  (add-anchors 1))
      
;;; ---------------------------------------------------------------------------

(defun header-p (chunk &key (depth))
  (let* ((header-elements  '(header1 header2 header3 
                             header4 header5 header6))
         (header-elements (subseq header-elements
                                  0 (min (or depth (length header-elements))
                                         (length header-elements)))))
    (some-element-p (markup-class chunk)
                    (lambda (class)
                      (member class header-elements)))))

;;; ---------------------------------------------------------------------------

(defun anchor (phase &rest args)
  (ecase phase
    (:parse
     (let ((name (caar args))
           (title (cadar args)))
       (setf (item-at (link-info *current-document*) name)
             (make-instance 'link-info
               :id name :url (format nil "#~a" name) :title (or title "")))))
    (:render (let ((name (caar args)))
               (format nil "<a name='~a' id='~a'></a>" name name)))))

;;; ---------------------------------------------------------------------------

(defun property (phase args result)
  (declare (ignore result phase))
  (if (length-at-least-p args 1)
    (bind (((name &rest args) args))
      (when args
        (warn "Extra arguments to property"))
      (document-property name))
    (warn "Not enough arguments to property (need at least 1)")))

;;; ---------------------------------------------------------------------------

(defun set-property (phase args result)
  ;; {set-property name value}
  (declare (ignore result))
  (assert (eq phase :parse))
  (if (length-at-least-p args 2)
    (bind (((name &rest value) args))
      (setf value (format nil "~{~a~^ ~}" value))
      (setf (document-property name) value))
    (warn "Not enough arguments to set-property (need at least 2)"))
  nil)


