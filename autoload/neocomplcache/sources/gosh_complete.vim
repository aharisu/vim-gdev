"=============================================================================
" FILE: gosh_complete.vim
" AUTHOR:  aharisu <foo.yobina@gmail.com>
" Last Modified: 04 Mar 2012.
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
      \}

let s:debug = 0
let s:debug_out_err = 0

let s:neocom_sources_directory = expand('<sfile>:p:h')
let s:gosh_complete_path = escape(get(g:, 'gosh_complete_path', s:neocom_sources_directory . '/gosh_complete.scm'), ' \')
let s:gosh_generated_doc_path = escape(s:neocom_sources_directory . '/doc',  ' \')
let s:async_task_queue = []

let s:default_module_order = []
let s:docinfo_table = {}

"5 seconds
let s:async_task_timeout = 5

function! s:source.initialize()"{{{
  call s:init_proc()

  augroup neocomplcache
    autocmd FileType scheme call s:initialize_buffer()
    autocmd BufWritePost * call s:parse_cur_buf_from_file()
    autocmd CursorHold * call s:cursor_hold('hold')
    autocmd CursorHoldI * call s:cursor_hold('holdi')
    autocmd CursorMoved * call s:cursor_moved('move')
    autocmd CursorMovedI * call s:cursor_moved('movei')
    autocmd VimLeave * call s:finale_proc()
  augroup END

  call s:load_default_module()
  call s:initialize_buffer()
endfunction"}}}

function! s:source.finalize()"{{{
  call s:finale_proc()
endfunction"}}}

function! s:source.get_keyword_pos(cur_text)"{{{
  let pattern = "\\%([[:alpha:]_$!&%@\\-\\+\\*/\\?<>=~^;][[:alnum:]_$!&%@\\-\\+\\*/\\?<>=~^:\\.]*\\m\\)$"
  let [cur_keyword_pos, cur_keyword_str] = neocomplcache#match_word(a:cur_text, l:pattern)
  return cur_keyword_pos
endfunction"}}}

function! s:source.get_complete_words(cur_keyword_pos, cur_keyword_str)"{{{
  if s:check_buffer_init()
    "It is not necessary to copy?
    return neocomplcache#keyword_filter(copy(b:word_list), a:cur_keyword_str)
  else
    return []
  endif
endfunction"}}}

function! neocomplcache#sources#gosh_complete#define()"{{{
  if neocomplcache#util#has_vimproc()
    return s:source
  else
    return {}
  endif
endfunction "}}}

function! s:check_buffer_init()"{{{
  if !exists('b:word_list')
    let b:word_list = []
  endif

  if !exists('b:buf_name')
    let b:buf_name = s:cur_buf_filepath()
  endif

  if !exists('b:prev_parse_tick')
    let b:prev_parse_tick = b:changedtick
  endif

  if getbufvar(bufnr('%'), '&filetype') != 'scheme'
    return 0
  endif

  return 1
endfunction"}}}

function! s:cursor_hold(type)"{{{
  call s:parse_cur_buf(1)

  "wait until all tasks
  while !empty(s:async_task_queue)
    call s:check_async_task()

    sleep 150m
  endwhile
endfunction"}}}

function! s:cursor_moved(type)"{{{
  call s:check_async_task()
endfunction"}}}

function! s:constract_docname(bufnum, bufname)"{{{
  if empty(a:bufname)
    return '#' . a:bufnum . '[No Name]'
  else
    return a:bufname
  endif
endfunction"}}}

function! s:initialize_buffer()"{{{
  if s:debug
    call neocomplcache#print_warning('s:initialize_buffer()')
  endif

  call s:check_buffer_init()

  if !has_key(s:docinfo_table, s:constract_docname(bufnr('%'), b:buf_name))
    call s:parse_cur_buf(0)
  endif
endfunction"}}}

function! s:add_doc(docs)"{{{
  for doc in a:docs
    "             doc[name]
    let docname = doc['n']
    let word_list = s:units_to_word_list(docname, get(doc, 'units', []))

    if has_key(s:docinfo_table, docname)
      let info = s:docinfo_table[docname]
      let info['words'] = word_list
      let info['extend'] = get(doc, 'extend', [])
    else
      let s:docinfo_table[docname] = {
            \ 'words' : word_list,
            \ 'extend' : get(doc, 'extend', [])
            \ }
    endif
  endfor
endfunction

function! s:units_to_word_list(docname, units) "{{{
  let table = {}

  for u in a:units
    "          u[name]
    let name = u['n']

    if has_key(table, name)
      let word = table[name]

      if empty(word['info'])
        let word['info'] = s:get_unit_info(u)
      else
        let word['info'] .= "\nAlt: " . s:get_unit_info(u)
      endif
    else
      let table[name] = {'word' : name,
            \ 'menu' : s:get_unit_menu(a:docname),
            \ 'kind' : s:get_unit_type_kind(u['t']),
            \ 'info' : s:get_unit_info(u)}
    endif
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

function! s:get_unit_info(unit)"{{{
  "          a:unit[type]
  let type = a:unit["t"] 
  if type ==# 'F' || type ==# 'Method' || type ==# 'Macro'
    "                a:unit[name]
    let info = "(" . a:unit["n"] 
    "                     a:unit[params] v:val[name]
    let params = join(map(get(a:unit, 'p', []), 'v:val["n"]'), ' ')
    if !empty(params)
      let info .= " " . params
    endif
    let info .= ")"
  elseif type ==# 'Class'
    "                                         a:unit[slot]
    let info = a:unit["n"] . " :" . join(map(get(a:unit, 's', []), 'v:val["n"]'), ' :')
  else
    let info = a:unit["n"]
  endif
    
  if !empty(get(a:unit, 'd', ''))
    let info .= "\n" . get(a:unit, 'd', '')
  endif

  return info
endfunction"}}}
"}}}

function! s:constract_word_list(order)"{{{
  let table = {}

  call s:add_word_list_in_order(table, s:default_module_order)
  call s:add_word_list_in_order(table, a:order)

  let b:word_list = values(table)
endfunction"}}}

function! s:add_word_list_in_order(table, order)"{{{

  for docname in a:order
    if !has_key(s:docinfo_table, docname)
      continue
    endif

    let info = s:docinfo_table[docname]
    for word in info['words']
      let a:table[word['word']] = word
    endfor
  endfor
endfunction"}}}

"
" Communicate to gosh-complete.scm

function! s:init_proc()"{{{
  let s:gosh_comp = vimproc#popen3('gosh' 
        \ . ' -I' . escape(s:neocom_sources_directory, ' \') . ' '
        \ . s:gosh_complete_path
        \ . " --generated-doc-directory=" . s:gosh_generated_doc_path
        \ . " --io-encoding=\"" . s:encoding() . "\""
        \ . s:get_loaded_module_text())
endfunction

function s:get_loaded_module_text()"{{{
  let text = ''
  for [name, doc] in items(s:docinfo_table)
    let text .= ' --loaded-module="' . s:get_loaded_module_name(name)
    for module in doc['extend']
      let text .= ' ' . module
    endfor
    let text .= '"'
  endfor

  return text
endfunction"}}}

function! s:get_loaded_module_name(docname)"{{{
  if match(a:docname, '^#') == -1
    let name = 'm' . a:docname
  else
    let name = 'f' . a:docname[2 :]
    if name ==# '[No Name]'
      let name = ''
    endif
  endif

  return name
endfunction"}}}"}}}

