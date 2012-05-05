"=============================================================================
" FILE: gosh_complete.vim
" AUTHOR:  aharisu <foo.yobina@gmail.com>
" Last Modified: 10 Mar 2012.
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


let s:neocom_sources_directory = expand('<sfile>:p:h')
let s:gosh_complete_path = escape(get(g:, 'gosh_complete_path', s:neocom_sources_directory . '/gosh_complete.scm'), ' \')
let s:gosh_generated_doc_path = escape(s:neocom_sources_directory . '/doc',  ' \')
let s:async_task_queue = []

let s:ginfo_table = {}
let s:each_buf_data = {}

let s:debug = 0
let s:debug_out_err = 0

"5 seconds
let s:async_task_timeout = 5

let s:init_count = 0

let g:gosh_info_width = 
      \ get(g:, 'gosh_info_width', 35)

let g:gosh_info_height = 
      \ get(g:, 'gosh_info_height', 6)

let g:gosh_info_direction = 
      \ get(g:, 'gosh_info_direction', 'h')


function! s:initialize()"{{{

  " Register key mapping
  nnoremap <silent> <Plug>(gosh_info_row_up)
        \ :call gosh_complete#do_cmd_in_gosh_info("call s:gosh_info_scroll_up()")<CR>
  nnoremap <silent> <Plug>(gosh_info_row_down)
        \ :call gosh_complete#do_cmd_in_gosh_info("call s:gosh_info_scroll_down()")<CR>
  nnoremap <silent> <Plug>(gosh_info_close)
        \ :call gosh_complete#do_cmd_in_gosh_info("wincmd q")<CR>
  inoremap <silent> <Plug>(gosh_info_row_up) 
        \<ESC>:call gosh_complete#do_cmd_in_gosh_info("call s:gosh_info_scroll_up()")<CR>a
  inoremap <silent> <Plug>(gosh_info_row_down) 
        \<ESC>:call gosh_complete#do_cmd_in_gosh_info("call s:gosh_info_scroll_down()")<CR>a
  inoremap <silent> <Plug>(gosh_info_close) 
        \<ESC>:call gosh_complete#do_cmd_in_gosh_info("wincmd q")<CR>a

  inoremap <silent> <Plug>(gosh_info_start_search_with_cur_keyword) 
        \<ESC>:call unite#sources#gosh_info#start_search_with_cur_keyword(1, 0)<CR>
  inoremap <silent> <Plug>(ginfo_start_with_cur_keyword_only_unique) 
        \<ESC>:call unite#sources#gosh_info#start_search_with_cur_keyword(2, 1)<CR>

  nnoremap <silent> <Plug>(gosh_info_start_search)
        \ :call unite#sources#gosh_info#start_search(0)<CR>
  nnoremap <silent> <Plug>(gosh_info_start_search_with_cur_keyword)
        \ :call unite#sources#gosh_info#start_search_with_cur_keyword(0, 0)<CR>
endfunction"}}}

function! gosh_complete#add_doc(name, units)"{{{
  if s:debug
    call neocomplcache#print_warning('add_doc:' . a:name)
  endif

  for unit in a:units
    let unit['docname'] = a:name
    let unit['_loaded_doc'] = 0
  endfor

  if has_key(s:ginfo_table, a:name)
    let s:ginfo_table[a:name]['units'] = a:units
  else
    let s:ginfo_table[a:name] = {
          \ 'units' : a:units,
          \ }
  endif
endfunction"}}}

function! gosh_complete#set_buf_data(buf_num, name, data)"{{{
  if s:debug
    call neocomplcache#print_warning('set_buf_data:' 
          \ . a:buf_num . ':' 
          \ . a:name . ':')

  endif

  if has_key(s:each_buf_data, a:buf_num)
    let s:each_buf_data[a:buf_num][a:name] = a:data
  else
    let s:each_buf_data[a:buf_num] = {
          \ a:name : a:data
          \ }
  endif
endfunction"}}}

function! gosh_complete#get_buf_data(buf_num, name, ...)"{{{
  if has_key(s:each_buf_data, a:buf_num) &&
        \ has_key(s:each_buf_data[a:buf_num], a:name)
    return s:each_buf_data[a:buf_num][a:name]
  elseif a:0 > 0
    return a:1
  else
    return 0
  endif
endfunction"}}}

function! gosh_complete#set_module_order(buf_num, order)"{{{
  call gosh_complete#set_buf_data(a:buf_num, 'order', a:order)
endfunction"}}}

function! gosh_complete#get_module_order(buf_num)"{{{
  return gosh_complete#get_buf_data(a:buf_num, 'order', [])
endfunction"}}}

function! gosh_complete#match_unit_in_order_first_match(buf_num, keyword, allow_duplicate)"{{{
  if a:allow_duplicate
    return s:match_unit_in_order_allow_duplicate(a:buf_num, a:keyword, function('s:first_match_filter'))
  else
    return s:match_unit_in_order_no_duplicate(a:buf_num, a:keyword, function('s:first_match_filter'))
  endif
endfunction"}}}

function! gosh_complete#match_unit_in_order(buf_num, keyword, allow_duplicate)"{{{
  if a:allow_duplicate
    return s:match_unit_in_order_allow_duplicate(a:buf_num, a:keyword, function('s:unit_name_head_filter'))
  else
    return s:match_unit_in_order_no_duplicate(a:buf_num, a:keyword, function('s:unit_name_head_filter'))
  endif
endfunction"}}}

functio! s:match_unit_in_order_no_duplicate(buf_num, keyword, Comp)"{{{
  let unit_table = {}

  for mod in gosh_complete#get_module_order(a:buf_num)
    if !has_key(s:ginfo_table, mod)
      continue
    endif


    let ginfo = s:ginfo_table[mod]
    if a:keyword == ''
      let units = copy(ginfo['units'])
    else
      let units = a:Comp(ginfo['units'], a:keyword)
    endif

    for unit in units
      let unit_table[unit['n']] = unit
    endfor
  endfor

  return values(unit_table)
endfunction"}}}

functio! s:match_unit_in_order_allow_duplicate(buf_num, keyword, Comp)"{{{
  let unit_table = {}
  let type_list = type([])

  for mod in gosh_complete#get_module_order(a:buf_num)
    if !has_key(s:ginfo_table, mod)
      continue
    endif

    let ginfo = s:ginfo_table[mod]
    if a:keyword == ''
      let units = copy(ginfo['units'])
    else
      let units = a:Comp(ginfo['units'], a:keyword)
    endif

    let table = {}
    for unit in units
      let name = unit['n']

      if has_key(table, name)
        if type(table[name]) == type_list
          call add(table[name], unit)
        else
          let dup = table[name]
          unlet table[name]
          let table[name] = [dup, unit]
        endif
      else
        let table[unit['n']] = unit
      endif
    endfor

    for item in items(table)
      if has_key(unit_table, item[0])
        unlet unit_table[item[0]]
      endif

      let unit_table[item[0]] = item[1]
    endfor
  endfor

  let unit_list = []
  for item in items(unit_table)
    if type(item[1]) == type_list
      call extend(unit_list, item[1])
    else
      call add(unit_list, item[1])
    endif
  endfor

  return unit_list
endfunction"}}}

function! s:first_match_filter(units, keyword)"{{{
  if &ignorecase
    let expr = printf('strpart(v:val.n, 0, %d) =~  %s', len(a:keyword), string(a:keyword))
  else
    let expr = printf('strpart(v:val.n, 0, %d) =~# %s', len(a:keyword), string(a:keyword))
  endif

  return filter(copy(a:units), expr)
endfunction"}}}

function! s:unit_name_head_filter(units, keyword)"{{{
  if &ignorecase
    let expr = printf('!stridx(tolower(v:val.n), %s)', tolower(string(a:keyword)))
  else
    let expr = printf('!stridx(v:val.n, %s)', string(a:keyword))
  endif

  return filter(copy(a:units), expr)
endfunction"}}}

function! gosh_complete#show_ginfo(module, symbol, ...)"{{{
  if has_key(s:ginfo_table, a:module)
    let units = s:find_ginfo_in_doc(s:ginfo_table[a:module], a:symbol)
    let ginfo_list = s:get_unit_ginfo(units)

    let text = s:ginfo_list_to_text(ginfo_list)
    call s:open_preview(text, 1, 0 < a:0 ? a:1 : g:gosh_info_direction)
  endif
endfunction"}}}

function! s:find_ginfo_in_doc(doc, symbol)"{{{
  let unit_list = []

  for unit in a:doc['units']
    if unit['n'] ==# a:symbol
      call add(unit_list, unit)
    endif
  endfor

  return unit_list
endfunction"}}}

"s:get_unit_ginfo"{{{
let s:get_unit_ginfo_complete = 1
let s:unit_ginfo = []
function! s:get_unit_ginfo(units)
  if empty(a:units)
    return a:units
  endif


  let loaded = 1
  for unit in a:units 
    if unit['_loaded_doc'] == 0
      let loaded = 0
      break
    endif
  endfor


  if loaded
    return a:units
  else
    let unit_name = a:units[0]['n']
    let doc_name = a:units[0]['docname']

    let s:get_unit_ginfo_complete = 0

    "call gosh
    call gosh_complete#add_async_task('#get-unit '
          \ . doc_name . ' ' . unit_name . "\n",
          \ function('s:get_unit_ginfo_callback'),
          \ {})

    "wait until get unit
    while !s:get_unit_ginfo_complete
      call gosh_complete#check_async_task()

      sleep 50m
    endwhile

    call filter(s:ginfo_table[doc_name]['units'],
          \ 'v:val["n"] !=# unit_name')

    for unit in s:unit_ginfo
      let unit['docname'] = doc_name
      let unit['_loaded_doc'] = 1
    endfor

    call extend(s:ginfo_table[doc_name]['units'], s:unit_ginfo)

    let ret = s:unit_ginfo
    let s:unit_ginfo = []
    return ret
  endif
endfunction

function! s:get_unit_ginfo_callback(out, err, context)
  if !empty(a:out)
    let s:unit_ginfo = eval(a:out)
  endif
  let s:get_unit_ginfo_complete = 1
endfunction"}}}

function! s:ginfo_list_to_text(units)"{{{
  let text = ''
  let is_first = 1

  for unit in a:units
    if is_first
      let text .= s:get_unit_type_kind(unit)
      let text .= '  --- ' . s:get_unit_module(unit)
      let text .= "\n"
    else
      if text !~# ".*\n\n$"
        if text[strlen(text) - 1] ==# "\n"
          let text .= "\n"
        else
          let text .= "\n\n"
        endif
      endif
    endif

    let text .= s:get_unit_interface(unit)
    let text .= "\n\n"
    let text .= s:get_unit_description(unit)
  endfor

  return text
endfunction"}}}

function! s:get_unit_type_kind(unit)"{{{
  let type = a:unit['t']

  if type ==# 'F'
    return 'Function'
  elseif type ==# 'Method'
    return 'Method'
  elseif type ==# 'var'
    return 'Variable'
  elseif type ==# 'C' 
    return 'Constant Variable'
  elseif type ==# 'Parameter'
    return 'Parameter'
  elseif type ==# 'Class'
    return 'Class'
  elseif type ==# 'Macro'
    return 'Macro'
  else
    return ''
  endif
endfunction"}}}

function! s:get_unit_module(unit)"{{{
  let module = a:unit['docname']

  if match(module, '^#') == -1
    return fnamemodify(module, ':t')
  else
    return fnamemodify(module[2 :], ':t:r')
  endif
endfunction"}}}

function! s:get_unit_interface(unit)"{{{
  let type = a:unit['t']
  if type ==# 'F' || type ==# 'Method' || type ==# 'Macro'
    let info = '(' . a:unit['n']
    let params = join(map(copy(get(a:unit, 'p', [])), 'v:val["n"]'), ' ')
    if !empty(params)
      let info .= ' ' . params
    endif
    let info .= ')'
  else
    let info = a:unit['n']
  endif

  return info
endfunction"}}}

function! s:get_unit_description(unit)"{{{
  let type = a:unit['t']
  let description = ''

  if type ==# 'F' || type ==# 'Method' || type ==# 'Macro' || type ==# 'Class'

    if type ==# 'Class'
      let name = 's'
      let is_show_empty = 1
    else
      let name = 'p'
      let is_show_empty = 0
    endif

    let is_first = 1
    let index = 0
    for param in get(a:unit, name, [])
      if !is_first
        let description .= "\n"
      endif

      let text = s:get_param_description(param, is_show_empty)
      if !empty(text)
        if is_first
          let description .= "--interface--\n"
        endif

        let description .= ' ' . index . ':' . text
        let is_first = 0
      endif

      let index += 1
    endfor
  endif

  if has_key(a:unit, 'd')
    if !empty(description) && description !~# ".*\n\n$"
      if description[strlen(description) - 1] ==# "\n"
        let description .= "\n"
      else
        let description .= "\n\n"
      endif
    endif

    let description .= "--description--\n"
    let description .= s:trim_both(a:unit['d'])
  endif

  return description
endfunction

function! s:trim_both(text)
  let text = a:text
  "trim head \n
  while text =~# "^\n"
    let text = text[1 :]
  endwhile
  "trim tail \n
  while text =~# "\n\n$"
    let text = text[0 : strlen(text) - 2]
  endwhile

  return text
endfunction

function! s:get_param_description(param, is_show_empty)
  let text = s:trim_both(a:param['n'])
  let has_description = 0

  if has_key(a:param, 'a')
    let has_description = 1
    let text .= "\n     Acceptable: " . join(a:param['a'], ' ')
  endif
  if has_key(a:param, 'd')
    let has_description = 1
    let text .= "\n   " . s:trim_both(a:param['d'])
  endif

  if a:is_show_empty || has_description
    return text
  else
    return ""
  endif
endfunction"}}}


"
" Communicate to gosh-complete.scm

function! gosh_complete#init_proc()"{{{
  if s:init_count == 0
    call s:initialize()

    let s:gosh_comp = vimproc#popen3('gosh' 
          \ . ' -I' . escape(s:neocom_sources_directory, ' \') . ' '
          \ . s:gosh_complete_path
          \ . " --generated-doc-directory=" . s:gosh_generated_doc_path
          \ . " --output-api-only"
          \ . " --io-encoding=\"" . s:encoding() . "\""
          \ . s:get_load_module_text())
  endif

  let s:init_count += 1
endfunction }}}

