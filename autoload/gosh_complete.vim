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

function! gosh_complete#add_doc(name, units, extend)
  for unit in a:units
    let unit['docname'] = a:name
  endfor

  if has_key(s:ginfo_table, a:name)
    let s:ginfo_table[a:name]['units'] = a:units
    let s:ginfo_table[a:name]['extend'] = a:extend
  else
    let s:ginfo_table[a:name] = {
          \ 'units' : a:units,
          \ 'extend' : a:extend
          \ }
  endif
endfunction

function! gosh_complete#set_buf_data(buf_num, name, data)
  if has_key(s:each_buf_data, a:buf_num)
    let s:each_buf_data[a:buf_num][a:name] = a:data
  else
    let s:each_buf_data[a:buf_num] = {
          \ a:name : a:data
          \ }
  endif
endfunction

function! gosh_complete#get_buf_data(buf_num, name, ...)
  if has_key(s:each_buf_data, a:buf_num) &&
        \ has_key(s:each_buf_data[a:buf_num], a:name)
    return s:each_buf_data[a:buf_num][a:name]
  elseif a:0 > 0
    return a:1
  else
    return 0
  endif
endfunction

function! gosh_complete#set_module_order(buf_num, order)
  call gosh_complete#set_buf_data(a:buf_num, 'order', a:order)
endfunction

function! gosh_complete#get_module_order(buf_num)
  return gosh_complete#get_buf_data(a:buf_num, 'order', [])
endfunction

function! gosh_complete#match_unit_in_order(buf_num, keyword, allow_duplicate)
  if a:allow_duplicate
    return s:match_unit_in_order_allow_duplicate(a:buf_num, a:keyword)
  else
    return s:match_unit_in_order_no_duplicate(a:buf_num, a:keyword)
  endif
endfunction

functio! s:match_unit_in_order_no_duplicate(buf_num, keyword)
  let unit_table = {}

  for mod in gosh_complete#get_module_order(a:buf_num)
    if !has_key(s:ginfo_table, mod)
      continue
    endif

    let ginfo = s:ginfo_table[mod]
    if a:keyword == ''
      let units = copy(ginfo['units'])
    else
      let units = s:unit_name_head_filter(ginfo['units'], a:keyword)
    endif

    for unit in units
      let unit_table[unit['n']] = unit
    endfor
  endfor

  return values(unit_table)
endfunction

functio! s:match_unit_in_order_allow_duplicate(buf_num, keyword)
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
      let units = s:unit_name_head_filter(ginfo['units'], a:keyword)
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
endfunction

functio! s:any_name(name, units)
  for unit in a:units
    if a:name ==# unit['n']
      return 1
    endif
  endfor

  return 0
endfunction

function! s:unit_name_head_filter(units, keyword)
  if &ignorecase
    let expr = printf('!stridx(tolower(v:val.n), %s)', tolower(string(a:keyword)))
  else
    let expr = printf('!stridx(v:val.n, %s)', string(a:keyword))
  endif

  return filter(copy(a:units), expr)
endfunction


"
" Communicate to gosh-complete.scm

function! gosh_complete#init_proc()"{{{
  if s:init_count == 0
    let s:gosh_comp = vimproc#popen3('gosh' 
          \ . ' -I' . escape(s:neocom_sources_directory, ' \') . ' '
          \ . s:gosh_complete_path
          \ . " --generated-doc-directory=" . s:gosh_generated_doc_path
          \ . " --output-api-only"
          \ . " --io-encoding=\"" . s:encoding() . "\""
          \ . s:get_loaded_module_text())
  endif

  let s:init_count += 1
endfunction

function s:get_loaded_module_text()"{{{
  let text = ''

  for [name, doc] in items(s:ginfo_table)
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

function! gosh_complete#finale_proc()"{{{
  let s:init_count -= 1

  if s:init_count <= 0
    call s:gosh_comp.stdin.write("#exit\n")
    call s:gosh_comp.waitpid()
    let s:init_count = 0
  endif
endfunction"}}}

function! s:restart_gosh_process()"{{{
  let s:init_count = 0

  "signal 15 is SIGTERM
  call s:gosh_comp.kill(15)
  call s:init_proc()
endfunction"}}}

function! gosh_complete#add_async_task(text, callback)"{{{
  if empty(s:async_task_queue)
    call s:gosh_comp.stdin.write(a:text)
    call add(s:async_task_queue, {'callback':a:callback, 'time' : localtime()})
  else
    call add(s:async_task_queue, {'text' : a:text, 'callback': a:callback})
  endif
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

" vim: foldmethod=marker
