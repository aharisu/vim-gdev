let s:source = {
      \ 'name' : 'gosh-complete',
      \ 'kind' : 'ftplugin',
      \ 'filetypes' : {'scheme' : 1},
      \}

let g:gosh_complete_parse_tick =
      \ get(g:, 'gosh_complete_parse_tick', 300)

let s:debug = 0
let s:debug_out_err = 0

let s:neocom_sources_directory = expand("<sfile>:p:h")
let s:gosh_complete_path = get(g:, 'gosh_complete_path', s:neocom_sources_directory . "/gosh_complete.scm")
let s:async_task_queue = []

let s:default_module_order = []
let s:docinfo_table = {}

let s:limit_buffer_parse_filesize = 20000
let s:limit_buffer_parse_linecount = 750
"5 seconds
let s:async_task_timeout = 5

function! s:source.initialize()
  if neocomplcache#util#has_vimproc()
    let s:enable = 1
    call s:init_proc()

    augroup neocomplcache
      autocmd FileType scheme call s:initialize_buffer()
      autocmd BufWritePost * call s:buf_write_post()
      autocmd CursorHold * call s:cursor_hold('hold')
      autocmd CursorHoldI * call s:cursor_hold('holdi')
      autocmd CursorMoved * call s:cursor_moved('move')
      autocmd CursorMovedI * call s:cursor_moved('movei')
      autocmd InsertLeave * call s:parse_cur_buf(0)
    augroup END

    call s:load_default_module()
    call s:initialize_buffer()
  elseif
    let s:enable = 0
    call neocomplcache#print_error("don't has vimproc")
  endif
endfunction

function! s:source.finalize()
  if s:enable
    call s:finale_proc()
  endif
endfunction

function! s:source.get_keyword_pos(cur_text)
  if s:enable && s:check_buffer_init()
    let pattern = "\\%([[:alpha:]_$!&%@\\-\\+\\*/\\?<>=~^;][[:alnum:]_$!&%@\\-\\+\\*/\\?<>=~^:\\.]*\\m\\)$"
    let [cur_keyword_pos, cur_keyword_str] = neocomplcache#match_word(a:cur_text, l:pattern)
    return cur_keyword_pos
  elseif
    return -1
  endif
endfunction

function! s:source.get_complete_words(cur_keyword_pos, cur_keyword_str)
  if s:enable && s:check_buffer_init()

    "It is not necessary to copy?
    return neocomplcache#keyword_filter(copy(b:word_list), a:cur_keyword_str)
  elseif
    return []
  endif
endfunction

function! neocomplcache#sources#gosh_complete#define()
  return s:source
endfunction 

function! s:check_buffer_init()
  if getbufvar(bufnr('%'), '&filetype') != 'scheme'
    return 0
  endif

  if !exists('b:word_list')
    let b:word_list = []
  endif

  if !exists('b:buf_name')
    let b:buf_name = bufname(bufnr('%'))
  endif

  if !exists('b:prev_parse_tick')
    let b:prev_parse_tick = b:changedtick
  endif

  return 1
endfunction

function! s:buf_write_post()
  if !s:check_buffer_init()
    return
  endif

  call s:parse_cur_buf_from_file()
endfunction

function! s:cursor_hold(type)
  call s:parse_cur_buf(1)

  "wait until all tasks
  while !empty(s:async_task_queue)
    call s:check_async_task()
  endwhile
endfunction

function! s:cursor_moved(type)
  call s:check_async_task()
endfunction


function! s:constract_docname(bufnum, bufname)
  if empty(a:bufname)
    return '#' . a:bufnum . '[No Name]'
  else
    return a:bufname
  endif
endfunction

function! s:initialize_buffer()
  if s:debug
    call neocomplcache#print_warning('s:initialize_buffer()')
  endif

  call s:check_buffer_init()

  if !has_key(s:docinfo_table, s:constract_docname(bufnr('%'), b:buf_name))
    call s:parse_cur_buf(1)
  endif
endfunction

function! s:add_doc(docs)"{{{
  for doc in a:docs
    let docname = doc['name']
    let word_list = s:units_to_word_list(docname, doc['units'])

    if has_key(s:docinfo_table, docname)
      let info = s:docinfo_table[docname]
      let info['words'] = word_list
    else
      let s:docinfo_table[docname] = {
            \ 'words' : word_list
            \ }
    endif
  endfor
endfunction

function! s:units_to_word_list(docname, units) "{{{
  let table = {}

  for u in a:units
    let name = u['name']

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
            \ 'kind' : s:get_unit_type_kind(u['type']),
            \ 'info' : s:get_unit_info(u)}
    endif
  endfor

  return values(table)
endfunction "}}}