function! s:finale_proc()"{{{
  call s:gosh_comp.stdin.write("#exit\n")
  call s:gosh_comp.waitpid()
endfunction"}}}

function! s:load_default_module()"{{{
  call s:add_async_task("#load-default-module\n", 
        \ function('s:load_default_module_end_callback'))
endfunction

function! s:load_default_module_end_callback(out, err)
  if s:debug
    call neocomplcache#print_warning("end default parse")
  endif

  if !empty(a:out)
    let result = eval(a:out)

    let s:default_module_order = result['order']

    call s:add_doc(result['docs'])
    call s:constract_word_list([])
  endif
endfunction"}}}

function! s:parse_cur_buf_from_file()"{{{
  if s:debug
    call neocomplcache#print_warning('s:parse_cur_buf_from_file()')
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
    call neocomplcache#print_warning('s:parse_cur_buf(' 
          \ . a:parse_tick . ')'
          \ . (b:changedtick - b:prev_parse_tick))
  endif

  if (b:changedtick - b:prev_parse_tick) < a:parse_tick
    return
  endif

  if s:debug
    call neocomplcache#print_warning('do parse')
  endif

  let bufnumber = bufnr('%')
  let filename = s:cur_buf_filepath()

  let docname = s:constract_docname(bufnumber, filename)
  if empty(filename) || b:changedtick != b:prev_parse_tick
    let b:prev_parse_tick = b:changedtick

    "parse from buffer
    call s:add_async_task('#stdin ' . docname . "\n" .
          \ join(getbufline('%', 1, '$'), "\n") . "\n" .
          \ "#stdin-eof\n", 
          \ function('s:parse_cur_buf_end_callback'))
  else

    "parse from file
    call s:add_async_task('#load-file ' . filename . ' ' . docname . "\n",
          \ function('s:parse_cur_buf_end_callback'))
  endif

