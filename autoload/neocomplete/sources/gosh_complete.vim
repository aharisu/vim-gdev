"=============================================================================
" FILE: gosh_complete.vim
" AUTHOR:  aharisu <foo.yobina@gmail.com>
" Last Modified: 22 Sep 2013.
" License: MIT license  {{{
"     Permission is hereby granted, free of charge, to any person obtaining
"     a copy of this software and associated documentation files (the
"     "Software"), to deal in the Software without restriction, including
"     without limitation the rights to use, copy, modify, merge, publish,
"     distribute, sublicense, and/or sell copies of the Software, and to
"     permit persons to whom the Software is furnished to do so, subject to
"     the following conditions:
"
"     The above copyright notice and this permission notice shall be included
"     in all copies or substantial portions of the Software.
"
"     THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
"     OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
"     MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
"     IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
"     CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
"     TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
"     SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
" }}}
"=============================================================================

let s:source = {
      \ 'name' : 'gosh-complete',
      \ 'kind' : 'ftplugin',
      \ 'filetypes' : {'scheme' : 1},
      \ 'hooks' : {},
      \}

let s:debug = 0
let s:debug_out_err = 0

let s:neocom_sources_directory = expand('<sfile>:p:h')
let s:gosh_complete_path = escape(get(g:, 'gosh_complete_path', s:neocom_sources_directory . '/gosh_complete.scm'), ' \')
let s:gosh_generated_doc_path = escape(s:neocom_sources_directory . '/doc',  ' \')

let s:default_module_order = []


function! s:source.hooks.on_init(context)"{{{
  call gdev#init_proc()

  augroup neocomplete
    autocmd FileType scheme call s:initialize_buffer()
    autocmd BufWritePost * call s:parse_cur_buf_from_file()
    autocmd CursorHold * call s:cursor_hold('hold')
    autocmd CursorHoldI * call s:cursor_hold('holdi')
    autocmd CursorMoved * call s:cursor_moved('move')
    autocmd CursorMovedI * call s:cursor_moved('movei')
    autocmd VimLeave * call gdev#finale_proc()
  augroup END

  call s:load_default_module()
  call s:initialize_buffer()
endfunction"}}}

function! s:source.hooks.on_final(context)"{{{
  call gdev#finale_proc()
endfunction"}}}

function! s:source.get_complete_position(context)"{{{
  call neocomplete#print_error("input:" . a:context.input)

  let pattern = "\\%([[:alpha:]_$!&%@\\-\\+\\*/\\?<>=~^;][[:alnum:]_$!&%@\\-\\+\\*/\\?<>=~^:\\.]*\\m\\)$"
  let [cur_keyword_pos, cur_keyword_str] = neocomplete#match_word(a:context.input, l:pattern)
  return cur_keyword_pos
endfunction"}}}

function! s:source.gather_candidates(context)"{{{
  if s:check_buffer_init()
    "It is not necessary to copy?
    return copy(gdev#get_buf_data(bufnr('%'), 'words', []))
  else
    return []
  endif
endfunction"}}}

function! neocomplete#sources#gosh_complete#define()"{{{
  if neocomplete#util#has_vimproc()
    return s:source
  else
    return {}
  endif
endfunction "}}}

function! s:check_buffer_init()"{{{

  if !exists('b:prev_parse_tick')
    let b:prev_parse_tick = b:changedtick
  endif

  if getbufvar(bufnr('%'), '&filetype') != 'scheme'
    return 0
  endif

  return 1
endfunction"}}}

function! s:cursor_hold(type)"{{{
  if &filetype !=# 'unite'
    "call s:parse_cur_buf(1)

    "wait until all tasks
    while !gdev#is_empty_async_task()
      call gdev#check_async_task()
    endwhile
  endif
endfunction"}}}

function! s:cursor_moved(type)"{{{
  if &filetype !=# 'unite'
    call gdev#check_async_task() 
  endif
endfunction"}}}

function! s:constract_docname(bufnum, bufname)"{{{
  if empty(a:bufname)
    return '#' . a:bufnum . '[No Name]'
  else
    return '#' . a:bufnum . a:bufname
  endif
endfunction"}}}

function! s:initialize_buffer()"{{{
  if s:debug
    call neocomplete#print_warning('s:initialize_buffer()')
  endif

  call s:check_buffer_init()

  call s:parse_cur_buf(0)
endfunction"}}}

function! s:add_doc(docs)"{{{
  for doc in a:docs
    call gdev#add_doc(doc['n'] ,doc['f'] ,get(doc, 'units', []))
  endfor
endfunction "}}}

function! s:set_module_order(bufnr, order)"{{{
  let order = copy(s:default_module_order)
  call extend(order, a:order)

  call gdev#set_module_order(a:bufnr, order)
endfunction"}}}

function! s:constract_word_list(bufnr)"{{{
  " get all unit
  let units = gdev#match_unit_in_order_first_match(a:bufnr, '', 0)

  " unit to completion word
  let word_list = s:units_to_word_list(units)

  " register word list
  call gdev#set_buf_data(a:bufnr, 'words', word_list)
endfunction"}}}

function! s:units_to_word_list(units) "{{{
  let table = {}

  for u in a:units
    "          u[name]
    let name = u['n']

    let table[name] = {'word' : name,
          \ 'menu' : s:get_unit_menu(u['docname']),
          \ 'kind' : s:get_unit_type_kind(u['t'])}
  endfor

  return values(table)
endfunction "}}}

function! s:get_unit_type_kind(type)"{{{
  "  a:type ==# 'Function'
  if a:type ==# 'F' || a:type ==# 'Method'
    return 'f'
   "                        a:type ==# Constant
  elseif a:type ==# 'var'|| a:type ==# 'C' || a:type ==# 'Parameter'
    return 'v'
  elseif a:type ==# 'Class'
    return 'c'
  elseif a:type ==# 'Macro'
    return 'm'
  else
    return ''
  endif
endfunction"}}}

function! s:get_unit_menu(module)"{{{
  let text = '[gosh] '
  if match(a:module, '^#') == -1
    let text .= fnamemodify(a:module, ':t')
  else
    let text .= fnamemodify(a:module[2 :], ':t:r')
  endif
  return text
endfunction"}}}


"
" Communicate to gosh-complete.scm

function! s:load_default_module()"{{{
  call gdev#add_async_task("#load-default-module\n", 
        \ s:funcref('load_default_module_end_callback'),
        \ {})
endfunction

function! s:load_default_module_end_callback(out, err, context)
  if s:debug
    call neocomplete#print_warning("end default parse")
  endif

  if !empty(a:out)
    let result = eval(a:out)

    let s:default_module_order = result['order']
    call s:add_doc(result['docs'])
  endif
endfunction"}}}

function! s:parse_cur_buf_from_file()"{{{
  if s:debug
    call neocomplete#print_warning('s:parse_cur_buf_from_file()')
  endif

  if !s:check_buffer_init()
    return
  endif

  if b:prev_parse_tick != b:changedtick
    let b:prev_parse_tick = b:changedtick

    call s:parse_cur_buf(0)
  endif
endfunction"}}}

function! s:parse_cur_buf(parse_tick)"{{{
  if !s:check_buffer_init()
    return
  endif

  if s:debug
    call neocomplete#print_warning('s:parse_cur_buf(' 
          \ . a:parse_tick . ')'
          \ . (b:changedtick - b:prev_parse_tick))
  endif

  if (b:changedtick - b:prev_parse_tick) < a:parse_tick
    return
  endif

  if s:debug
    call neocomplete#print_warning('do parse')
  endif

  let bufnumber = bufnr('%')
  let filename = s:cur_buf_filepath()

  let docname = s:constract_docname(bufnumber, filename)
  if empty(filename) || (b:changedtick - b:prev_parse_tick) > 10
    let b:prev_parse_tick = b:changedtick
    if empty(filename)
      let basedir = getcwd()
    else
      let basedir = escape(expand('%:p:h'),  ' \')
    endif

    if s:debug
      call neocomplete#print_warning('from buffer')
    endif

    "parse from buffer
    call gdev#add_async_task('#stdin ' . basedir . ' ' . docname . "\n" .
          \ join(getbufline('%', 1, '$'), "\n") . "\n" .
          \ "#stdin-eof\n", 
          \ s:funcref('parse_cur_buf_end_callback'),
          \ {'bufnr' : bufnr('%')})
  else

    if s:debug
      call neocomplete#print_warning('from file')
    endif

    "parse from file
    call gdev#add_async_task('#load-file ' . filename . ' ' . docname . "\n",
          \ s:funcref('parse_cur_buf_end_callback'),
          \ {'bufnr' : bufnr('%')})
  endif

endfunction

function! s:parse_cur_buf_end_callback(out, err, context)
  if s:debug
    call neocomplete#print_warning("end parse")
  endif

  if !empty(a:out)
    let result = eval(a:out)

    call s:add_doc(result['docs'])
    call s:set_module_order(a:context['bufnr'], result['order'])

    call s:constract_word_list(a:context['bufnr'])
  endif
endfunction"}}}


"
" util

function! s:cur_buf_filepath() "{{{
  return escape(substitute(expand('%:p'), '\\', '/', 'g'), ' ')
endfunction"}}}

function! s:SID_PREFIX()
  return matchstr(expand('<sfile>'),'<SNR>\d\+_\zeSID_PREFIX$')
endfunction

function! s:funcref(func)
  return function(s:SID_PREFIX() . a:func)
endfunction

" vim: foldmethod=marker
