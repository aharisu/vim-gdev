(use srfi-1)
(use srfi-13)
(use util.list)
(use util.match)
(use file.util)
(use ginfo)

;;---------------------
;;Functions related to print
;;---------------------
(define (print-port x port)
  (for-each (cut display <> port) x)
  (newline port)
  (flush port))
(define (print-std . x) (print-port x (standard-output-port)))
(define (print-err . x) (print-port x (standard-error-port)))

(define (display-port x port)
  (for-each (cut display <> port) x))
(define (display-std . x) (display-port x (standard-output-port)))
(define (display-err . x) (display-port x (standard-error-port)))



;;---------------------
;;Functions related to state
;;---------------------
(define (do-nothing . unused) (undefined))
(define *state-list* '())
(define-macro (define-state name in exec out)
  `(set! *state-list* (acons (quote ,name)
                           (cons ,in (cons ,exec ,out))
                           *state-list*)))
(define (get-state name)
  (assoc-ref *state-list* name #f))
(define state-in car)
(define state-exec cadr) 
(define state-out cddr)


;;---------------------
;;Functions related to command
;;---------------------
(define *commands* '())
(define-macro (define-cmd cmd valid-arg exec)
  `(set! *commands* (acons (string-append "#" (symbol->string (quote ,cmd)))
                         (cons ,valid-arg ,exec)
                         *commands*)))
(define (get-command cmd)
  (assoc-ref *commands* cmd #f))
(define cmd-valid-arg car)
(define cmd-exec cdr)
(define (get-all-command)
  (cons "#exit" (map car *commands*)))

(define (variable-length-argument num) #t)



;;---------------------
;;Functions related to doccument
;;---------------------
(define *docs*  '())
(define (update-doc doc)
  (set! *docs* (cons doc
                     (remove! (lambda (d) (equal? (ref doc 'name) (ref d 'name)))
                              *docs*))))

(define (load-info loader)
  (guard (e [(<geninfo-warning> e) (print-err "Error: " (ref e 'message))])
    (update-doc (loader))))

(define (match-unit-list cmp)
  (append-map
    (lambda (doc)
      (filter
        (lambda (unit) (cmp (ref unit 'name)))
        (ref doc 'units)))
    *docs*))

(define (unit-candidate-list text)
  (match-unit-list
    (let1 len (string-length text)
      (lambda (name)
        (and (<= len (string-length name))
          (string=? text (substring name 0 len)))))))

(define (exact-match-unit-list text)
  (match-unit-list (cut string=? text <>)))

;;
;;
;;

(define (guarded-read :optional (port (current-input-port)))
  (guard (exc [(<read-error> exc) (guarded-read)])
    (read port)))

(define (to-abs-path path)
  (if (absolute-path? path)
    path
    (let1 path (expand-path path)
      (if (eq? (string-ref path 0) #\.)
        (build-path (current-directory) 
                    (if (> (string-length path) 1)
                      (substring path 2 (string-length path))
                      (substring path 1 (string-length path))))
        path))))

(define (load-from-texts texts name)
  ;;TODO
  (define (get-load-path op) (map to-abs-path *load-path*))
  (with-input-from-string 
    texts
    (pa$ port-for-each
         (lambda (e)
           (match e
             [(or ('use (? symbol? name) op ...) 
                ('import ((? symbol? name) op ...)))
              (load-info (pa$ geninfo name))]
             [('import (? symbol? name)) 
              (load-info (pa$ geninfo (string->symbol name)))]
             [('load (? string? file) op ...) 
              (let* ([load-path (get-load-path op)]
                     [path (find-file-in-paths (if (path-extension file)
                                                   file
                                                   (path-swap-extension file "scm"))
                                               :paths load-path
                                               :pred file-is-readable?)])
                (when path
                  (load-info (pa$ geninfo path))))]
             ;;do nothing
             [else #t]))
         guarded-read))
  (load-info (pa$ geninfo-from-text texts name)))

(let ([name #f]
      [texts #f])
  (define-state read-texts
                (lambda (n); enter execution
                  (set! name n)
                  (set! texts ""))
                (lambda (line)
                  (if (string=? "#stdin-eof" line)
                    (cons 'init '())
                    (set! texts (string-append texts "\n" line))))
                (lambda () ;exit execution
                  ;;load info from text
                  (load-from-texts texts name)
                  (set! name #f)
                  (set! texts #f))))

(define-cmd stdin
            (lambda (num) (eq? 1 num))
            (lambda (name)
              (cons 'read-texts (list name))))

(define-class <json-context> (<convert-context>) ())

(define (make-description description-list)
  (string-join description-list "\\n"))

(define (make-list-text accept-list)
  (string-join 
    (map (cut string-append "\"" <> "\"") accept-list)
    ","))

(define (make-params-text params)
  (string-join 
    (map
      (lambda (p)
        (string-append
          "{\"name\":\"" (param-name p) "\","
          "\"description\":\"" (make-description (param-description p)) "\","
          "\"accept\":[" (make-list-text (param-acceptable p)) "]}"))
      params)
    ","))

(define-method output ((c <json-context>) (unit <unit-top>))
  (display-std (string-append
                 "\"type\":\"" (ref unit 'type) "\","
                 "\"name\":\"" (ref unit 'name) "\","
                 "\"description\":\"" (make-description (ref unit 'description)) "\""
                 )))

(define-method output ((c <json-context>) (unit <unit-proc>))
  (next-method)
  (display-std (string-append
                 ",\"params\":[" (make-params-text (ref unit 'param)) "],"
                 "\"return\":\"" (make-description (ref unit 'return)) "\""))
  )

(define-method output ((c <json-context>) (unit <unit-class>))
  (next-method)
  (display-std (string-append
                 ",\"supers\":[" (make-list-text (ref unit 'supers))"],"
                 "\"slots\":[" (make-params-text (ref unit 'slots)) "]"))

  )

(define-constant *json-context* (make <json-context>))
(define (output-unit-list unit-list)
  (display-std "[")
  (unless (null? unit-list)
    (display-std "{")
    (output *json-context* (car unit-list))
    (display-std "}"))
  (for-each
    (lambda (u)
      (display-std ",{")
      (output *json-context* u)
      (display-std "}"))
    (cdr unit-list))
  (print-std "]"))

;;
;;definination of initial state
(define-state init
              (lambda ())
              (lambda (line)
                (if (eq? (string-ref line 0) #\#)
                  (let* ([tokens (string-split line #[\s])]
                         [cmd (get-command (car tokens))])
                    (if cmd
                      (if ((cmd-valid-arg cmd) (length (cdr tokens)))
                        (apply (cmd-exec cmd) (cdr tokens))
                        (print-err "Invalid argument.")) 
                      (print-err (format #f "Unkown command [~a]." line))))
                  (let1 units (unit-candidate-list line)
                    (if (null? units)
                      (print-err "Not found.")
                      (output-unit-list units)))))
              (lambda ()))
  

;;---------------------
;;Entry point
;;---------------------

(define *cur-state* (get-state 'init));;exection first in action
((state-in *cur-state*))
(define (exec-line line)
  (let1 result ((state-exec *cur-state*) line)
    (when (pair? result)
      ;;transition
      (cond
        [(get-state (car result))
         => (lambda (state)
              ;;exec out action
              ((state-out *cur-state*))
              ;;set new state
              (set! *cur-state* state)
              ;;exec in action
              (apply (state-in state) (cdr result)))]
        [else (error "State not found.")]))))


(define (main args)
  (unwind-protect
    (begin
      (let loop ([line (read-line)])
        (unless (eof-object? line)
          (let1 line (string-trim-both line)
            (unless (string=? line "#exit")
              (unless (zero? (string-length line))
                (exec-line line))
              (loop (read-line))))))
      0)
    1))
