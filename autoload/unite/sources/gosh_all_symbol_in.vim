let s:openable_action_table = {}

let s:source = {
      \ 'name' : 'gosh_all_symbol_in',
      \ 'description' : 'all symbol in module',
      \ 'default_action' : 'open',
      \ 'is_volativle' : 0,
      \ 'required_pattern_length' : 0,
      \ 'max_candidates' : 100,
      \ 'action_table' : {'openable' : s:openable_action_table},
      \ 'hooks' : {},
      \ }


function! unite#sources#gosh_all_symbol_in#define()
  call gdev#init_proc()

  return s:source
endfunction

function! s:source.hooks.on_init(args, context)"{{{
  if len(a:args) == 0
    echohl WarningMsg | echomsg 'require module name' | echohl None
    return
  endif

  let a:context.source__first_candidates = 1

  unlet! s:doc
  call gdev#add_async_task('#load-symbol-in ' . a:args[0] . "\n",
        \ s:funcref('get_all_symbol_in_callback'),
        \ 0)
endfunction"}}}

function! s:source.async_gather_candidates(args, context)"{{{
  if len(a:args) == 0
    let a:context.is_async = 0
    return [{
          \ 'word': '!!! require module name !!!',
          \ 'is_dummy' : 1,
          \}]
  endif

  call gdev#check_async_task()

  if exists('s:doc')
    "clear loading word
    let a:context.source.unite__cached_candidates = []

    let ret = []
    for doc in s:doc
      let doc_name = doc['n']
      let units = doc['units']

      call extend(ret, map(units, '{
            \ "word" : v:val.n,
            \ "kind" : "openable",
            \ "abbr" : gdev#constract_unit_word(v:val, doc_name),
            \ "source__docname" : doc_name,
            \}'))
    endfor
    unlet s:doc

    let a:context.is_async = 0
    return ret
  elseif a:context.source__first_candidates
    let a:context.source__first_candidates = 0
    return [{
          \ 'word': 'Loading ...',
          \ 'is_dummy' : 1,
          \}]
  else
    return []
  endif
endfunction"}}}

function! s:get_all_symbol_in_callback(out, err, context)"{{{
  let s:doc = eval(a:out)
endfunction"}}}

"
"action table

"open {{{
let s:openable_action_table.open ={
      \ 'is_selectable' : 0,
      \ }
function! s:openable_action_table.open.func(c)
  call gdev#show_ginfo(a:c.source__docname, a:c.word)
endfunction"}}}

"split {{{
let s:openable_action_table.split ={
      \ 'is_selectable' : 0,
      \ }
function! s:openable_action_table.split.func(c)
  call gdev#show_ginfo(a:c.source__docname, a:c.word, 'h')
endfunction"}}}

" vsplit {{{
let s:openable_action_table.vsplit ={
      \ 'is_selectable' : 0,
      \ }
function! s:openable_action_table.vsplit.func(c)
  call gdev#show_ginfo(a:c.source__docname, a:c.word, 'v')
endfunction"}}}

" left {{{
let s:openable_action_table.left ={
      \ 'is_selectable' : 0,
      \ }
function! s:openable_action_table.left.func(c)
  call gdev#show_ginfo(a:c.source__docname, a:c.word, 'v:l')
endfunction"}}}

" right {{{
let s:openable_action_table.right ={
      \ 'is_selectable' : 0,
      \ }
function! s:openable_action_table.right.func(c)
  call gdev#show_ginfo(a:c.source__docname, a:c.word, 'v:r')
endfunction"}}}

" above {{{
let s:openable_action_table.above ={
      \ 'is_selectable' : 0,
      \ }
function! s:openable_action_table.above.func(c)
  call gdev#show_ginfo(a:c.source__docname, a:c.word, 'h:a')
endfunction"}}}

" below {{{
let s:openable_action_table.below ={
      \ 'is_selectable' : 0,
      \ }
function! s:openable_action_table.below.func(c)
  call gdev#show_ginfo(a:c.source__docname, a:c.word, 'h:b')
endfunction"}}}


"from vimproc plugin s:funcref(funcname)"{{{
function! s:SID_PREFIX()
  return matchstr(expand('<sfile>'), '<SNR>\d\+_\zeSID_PREFIX$')
endfunction

function! s:funcref(funcname)
  return function(s:SID_PREFIX() . a:funcname)
endfunction"}}}

" vim: foldmethod=marker