function s:get_load_module_text()"{{{
  let text = ''

  for [name, doc] in items(s:ginfo_table)
    let text .= ' --load-module="' . s:get_loaded_module_name(name) . '"'
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
    else
      let name .= ' ' . a:docname
    endif
  endif

  return name
endfunction"}}}"}}}

function! gosh_complete#finale_proc()"{{{
  let s:init_count -= 1

  if s:init_count <= 0
    call s:gosh_comp.stdin.write("#exit\n")
    call s:gosh_comp.waitpid()
    let s:init_count = 0
  endif
endfunction"}}}

function! s:restart_gosh_process()"{{{
  " save s:init_count
  let tmp = s:init_count
  let s:init_count = 0

  "signal 15 is SIGTERM
  call s:gosh_comp.kill(15)
  call gosh_complete#init_proc()

  " restore s:init_count
  let s:init_count = tmp
endfunction"}}}

function! gosh_complete#add_async_task(text, callback, context)"{{{
  if empty(s:async_task_queue)
    call s:gosh_comp.stdin.write(a:text)
    call add(s:async_task_queue, {'callback':a:callback, 'time' : localtime(), 'context' : a:context})
  else
    call add(s:async_task_queue, {'text' : a:text, 'callback': a:callback, 'context' : a:context})
  endif
