let s:openable_action_table = {}

let s:source = {
      \ 'name' : 'gosh_all_symbol',
      \ 'description' : 'all gauche symbol infomation',
      \ 'default_action' : 'open',
      \ 'is_volativle' : 0,
      \ 'required_pattern_length' : 0,
      \ 'max_candidates' : 100,
      \ 'action_table' : {'openable' : s:openable_action_table},
      \ 'hooks' : {},
      \ }


function! unite#sources#gosh_all_symbol#define()
  call gdev#init_proc()

  return s:source
endfunction

function! s:source.hooks.on_init(args, context)"{{{
  let s:ginfo_doc = []
  let s:symbol_selected = 0
  let s:finish_get_all_symbol = 0

  let s:cur_text = ''
  let s:equal_count = 0

  let a:context.source__candidates_state = 0

  call gdev#add_async_task("#load-all-symbol\n",
        \ s:funcref('get_all_symbol_callback'),
        \ 0)
endfunction"}}}

function! s:source.hooks.on_close(args, context)"{{{
  let s:symbol_selected = 1
  call gdev#write_text("#end-load-all-symbol\n")

  while !s:finish_get_all_symbol
    call gdev#check_async_task()
  endwhile
endfunction"}}}

function! s:source.async_gather_candidates(args, context)"{{{
  if s:cur_text ==# a:context.input
    let s:equal_count += 1
  else
    let s:equal_count += 0
    let s:cur_text = a:context.input
  endif

  for n in range(0, s:equal_count * 4)
    if gdev#check_async_task() == 0
      break
    endif
  endfor

  let ret = []

  if len(s:ginfo_doc)
    if a:context.source__candidates_state == 1
      "clear loading word
      let a:context.source.unite__cached_candidates = []
      let a:context.source__candidates_state = 2
    endif

    for doc in s:ginfo_doc
      let doc_name = doc['n']
      let units = doc['units']

      call extend(ret, map(units, '{
          \ "word" : v:val.n,
          \ "kind" : "openable",
          \ "abbr" : gdev#constract_unit_word(v:val, doc_name),
          \ "source__docname" : doc_name,
          \}'))
    endfor

    let s:ginfo_doc = []
  elseif a:context.source__candidates_state == 0
    let a:context.source__candidates_state = 1
    "first candidate
    call add(ret, {
          \ 'word': 'Loading ...',
          \ 'is_dummy' : 1,
          \})
  endif

  if s:finish_get_all_symbol
    let a:context.is_async = 0
  endif

  return ret
endfunction"}}}

function! s:get_all_symbol_callback(out, err, context)"{{{
  let docs = eval(a:out)
  if type(docs) == type('')
    if docs ==# '##'
      if !s:symbol_selected
        call gdev#write_text("#resume-load-all-symbol\n")
        return 1
      else
        let s:ginfo_doc = []
        let s:finish_get_all_symbol = 1
        return 0
      endif

    elseif docs ==# '#'
      let s:ginfo_doc = []
      let s:finish_get_all_symbol = 1
      return 0
    endif
  else 
    if !s:symbol_selected
      call add(s:ginfo_doc, docs[0])
    endif

    return 1
  endif
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
