(use srfi-1)
(use srfi-13)
(use util.list)
(use util.match)
(use file.util)
(use gauche.parseopt)
(use ginfo)

(ignore-geninfo-warning? #t)

(define-constant default-module '(gauche scheme null))
(define generated-doc-directory #f)

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
(define loaded-doc-names  '())
(define (load-info loader name update?)
  (guard (e [else #f]) ;catch all error
    (let1 loaded? (any (cut equal? <> name) loaded-doc-names)
      (if (or update? (not loaded?))
        (let1 doc (loader)
          (slot-set! doc 'name name)
          (when (not loaded?) 
            (set! loaded-doc-names (cons name loaded-doc-names)))
          (cons name doc))
        (cons name #f)))))

(define (output-order order)
  (display-std "[")
  (unless (null? order)
    (display-std "\"")
    (display-std (car order))
    (display-std "\"")
    (for-each
      (lambda (m)
        (display-std ",\"")
        (display-std m)
        (display-std "\""))
      (cdr order)))
  (display-std "]"))

(define (output-result name-and-docs)
  (let1 order-and-docs (fold
                         (lambda (d acc)
                           (cons
                             (cons (car d) (car acc))
                             (filter-cons (cdr d) (cdr acc))))
                         (cons '() '())
                         name-and-docs)
    (display-std "{")
    (display-std "\"order\":")
    (output-order (car order-and-docs))
    (display-std ",")
    (display-std "\"docs\":")
    (output-unit-list (cdr order-and-docs))
    (print-std "}")))

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

(define (filter-cons car cdr)
  (if car
    (cons car cdr)
    cdr))

;;If you have read the generated document
(define (alt-geninfo-file module)
  (let1 generated-doc-path (build-path generated-doc-directory (symbol->string module))
    (if (file-is-readable? generated-doc-path)
              generated-doc-path
              module)))

(define (parse-related-module port)
  ;;TODO
  (define (get-load-path op) (map to-abs-path *load-path*))
  (with-input-from-port
    port
    (pa$ port-fold
         (lambda (e acc)
           (filter-cons (match e
                          [(or ('use (? symbol? name) op ...) 
                             ('import ((? symbol? name) op ...)))
                           (load-info (pa$ geninfo (alt-geninfo-file name)) name #f)]
                          [('import (? symbol? name)) 
                           (load-info (pa$ geninfo (alt-geninfo-file (string->symbol name))) 
                                      (string->symbol name) #f)]
                          [('load (? string? file) op ...) 
                           (let* ([load-path (get-load-path op)]
                                  [path (find-file-in-paths (if (path-extension file)
                                                              file
                                                              (path-swap-extension file "scm"))
                                                            :paths load-path
                                                            :pred file-is-readable?)])
                             (if path
                               (load-info (pa$ geninfo path) path #f)
                               #f))]
                          ;;do nothing
                          [else #f])
                        acc))
         '()
         guarded-read)))

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
                  (output-result
                    (filter-cons
                      (load-info (pa$ geninfo-from-text texts name) name #t)
                      (parse-related-module (open-input-string texts))))
                  (set! name #f)
                  (set! texts #f)
                  )))

(define-cmd stdin
            (lambda (num) (eq? 1 num))
            (lambda (name) (cons 'read-texts (list name))))

(define-cmd load-defualt-module
            (lambda (num) (zero? num))
            (lambda ()
              (output-result 
                (filter-map
                  (lambda (m) (load-info (pa$ geninfo (alt-geninfo-file m)) m #t))
                  default-module))))

(define-cmd load-file
            (lambda (num) (and (<= 1 num) (<= num 2)))
            (lambda (file :optional name)
              (if (file-is-readable? file)
                (let1 name (if (undefined? name) file name)
                  (output-result
                    (filter-cons
                      (load-info (pa$ geninfo file) name #t)
                      (call-with-input-file file parse-related-module))))
                (output-result '()))))


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

(define-method output ((c <json-context>) (doc <doc>))
  (display-std (string-append
                 "\"name\":\"" (x->string (ref doc 'name)) "\","
                 "\"units\":"))
  (output-unit-list (ref doc 'units)))


(define-constant *json-context* (make <json-context>))
(define (output-unit-list unit-list)
  (display-std "[")
  (unless (null? unit-list)
    (display-std "{")
    (output *json-context* (car unit-list))
    (display-std "}")
    (for-each
      (lambda (u)
        (display-std ",{")
        (output *json-context* u)
        (display-std "}"))
      (cdr unit-list)))
  (display-std "]"))

;;
;;definination of initial state
(define-state init
              (lambda ())
              (lambda (line)
                (let* ([tokens (string-split line #[\s])]
                       [cmd (get-command (car tokens))])
                  (if cmd
                    (if ((cmd-valid-arg cmd) (length (cdr tokens)))
                      (apply (cmd-exec cmd) (cdr tokens))
                      (print-err "Invalid argument.")) 
                    (print-err (format #f "Unkown command [~a]." line)))))
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
  (let-args (cdr args)
    ([gdd "generated-doc-directory=s" "./doc"]
     [loaded "loaded-modules=s" '() => 
             (lambda (opt)
               (filter-map
                 (lambda (token)
                   (if (string-null? token)
                     #f
                     (let1 kind (string-ref token 0)
                       (cond
                         ([eq? #\m kind] (string->symbol (substring token 1 (string-length token))))
                         ([eq? #\f kind] (substring token 1 (string-length token)))
                         ([else (errorf "illegal token.[~S]" token)])))))
                   (string-split opt #[\s])))]
     . args)
    (set! loaded-doc-names (append loaded-doc-names loaded))
    (set! generated-doc-directory gdd) 
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
      1)))

