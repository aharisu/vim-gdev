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