endfunction

function! s:parse_cur_buf_end_callback(out, err)
  if s:debug
    call neocomplcache#print_warning("end parse")
  endif

  if !empty(a:out)
    let result = eval(a:out)

    call s:add_doc(result['docs'])
    call s:constract_word_list(result['order'])
  endif
endfunction"}}}

function! s:restart_gosh_process()"{{{
  "signal 15 is SIGTERM
  call s:gosh_comp.kill(15)
  call s:init_proc()
endfunction"}}}

function! s:add_async_task(text, callback)"{{{
  if empty(s:async_task_queue)
    call s:gosh_comp.stdin.write(a:text)
    call add(s:async_task_queue, {'callback':a:callback, 'time' : localtime()})
  else
    call add(s:async_task_queue, {'text' : a:text, 'callback': a:callback})
  endif
endfunction

function! s:check_async_task()
  if empty(s:async_task_queue)
    return
  endif

  let out = s:read_output_one_try(s:gosh_comp.stdout)

  let err = ""
  if empty(out)
    let err = s:read_output_one_try(s:gosh_comp.stderr)
  endif

  let is_exec_next_task = 0
  if !empty(out) || !empty(err)
    let finish_task = remove(s:async_task_queue, 0)
    let Callback = finish_task['callback']
    call Callback(out, err)

    if s:debug_out_err
      if !empty(out)
        call neocomplcache#print_warning('out:' . out)
      endif
      if !empty(err)
        call neocomplcache#print_warning('err:' . err)
      endif
    endif

    let is_exec_next_task = 1
  else
    let cur_task = get(s:async_task_queue, 0)
    if s:async_task_timeout < (localtime() - cur_task['time'])
      if s:debug
        call neocomplcache#print_warning('timeout')
      endif

      "timeout: task failure
      call remove(s:async_task_queue, 0)

      "kill current process and restart gosh_complete
      call s:restart_gosh_process()

      let is_exec_next_task = 1
    endif
  endif

  if is_exec_next_task
    "execution next task
    let task = get(s:async_task_queue, 0)
    if task isnot 0
      call s:gosh_comp.stdin.write(task['text'])
      let task['text'] = 0
      let task['time'] = localtime()
    endif
  endif

endfunction

function! s:read_output_one_try(port)
  let out = ""

  let res = a:port.read()
  if !empty(res)
    while 1
      let len = strlen(res)
      if res[len - 1] ==# "\n"
        let out .= strpart(res, 0, len - 1)
        break
      else
        let out .= res
      endif

      let res = a:port.read()
    endwhile
  endif

  return out
endfunction"}}}

"
" util

function! s:encoding()"{{{
  let enc = &encoding
  if enc == 'utf-8'
    return 'utf-8'
  elseif enc == 'cp932'
    return 'shift_jis'
  elseif enc == 'euc-jp'
    return 'euc_jp'
  elseif enc == 'iso-2022-jp'
    return 'iso2022jp'
  endif
endfunction"}}}

function! s:cur_buf_filepath() "{{{
  return escape(expand('%:p'),  ' \')
endfunction"}}}

" vim: foldmethod=marker