function! s:get_unit_type_kind(type)"{{{
  if a:type ==# 'Function'
    return 'f'
  elseif a:type ==# 'var'|| a:type ==# 'Constant' || a:type ==# 'Parameter'
    return 'v'
  elseif a:type ==# 'Method'
    return 'm'
  elseif a:type ==# 'Class'
    return 'c'
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

  let type = a:unit["type"]
  if type ==# 'Function' || type ==# 'Method'
    let info = "(" . a:unit["name"]
    let params = join(map(a:unit["params"], 'v:val["name"]'), ' ')
    if !empty(params)
      let info .= " " . params
    endif
    let info .= ")"
  elseif type ==# 'Class'
    let info = a:unit["name"] .  " :" . join(map(a:unit["slots"], 'v:val["name"]'), ' :')
  else
    let info = a:unit["name"]
  endif
    
  if !empty(a:unit["description"])
    let info .= "\n" . a:unit["description"]
  endif

  return info
endfunction"}}}
"}}}

function! s:constract_word_list(order)
  let table = {}

  call s:add_word_list_in_order(table, s:default_module_order)
  call s:add_word_list_in_order(table, a:order)

  let b:word_list = values(table)
endfunction

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

function! s:init_proc()
  let s:gosh_comp = vimproc#popen3('gosh ' . s:gosh_complete_path
        \ . " --generated-doc-directory=" . s:neocom_sources_directory . "/doc"
        \ . ' --loaded-modules="' . join(map(keys(s:docinfo_table), 's:get_loaded_module_name(v:val)'), ' ') . '"')
endfunction

function! s:get_loaded_module_name(docname)
  if match(a:docname, '^#') == -1
    let name = 'm' . a:docname
  else
    let name = 'f' . a:docname[2 :]
    if name ==# '[No Name]'
      let name = ''
    endif
  endif

  return name
endfunction

function! s:finale_proc()
  call s:gosh_comp.stdin.write("#exit\n")
  call s:gosh_comp.waitpid()
endfunction

function! s:load_default_module()
  call s:add_async_task("#load-default-module\n", 
        \ function('s:load_default_module_end_callback'))
endfunction

function! s:load_default_module_end_callback(out, err)
  if s:debug
    call neocomplcache#print_warning("end default parse")
  endif

  if !empty(a:out)
    let result = eval(strpart(a:out, 0, strlen(a:out) - 1))

    let s:default_module_order = result['order']

    call s:add_doc(result['docs'])
    call s:constract_word_list([])
  endif
endfunction

function! s:parse_cur_buf_from_file()
  if s:debug
    call neocomplcache#print_warning('s:parse_cur_buf_from_file()')
  endif

  if !s:check_buffer_init()
    return
  endif

  if b:prev_parse_tick != b:changedtick
    let b:prev_parse_tick = b:changedtick

    call s:parse_cur_buf(1)
  endif
endfunction

function! s:parse_cur_buf(is_force)
  if s:debug
    call neocomplcache#print_warning('s:parse_cur_buf()' . a:is_force)
  endif

  if !s:check_buffer_init()
    return
  endif

  if !a:is_force && 
        \ (b:changedtick - b:prev_parse_tick ) < g:gosh_complete_parse_tick
    return
  endif

  let bufnumber = bufnr('%')
  let filename = bufname(bufnumber)
  let docname = s:constract_docname(bufnumber, filename)
  if empty(filename) || b:changedtick != b:prev_parse_tick

    if empty(filename)
      let filesize = 0
    else
      let filesize = getfsize(fnamemodify(filename, ':p'))
    endif

    if filesize < s:limit_buffer_parse_filesize
          \ && line('$') < s:limit_buffer_parse_linecount
      let b:prev_parse_tick = b:changedtick


      "parse from buffer
      call s:add_async_task('#stdin ' . docname . "\n" .
            \ join(getbufline('%', 1, '$'), "\n") . "\n" .
            \ "#stdin-eof\n", 
            \ function('s:parse_cur_buf_end_callback'))
    endif
  else

    "parse from file
    call s:add_async_task('#load-file ' . fnamemodify(filename, ':p') . ' ' . docname . "\n",
          \ function('s:parse_cur_buf_end_callback'))
  endif

endfunction

function! s:parse_cur_buf_end_callback(out, err)
  if s:debug
    call neocomplcache#print_warning("end parse")
  endif

  if !empty(a:out)
    let result = eval(strpart(a:out, 0, strlen(a:out) - 1))

    call s:add_doc(result['docs'])
    call s:constract_word_list(result['order'])
  endif
endfunction

function! s:restart_gosh_process()
  "signal 15 is SIGTERM
  call s:gosh_comp.kill(15)
  call s:init_proc()
endfunction

function! s:add_async_task(text, callback)
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
  while !empty(res)
    let out .= res
    let res = a:port.read()
  endwhile
  return out
endfunction

" vim: foldmethod=marker
