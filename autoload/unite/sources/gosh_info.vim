let s:openable_action_table = {}

let s:source = {
      \ 'name' : 'gosh_info',
      \ 'description' : 'gauche infomation',
      \ 'default_action' : 'open',
      \ 'is_volativle' : 1,
      \ 'action_table' : {'openable' : s:openable_action_table},
      \ 'hooks' : {},
      \ }

function! unite#sources#gosh_info#define()
  return s:source
endfunction


function! s:source.hooks.on_init(args, context)
  if has_key(a:context, 'source__with_keyword')
    let units = gdev#match_unit_in_order_first_match_prionity_exact_match(bufnr('%'),a:context.input , 0) "no duplicate
  else
    let units = gdev#match_unit_in_order(bufnr('%'), '', 0) "no duplicate
  endif
  call map(units, '{
        \ "word" : v:val.n,
        \ "kind" : "openable",
        \ "abbr" : gdev#constract_unit_word(v:val),
        \ "source__docname" : v:val.docname,
        \}')

  let a:context.source__candidates = units
endfunction

function! s:source.gather_candidates(args, context)
  return a:context.source__candidates
endfunction

"
"action table

let s:openable_action_table.open ={
      \ 'is_selectable' : 0,
      \ }
function! s:openable_action_table.open.func(c)
  call gdev#show_ginfo(a:c.source__docname, a:c.word)
endfunction

let s:openable_action_table.split ={
      \ 'is_selectable' : 0,
      \ }
function! s:openable_action_table.split.func(c)
  call gdev#show_ginfo(a:c.source__docname, a:c.word, 'h')
endfunction

let s:openable_action_table.vsplit ={
      \ 'is_selectable' : 0,
      \ }
function! s:openable_action_table.vsplit.func(c)
  call gdev#show_ginfo(a:c.source__docname, a:c.word, 'v')
endfunction

let s:openable_action_table.left ={
      \ 'is_selectable' : 0,
      \ }
function! s:openable_action_table.left.func(c)
  call gdev#show_ginfo(a:c.source__docname, a:c.word, 'v:l')
endfunction

let s:openable_action_table.right ={
      \ 'is_selectable' : 0,
      \ }
function! s:openable_action_table.right.func(c)
  call gdev#show_ginfo(a:c.source__docname, a:c.word, 'v:r')
endfunction

let s:openable_action_table.above ={
      \ 'is_selectable' : 0,
      \ }
function! s:openable_action_table.above.func(c)
  call gdev#show_ginfo(a:c.source__docname, a:c.word, 'h:a')
endfunction

let s:openable_action_table.below ={
      \ 'is_selectable' : 0,
      \ }
function! s:openable_action_table.below.func(c)
  call gdev#show_ginfo(a:c.source__docname, a:c.word, 'h:b')
endfunction

"
"application interface

function! unite#sources#gosh_info#start_search(is_insert)
  call s:start_search(0, a:is_insert, 0)
endfunction

function! unite#sources#gosh_info#start_search_with_cur_keyword(is_insert, only_unique)
  call s:start_search(1, a:is_insert, a:only_unique)
endfunction

function! s:start_search(with_key, is_insert, only_unique)
  if !exists(':Unite')
    echoerr 'unite.vim is not installed.'
    return 
  endif

  let context = {}

  let is_unique = 0
  if a:with_key
    let cword = expand('<cword>')
    let context['input'] = cword

    let units = gdev#match_unit_in_order_first_match_prionity_exact_match(bufnr('%'), cword, 0)
    if len(units) == 1 
      let is_unique = 1
      let context['immediately'] = 1
      let context['source__with_keyword'] = 1
    endif
  endif

  if !a:only_unique || is_unique
    call unite#start(['gosh_info'], context)
    if is_unique && a:is_insert
      call s:start_a_insert()
    endif
  else
    if a:is_insert
      call s:start_a_insert()
    endif
  endif
endfunction

function! s:start_a_insert()
  let [l,c] = searchpos('\>', 'ec')
  if c == col('$')
    startinsert!
  else
    startinsert
  endif
endfunction

