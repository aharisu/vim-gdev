;;;
;;; gosh_complete
;;;
;;; MIT License
;;; Copyright 2012 aharisu
;;; All rights reserved.
;;;
;;; Permission is hereby granted, free of charge, to any person obtaining a copy
;;; of this software and associated documentation files (the "Software"), to deal
;;; in the Software without restriction, including without limitation the rights
;;; to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
;;; copies of the Software, and to permit persons to whom the Software is
;;; furnished to do so, subject to the following conditions:
;;;
;;; The above copyright notice and this permission notice shall be included in all
;;; copies or substantial portions of the Software.
;;;
;;;
;;; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
;;; IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
;;; FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
;;; AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
;;; LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
;;; OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
;;; SOFTWARE.
;;;
;;;
;;; aharisu
;;; foo.yobina@gmail.com
;;;

(use srfi-1)
(use srfi-13)
(use util.list)
(use util.match)
(use file.util)
(use gauche.parseopt)
(use gauche.charconv)
(use gauche.sequence)
(use ginfo)

(ignore-geninfo-warning? #t)

(define-constant default-module '(gauche scheme null))
(define generated-doc-directory "./doc")
(define output-full-member #f)
(define-syntax output?
  (syntax-rules ()
    [(_ text)
     (or output-full-member (not (string-null? text)))]))

(define output-name-only #f)
(define process-all-line #f)

;;---------------------
;;Functions related to print
;;---------------------

(define in-conv identity)
(define out-conv identity)

(define (print-port x port)
  (for-each (lambda (s) (display (out-conv (x->string s)) port)) x)
  (newline port)
  (flush port))
(define (print-std . x) (print-port x (standard-output-port)))
(define (print-err . x) (print-port x (standard-error-port)))

(define (display-port x port)
  (for-each (lambda (s) (display (out-conv (x->string s)) port)) x))
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
;;Functions related to load doccument
;;---------------------

(define-class <doc-extend> (<doc>)
  (
   (filestamp :init-value 0)
   ))

(define (doc->doc-extend doc name filestamp)
  (let1 ext (make <doc-extend>)
    (slot-set! ext 'filestamp filestamp)
    (slot-set! ext 'units (slot-ref doc 'units))
    (slot-set! ext 'name name)
    (slot-set! ext 'filepath (slot-ref doc 'filepath))
    (slot-set! ext 'extend (slot-ref doc 'extend))
    ext))

(define all-doc-vector (make-weak-vector 200))

(define add-to-all-doc-vector 
  (let1 next-index 0
    (lambda (name obj)
      (when (<= (weak-vector-length all-doc-vector) next-index)
        (let1 vec (make-weak-vector (truncate->exact (* 1.5 (weak-vector-length all-doc-vector))))
          (for-each-with-index
            (lambda (idx obj) (weak-vector-set! vec idx obj))
            all-doc-vector)
          (set! all-doc-vector vec)))
      (hash-table-put! all-doc-vector-index-table name next-index)
      (weak-vector-set! all-doc-vector next-index obj) 
      (inc! next-index))))

(define-constant all-doc-vector-index-table (make-hash-table 'equal?))

(define-constant loaded-doc-table (make-hash-table 'equal?))

(define (set-ginfo-unit name doc :optional (weak-only #f))
  (unless weak-only
    (hash-table-put! loaded-doc-table name doc))
  (let1 index (hash-table-get all-doc-vector-index-table name #f)
    (if index
      (weak-vector-set! all-doc-vector index doc)
      (add-to-all-doc-vector name doc))))

(define (get-doc-from-waek-vec module index)
  (let1 doc (weak-vector-ref all-doc-vector index)
    (if doc
      doc
      (let* ([alt (alt-geninfo-file module)]
             [doc (doc->doc-extend ((geninfo-with-alt module alt))
                                   module (get-filestamp alt))])
        (weak-vector-set! all-doc-vector index doc)
        doc))))

(define (get-doc module)
  (let1 sym-module (if (string? module)
                     (string->symbol module)
                     module)
    (cond
      [(or (hash-table-get loaded-doc-table sym-module #f)
         (hash-table-get loaded-doc-table module #f))
       => identity]
      [(hash-table-get all-doc-vector-index-table sym-module #f)
       => (pa$ get-doc-from-waek-vec sym-module)]
      [(hash-table-get all-doc-vector-index-table module #f)
       => (pa$ get-doc-from-waek-vec module)]
      [else 
        (let* ([alt (alt-geninfo-file module)]
               [doc (doc->doc-extend ((geninfo-with-alt module alt))
                                     module (get-filestamp alt))])
          (add-to-all-doc-vector module doc)
          doc)])))

(define (get-ginfo-unit module name)
  (let ([filter-unit (lambda (doc)
                       (filter
                         (lambda (u) 
                           (string=? (slot-ref u 'name) name))
                         (slot-ref doc 'units)))]
        [sym-module (string->symbol module)])
    (cond
      [(or (hash-table-get loaded-doc-table sym-module #f)
         (hash-table-get loaded-doc-table module #f)) 
       => filter-unit]
      [(hash-table-get all-doc-vector-index-table sym-module #f)
       => (.$ filter-unit (pa$ get-doc-from-waek-vec sym-module))]
      [(hash-table-get all-doc-vector-index-table module #f)
       => (.$ filter-unit (pa$ get-doc-from-waek-vec module))]
      [else '()])))

(define (add-loaded-module module :optional name)
  (let* ([name (if (undefined? name) module name)]
         [module (if (symbol? module) (alt-geninfo-file module) module)])
    (set-ginfo-unit name (doc->doc-extend 
                           ((geninfo-with-alt name module))
                           name (get-filestamp module)))))

(define (get-module-extend name)
  (cond
    [(hash-table-get loaded-doc-table name #f) => (cut ref <> 'extend)]
    [else '()]))

(define (guarded-read :optional (port (current-input-port)))
  (guard (exc [(or (<read-error> exc) (<error> exc)) (guarded-read)])
    (read port)))

(define (load-info loader name filestamp)
  (guard (e [else '()]) ;catch all error
    (let1 loaded-doc (hash-table-get loaded-doc-table name #f)
      ;;do not load yet, or has been updated
      (if (or (not loaded-doc) (< (slot-ref loaded-doc 'filestamp) filestamp))
        (let1 doc (doc->doc-extend (loader) name filestamp)
          (set-ginfo-unit name doc)
          (cons
            (cons name doc)
            (fold
              (lambda (m acc)
                (append
                  (load-info-from-alt-geninfo m)
                  acc))
              '()
              (ref doc 'extend))))
        (cons
          (cons name #f)
          (let loop ([extend (get-module-extend name)]
                     [acc '()])
            (if (null? extend)
              acc
              (loop (cdr extend)
                    (append
                      (cons (cons (car extend) #f) acc)
                      (loop (get-module-extend (car extend)) 
                            '()))))))
        ))))

;;If you have read the generated document
(define (alt-geninfo-file module)
  (if (symbol? module)
    (let1 generated-doc-path (build-path generated-doc-directory 
                                         (symbol->string module))
      (if (file-is-readable? generated-doc-path)
        generated-doc-path
        module))
    module))

(define (unit-top-equal? this other)
  (and (string=? (slot-ref this 'name) (slot-ref other 'name))
    (string=? (slot-ref this 'type) (slot-ref other 'type))))

(define-method unit-equal? ((this <unit-top>) other)
  #f)

(define-method unit-equal? ((this <unit-proc>) (other <unit-proc>))
  (boolean
    (and (unit-top-equal? this other)
      (= (length (slot-ref this 'param)) (length (slot-ref other 'param))))))

(define-method unit-equal? ((this <unit-var>) (other <unit-var>))
  (boolean (unit-top-equal? this other)))

(define-method unit-equal? ((this <unit-class>) (other <unit-class>))
  (boolean (unit-top-equal? this other)))

(define (merge-units units1 units2)
  (append
    (map
      (lambda (u)
        (when (<= (slot-ref u 'line) 0)
          (if-let1 u2 (find (cut unit-equal? u <>) units2)
            (slot-set! u 'line (slot-ref u2 'line))))
        u)
      units1)
    (filter
      (lambda (u) (not (any (cut unit-equal? u <>) units1)))
      units2)))



(define (not-found-garud-geninfo module)
  (guard (e 
           [(and (<geninfo-warning> e) (string=? (slot-ref e 'message) "module not found"))
            #f]
           [else e])
    (geninfo module)))

(define (geninfo-with-alt original alt)
  (if (equal? original alt)
    (pa$ geninfo original)
    (lambda ()
      (let ([org (not-found-garud-geninfo original)]
            [alt (not-found-garud-geninfo alt)])
        (cond
          [(and (is-a? org <doc>) (is-a? alt <doc>))
           (slot-set! alt 'units (merge-units (slot-ref alt 'units)
                                              (slot-ref org 'units)))
           (slot-set! alt 'filepath (slot-ref org 'filepath))
           alt]
          [(is-a? org <doc>) org]
          [(is-a? alt <doc>) alt]
          [else (raise org)])))))

(define (load-info-from-alt-geninfo name)
  (let1 alt (alt-geninfo-file name)
    (load-info (geninfo-with-alt name alt) name (get-filestamp alt))))

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

(define (get-filestamp name)
  (cond
    [(string? name) 
     (if (file-is-readable? name)
       (file-mtime name)
       (sys-time))]
    [(symbol? name) 
     (let1 path (library-fold name (lambda (l p acc) (cons p acc)) '())
       (if (null? path)
         (sys-time)
         (file-mtime (car path))))]
    [else (sys-time)]))

(define (parse-related-module basedir port)
  (let ([add-path '()]
        [find-load-file (lambda (path)
                          (cond
                            [(string-prefix? "/" path) path]
                            [(or (string-prefix? "./" path) (string-prefix? "../" path))
                             (simplify-path (build-path basedir path))]
                            [else (find-file-in-paths (if (path-extension path)
                                                        path
                                                        (path-swap-extension path "scm"))
                                                      :paths (map to-abs-path *load-path*)
                                                      :pred file-is-readable?)]))])
    (define (parse-expression e)
      (match e
        [('add-load-path (? string? path) :relative)
         (let1 path (simplify-path (build-path basedir path))
           (set! add-path (cons path add-path))
           ((with-module gauche.internal %add-load-path) path #f) 
           '())]
        [('add-load-path (? string? path))
         (set! add-path (cons path add-path))
         ((with-module gauche.internal %add-load-path) path #f) 
         '()]
        [(or ('use (? symbol? name) op ...) 
           ('import ((? symbol? name) op ...)))
         (load-info-from-alt-geninfo name)]
        [('import (? symbol? name)) 
         (load-info-from-alt-geninfo name)]
        [('load (? string? file) op ...) 
         (let1 path (find-load-file file)
           (if path
             (load-info (pa$ geninfo path) path (get-filestamp path))
             '()))]
        [('define-module (? symbol? mod) spec ...)
         (append-map
           (cut parse-expression <>)
           spec)]
        [('extend module ...)
         (append-map
           (lambda (m) (load-info-from-alt-geninfo m))
           module)]
        ;;do nothing
        [_ '()]))
    (begin0
      (with-input-from-port
        port
        (pa$ port-fold
             (lambda (e acc) (append (parse-expression e) acc))
             '()
             guarded-read))
      (set! *load-path*
        (filter
          (lambda (path) (not (any (cut string=? path <>) add-path)))
          *load-path*)))))

;;---------------------
;;Functions related to output
;;---------------------

(define (make-json-string text)
  (string-append "\""
                 (regexp-replace-all #/(\/)/ text
                                     (lambda (m) (string-append "\\" (rxmatch-substring m 1))))
                 "\""))

;;---
;;output order list
;;---
(define (output-order order)
  (display-std "[")
  (unless (null? order)
    (display-std (make-json-string (x->string (car order))))
    (for-each
      (lambda (m)
        (display-std ",")
        (display-std (make-json-string (x->string m))))
      (cdr order)))
  (display-std "]"))

;;---
;;output unit list
;;---
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
          ;; n is name
          "{\"n\":" (make-json-string (param-name p))
          (let1 desc (make-description (param-description p))
            (if (output? desc)
              ;; d is description
              (string-append ",\"d\":" (make-json-string desc))
              ""))
          (let1 accept (make-list-text (param-acceptable p))
            (if (output? accept)
              ;; a is accept
              (string-append",\"a\":[" accept "]")
              ""))
          "}"))
      params)
    ","))

(define-method output ((c <json-context>) (unit <unit-top>))
  (display-std (string-append
                 ;; t is type
                 "\"t\":\"" (cond
                              [(equal? type-fn (ref unit 'type)) "F"]
                              [(equal? type-const (ref unit 'type)) "C"]
                              [else (ref unit 'type)]) "\""
                 ;; n is name
                 ",\"n\":" (make-json-string (ref unit 'name))
                 ;; l is line
                 ",\"l\":\"" (x->string (ref unit 'line)) "\""
                 ;; d is description
                 (if output-name-only
                   ""
                   (let1 desc (make-description (ref unit 'description))
                     (if (output? desc)
                       (string-append ",\"d\":" (make-json-string desc))
                       "")))
                 )))

(define-method output ((c <json-context>) (unit <unit-proc>))
  (next-method)
  (unless output-name-only
    (display-std (string-append
                   ;; p is param
                   (let1 param (make-params-text (ref unit 'param))
                     (if (output? param)
                       (string-append ",\"p\":[" param "]")
                       ""))
                   ;; r is return
                   (let1 return (make-description (ref unit 'return))
                     (if (output? return)
                       (string-append ",\"r\":" (make-json-string return))
                       "")))))
  )

(define-method output ((c <json-context>) (unit <unit-class>))
  (next-method)
  (unless output-name-only
    (display-std (string-append
                   (let1 supers (make-list-text (ref unit 'supers))
                     (if (output? supers)
                       (string-append ",\"supers\":[" supers "]")
                       ""))
                   (let1 slots (make-params-text (ref unit 'slots))
                     (if (output? slots)
                       (string-append ",\"s\":[" slots "]")
                       "")))))
  )

(define-method output ((c <json-context>) (doc <doc>))
  (display-std (string-append
                 "\"n\":" (make-json-string (x->string (ref doc 'name)))
                 ",\"f\":" (make-json-string (x->string (ref doc 'filepath)))
                 ",\"units\":"))
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

;;---
;;output all result
;;---
(define (filter-cons car cdr)
  (if car
    (cons car cdr)
    cdr))

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


;;--------------------
;;definination of command
;;--------------------

(define-cmd stdin
            (lambda (num) (eq? 2 num))
            (lambda (basedir name) (cons 'read-texts (list basedir name))))

(define-cmd load-default-module
            (lambda (num) (zero? num))
            (lambda ()
              (output-result 
                (append-map
                  (lambda (m) (load-info-from-alt-geninfo m))
                  default-module))))

(define-cmd load-file
            (lambda (num) (<= 1 num 2))
            (lambda (file :optional name)
              (if (file-is-readable? file)
                (let1 name (if (undefined? name) file name)
                  (output-result
                    (append
                      (load-info (pa$ geninfo file) name (get-filestamp file))
                      (call-with-input-file file (pa$ parse-related-module (sys-dirname file))))))
                (output-result '()))))

(define-cmd get-unit
            (lambda (num) (eq? 2 num))
            (lambda (module symbol)
              (let1 save output-name-only
                (set! output-name-only #f)
                (unwind-protect
                  (output-unit-list (get-ginfo-unit module symbol))
                  (set! output-name-only save))
                (print-std))))

(define (all-library-names)
  (filter
    identity
    (append-map
      (lambda (s)
        (library-map
          s
          (lambda (m p) 
            (if (or (eq? m 'gauche.singleton)
                  (eq? m 'gauche.validator)
                  (eq? m 'gauche.let-opt))
              #f m))))
      '(* *.* *.*.* *.*.*.* *.*.*.*.*))))

(define load-all-symbol-continuation #f)


(define-cmd load-all-symbol
            zero?
            (lambda ()
              (cond-expand
                (gauche.os.windows
                  (let/cc escape
                    (for-each-with-index
                      (lambda (index mod)
                        (output-unit-list (cons
                                            (get-doc mod)
                                            '()))
                        (print-std)
                        (when (zero? (remainder (+ index 1) 12))
                          (let/cc resume-cont
                            ;;pause
                            (print-std "##")
                            (set! load-all-symbol-continuation resume-cont)
                            (escape))))
                      (append
                        default-module
                        (all-library-names)))
                    (print-std "#")))
                (else
                  (let/cc escape
                    (for-each
                      (.$
                        (lambda (notuse) 
                          (print-std)
                          (when (char-ready? (standard-input-port))
                            (escape)))
                        output-unit-list
                        (cut cons <> '())
                        get-doc)
                      (append
                        default-module
                        (all-library-names))))
                  (print-std "#")))))

(define-cmd resume-load-all-symbol
            zero?
            (lambda ()
              (let1 resume load-all-symbol-continuation
                (set! load-all-symbol-continuation #f)
                (if resume
                  (resume)
                  (print-err "Invalid resume.")))))

(define-cmd end-load-all-symbol
            zero?
            (lambda () 
              (set! load-all-symbol-continuation #f)))

(include "./module_description.scm")
(define-cmd load-all-module
            zero?
            (lambda ()
              (display-std "[")
              (for-each-with-index
                (lambda (idx mod)
                  (unless (zero? idx)
                    (display-std ","))
                  (display-std "{\"n\":\"" mod "\",\"d\":\""
                               (let1 d (assq mod module-description)
                                 (if d (cdr d) ""))
                               "\"}"))
                (append default-module (all-library-names)))
              (print-std "]")))

(define-cmd load-symbol-in
            (pa$ eq? 1)
            (.$
              (lambda (notuse) (print-std))
              output-unit-list
              (lambda (doc)
                (cons doc
                      (map get-doc (slot-ref doc 'extend))))
              get-doc
              string->symbol))


;;--------------------
;;definination of state
;;--------------------

(let ([save-process-all-line #f]
      [name #f]
      [basedir #f]
      [lines #f])
  (define-state read-texts
                (lambda (base n); enter execution
                  (set! save-process-all-line process-all-line)
                  (set! process-all-line #t)
                  (set! basedir base)
                  (set! name n)
                  (set! lines '()))
                (lambda (line)
                  (if (string=? "#stdin-eof" line)
                    (cons 'init '())
                    (begin
                      (set! lines (cons line lines))
                      (undefined))))
                (lambda () ;exit execution
                  (let1 text (string-join (reverse lines) "\n")
                    (output-result
                      (append
                        (load-info (pa$ geninfo-from-text text name) name (sys-time))
                        (parse-related-module basedir (open-input-string text)))))
                  (set! process-all-line save-process-all-line)
                  (set! name #f)
                  (set! lines #f)
                  )))

;;
;;definination of initial state
(define-state init
              (lambda ())
              (lambda (line)
                (let* ([tokens (string-split-space line)]
                       [cmd (get-command (car tokens))])
                  (if cmd
                    (if ((cmd-valid-arg cmd) (length (cdr tokens)))
                      (apply (cmd-exec cmd) (cdr tokens))
                      (print-err "Invalid argument.")) 
                    (print-err (format #f "Unkown command [~a]." line)))))
              (lambda ()))

(define (whitespace? ch) (or (eq? ch #\space) (eq? ch #\tab)))

(define (string-split-space text)
  (let1 in (open-input-string text)
    (let loop ([prev #f]
               [out (open-output-string)]
               [l '()])
      (let1 ch (read-char in)
        (if (eof-object? ch)
          (reverse (cons (get-output-string out) l))
          (cond
            [(whitespace? ch)
             (cond
               [(eq? prev #\\) 
                (display ch out)
                (loop ch out l)]
               [(whitespace? prev) (loop ch out l)]
               [else 
                 (loop ch (open-output-string)
                       (cons (get-output-string out) l))])]
            [(eq? ch #\\) (loop ch out l)]
            [else
              (display ch out)
              (loop ch out l)]))))))

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

(define (convert-token token)
  (let1 kind (string-ref token 0)
    (cond
      ([eq? #\m kind] (string->symbol (substring token 1 (string-length token))))
      ([eq? #\f kind] (substring token 1 (string-length token)))
      ([else (errorf "illegal token.[~S]" token)]))))

(define (main args)
  (let-args (cdr args)
    ([#f "generated-doc-directory=s" 
      => (lambda (opt) 
           (set! generated-doc-directory (string-trim-both opt)))]
     [#f "load-module=s" 
      => (lambda (opt)
           (let1 opt (string-trim-both opt)
             (unless (string-null? opt)
               (let1 module (string-split-space opt)
                 (add-loaded-module (convert-token (car module))
                                    (if (null? (cdr module))
                                      (undefined)
                                      (cadr module)))))))]
     [#f "output-full-member"
      => (lambda () (set! output-full-member #t))]
     [#f "output-name-only"
      => (lambda () (set! output-name-only #t))]
     [#f "io-encoding=s"
      => (lambda (opt) 
           (let1 opt (string-downcase (string-trim-both opt))
             (case (string->symbol opt)
               [(utf-8) ]
               [(euc_jp shift_jis iso2022jp)
                (set! in-conv (lambda (s) (ces-convert s opt)))
                (set! out-conv (lambda (s) (ces-convert s (gauche-character-encoding) opt)))]
               [else (errorf "invalid encoding.[~s]" opt)])))]
     . args)
    (unwind-protect
      (begin
        (let loop ([raw-line (in-conv (read-line))])
          (unless (eof-object? raw-line)
            (let1 line (string-trim-both raw-line)
              (unless (string=? line "#exit")
                (if process-all-line 
                  (exec-line raw-line)
                  (unless (zero? (string-length line))
                    (exec-line line)))
                (loop (in-conv (read-line)))))))
        0)
      1)))

