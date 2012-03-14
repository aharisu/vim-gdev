let s:source = {
      \ 'name' : 'gosh_info',
      \ 'description' : 'gauche infomation',
      \ 'default_action' : 'open',
      \ 'is_volativle' : 1,
      \ 'action_table' : {},
      \ 'hooks' : {},
      \ }

function! unite#sources#gosh_info#define()
  return s:source
endfunction


function! s:source.hooks.on_init(args, context)
  let units = gosh_complete#match_unit_in_order(bufnr('%'), '', 0) "no duplicate
  call map(units, '{
        \ "word" : v:val.n,
        \ "kind" : "openable",
        \ "source__docname" : v:val.docname,
        \}')
  let a:context.source__candidates = units
endfunction

function! s:source.gather_candidates(args, context)
  return a:context.source__candidates
endfunction


let s:source.action_table.open ={
      \ 'is_selectable' : 0,
      \ }

function! s:source.action_table.open.func(c)
  call gosh_complete#show_ginfo(a:c.source__docname, a:c.word)
endfunction


function! unite#sources#gosh_info#start_search()
  call s:start_search(0)
endfunction

function! unite#sources#gosh_info#start_search_with_cur_keyword()
  call s:start_search(1)
endfunction

function! s:start_search(with_key)
  if !exists(':Unite')
    echoerr 'unite.vim is not installed.'
    return 
  endif

  let context = {}

  if a:with_key
    let cword = expand('<cword>')
    let context['input'] = cword

    let units = gosh_complete#match_unit_in_order(bufnr('%'), cword, 0)
    if len(units) == 1 
      let context['immediately'] = 1
    endif
  endif

  call unite#start(['gosh_info'], context)
endfunction