endfunction

function! gosh_complete#is_empty_async_task()
  return empty(s:async_task_queue)
endfunction

function! gosh_complete#check_async_task()
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
    call Callback(out, err, finish_task['context'])

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

  let res = a:port.read(-1, 0)
  if !empty(res)
    while 1
      let len = strlen(res)
      if res[len - 1] ==# "\n"
        let out .= strpart(res, 0, len - 1)
        break
      else
        let out .= res
      endif

      let res = a:port.read(-1, 250)
    endwhile
  endif

  return out
endfunction"}}}


"
"open gosh info buffer

function! s:open_preview(content, noenter, open_cmd)"{{{
  if a:noenter
    call s:mark_back_to_window()
  endif

  let bufnr = s:move_to_gosh_info_window()

  if bufnr == 0
    call s:open_buffer(a:open_cmd)
    enew
    call s:initialize_buffer()

  else
    setlocal modifiable noreadonly
    % delete _
  endif

  " put content to buffer
  let s:content = a:content
  silent :1 put = s:content | 1 delete _
  unlet! s:content

  setlocal nomodifiable readonly

  if a:noenter
    call s:back_to_marked_window()
  endif

endfunction"}}}

function s:open_buffer(open_cmd)"{{{
  let cmds = split(a:open_cmd, ':')

  let direc = ''

  let len = len(cmds)
  if len == 0
    let split = g:gosh_info_height . 'sp'
  else
    if cmds[0] =~ 'v'
      let split = g:gosh_info_width . 'vs'
    else
      let split = g:gosh_info_height . 'sp'
    endif

    if 1 < len 
      if cmds[1] =~ 'l'
        let tmp_split = &splitright
        let &splitright = 0
        let direc = 'v'

      elseif cmds[1] =~ 'r'
        let tmp_split = &splitright
        let &splitright = 1

        let direc = 'v'
      elseif cmds[1] =~ 'a'
        let tmp_split = &splitbelow
        let &splitbelow = 0

        let direc = 'h'
      elseif cmds[1] =~ 'b'
        let tmp_split = &splitbelow
        let &splitbelow = 1

        let direc = 'h'
      endif
    endif
  endif

  silent! execute split

  if direc ==# 'v'
    let &splitright = tmp_split
  elseif direc ==# 'h'
    let &splitbelow = tmp_split
  endif
