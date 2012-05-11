let s:symbols_action_table = {}

let s:source = {
      \ 'name' : 'gosh_all_module',
      \ 'description' : 'all gauche module',
      \ 'default_action' : 'symbols',
      \ 'is_volativle' : 0,
      \ 'filters' : ['matcher_default', 'sorter_word', 'converter_default'],
      \ 'hooks' : {},
      \ 'action_table' : {'common' : s:symbols_action_table},
      \ }

function! unite#sources#gosh_all_module#define()
  call gosh_complete#init_proc()

  return s:source
endfunction

function! s:source.hooks.on_init(args, context)"{{{
  call gosh_complete#add_async_task("#load-all-module\n",
        \ s:funcref('get_all_module_callback'),
        \ 0)
endfunction"}}}

function! s:source.async_gather_candidates(args, context)"{{{
  call gosh_complete#check_async_task()

  if exists('s:modules')
    call map(s:modules, '{
          \ "word" : v:val.n,
          \ "abbr" : s:constract_word(v:val.n, v:val.d),
          \ }')

    let ret = s:modules
    unlet s:modules

    let a:context.is_async = 0
    return ret
  else
    return []
  endif
endfunction"}}}

function! s:constract_word(mod, description)"{{{
  if empty(a:description)
    return a:mod
  else
    return printf("%s -- %s", a:mod, a:description)
  endif
endfunction"}}}

function! s:get_all_module_callback(out, err, context)"{{{
  let s:modules = eval(a:out)
endfunction"}}}

"
"action table

"open {{{
let s:symbols_action_table.symbols ={
      \ 'is_selectable' : 0,
      \ }
function! s:symbols_action_table.symbols.func(c)
  call unite#start([['gosh_all_symbol_in', a:c.word]])
endfunction"}}}


"from vimproc plugin s:funcref(funcname)"{{{
function! s:SID_PREFIX()
  return matchstr(expand('<sfile>'), '<SNR>\d\+_\zeSID_PREFIX$')
endfunction

function! s:funcref(funcname)
  return function(s:SID_PREFIX() . a:funcname)
endfunction"}}}

" vim: foldmethod=marker