endfunction"}}}

function! s:initialize_buffer()"{{{
  setlocal nobuflisted
  setlocal buftype=nofile noswapfile
  setlocal bufhidden=delete
  setlocal nonumber
  setlocal wrap

  setlocal filetype=gosh-info
endfunction"}}}

function! gosh_complete#do_cmd_in_gosh_info(cmd)"{{{
  call s:mark_back_to_window()

  if s:move_to_gosh_info_window()
    execute a:cmd
    call s:back_to_marked_window()
  else
    call s:unmark_back_to_window()
  endif
endfunction

function! s:gosh_info_scroll_down()
  let c = winheight(0) - winline() + 1
  let i = 0

  while i < c && line('.') != line('$')
    execute 'normal j'

    let i += 1
  endwhile
endfunction

function! s:gosh_info_scroll_up()
  let c = winline()
  let i = 0

  while i < c && line('.') != 1
    execute 'normal k'

    let i += 1
  endwhile
endfunction"}}}


function! s:move_to_gosh_info_window()"{{{
  for i in range(0, winnr('$'))
    let n = winbufnr(i)
    if getbufvar(n, '&filetype') ==# 'gosh-info'
      if i != 0
        execute i 'wincmd w'
      endif
      return n
    endif
  endfor

  return 0
endfunction"}}}

function! s:mark_back_to_window()"{{{
  let w:ref_back = 1
endfunction"}}}

function! s:unmark_back_to_window()"{{{
  unlet! w:ref_back
endfunction"}}}

function! s:back_to_marked_window()"{{{
  for t in range(1, tabpagenr('$'))
    for w in range(1, winnr('$'))
      if gettabwinvar(t, w, 'ref_back')
        execute 'tabnext' t
        execute w 'wincmd w'
        unlet! w:ref_back
      endif
    endfor
  endfor
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

" vim: foldmethod=marker
