let s:source = {
      \ 'name' : 'gosh-complete',
      \ 'kind' : 'ftplugin',
      \ 'filetypes' : {'scheme' : 1},
      \}

let g:gosh_complete_parse_tick =
      \ get(g:, 'gosh_complete_parse_tick', 50)

let s:neocom_sources_directory = expand("<sfile>:p:h")
let s:gosh_complete_path = get(g:, 'gosh_complete_path', s:neocom_sources_directory . "/gosh_complete.scm")
let s:async_task_queue = []

let s:default_module_order = []
let s:docinfo_table = {}

function! s:source.initialize()
  if neocomplcache#util#has_vimproc()
    let s:enable = 1
    call s:init_proc()

    augroup neocomplcache
      autocmd FileType scheme call s:initialize_buffer()
      autocmd BufWritePost * call s:parse_cur_buf_from_file()
      autocmd CursorHold * call s:cursor_hold('hold')
      autocmd CursorHoldI * call s:cursor_hold('holdi')
      autocmd CursorMoved * call s:cursor_moved('move')
      autocmd CursorMovedI * call s:cursor_moved('movei')
    augroup END

    call s:load_defualt_module()
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
  if s:enable
    let pattern = "\\%([[:alpha:]_$!&%@\\-\\+\\*/\\?<>=~^;][[:alnum:]_$!&%@\\-\\+\\*/\\?<>=~^:\\.]*\\m\\)$"
    let [cur_keyword_pos, cur_keyword_str] = neocomplcache#match_word(a:cur_text, l:pattern)
    return cur_keyword_pos
  elseif
    return -1
  endif
endfunction

function! s:source.get_complete_words(cur_keyword_pos, cur_keyword_str)
  if s:enable
    "It is not necessary to copy?
    return neocomplcache#keyword_filter(copy(b:word_list), a:cur_keyword_str)
  elseif
    return []
  endif
endfunction

function! neocomplcache#sources#gosh_complete#define()
  return s:source
endfunction 



function! s:cursor_hold(type)
  "call neocomplcache#print_warning(a:type)

  call s:parse_cur_buf(1)

  "wait until all tasks
  while !empty(s:async_task_queue)
    call s:check_async_task()
  endwhile
endfunction

function! s:cursor_moved(type)
  "call neocomplcache#print_warning(a:type)

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

  if !exists('b:word_list')
    let b:word_list = []
  endif

  let bufnum = bufnr('%')
  let b:buf_name = bufname(bufnum)
  let docname = s:constract_docname(bufnum, b:buf_name)
  let b:prev_parse_tick = b:changedtick

  if !has_key(s:docinfo_table, docname)
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
        \ . " --generated-doc-directory=" . s:neocom_sources_directory . "/doc")
endfunction

function! s:finale_proc()
  call s:gosh_comp.stdin.write("#exit\n")
  call s:gosh_comp.waitpid()
endfunction

function! s:load_defualt_module()
  call s:add_async_task("#load-defualt-module\n", 
        \ function('s:load_defualt_module_end_callback'))
endfunction

function! s:load_defualt_module_end_callback(out, err)
  "call neocomplcache#print_warning("end defualt parse")

  if !empty(a:out)
    let result = eval(strpart(a:out, 0, strlen(a:out) - 1))

    let s:default_module_order = result['order']

    call s:add_doc(result['docs'])
    call s:constract_word_list([])
  endif
endfunction

function! s:parse_cur_buf_from_file()
  if b:prev_parse_tick != b:changedtick
    let b:prev_parse_tick = b:changedtick
    call s:parse_cur_buf(1)
  endif
endfunction

function! s:parse_cur_buf(is_force)
  if !a:is_force && 
        \ (b:changedtick - b:prev_parse_tick ) < g:gosh_complete_parse_tick
    return
  endif

  let bufnumber = bufnr('%')
  let filename = bufname(bufnumber)
  let docname = s:constract_docname(bufnumber, filename)
  if empty(filename) || b:changedtick != b:prev_parse_tick
    let b:prev_parse_tick = b:changedtick

    "call neocomplcache#print_warning('from buffer')

    "parse from buffer
    call s:add_async_task('#stdin ' . docname . "\n" .
          \ join(getbufline('%', 1, '$'), "\n") . "\n" .
          \ "#stdin-eof\n", 
          \ function('s:parce_cur_buf_end_callback'))
  else
    "call neocomplcache#print_warning('from file')

    "parse from file
    call s:add_async_task('#load-file ' . fnamemodify(filename, ':p') . ' ' . docname . "\n",
          \ function('s:parce_cur_buf_end_callback'))
  endif

endfunction

function! s:parce_cur_buf_end_callback(out, err)
  "call neocomplcache#print_warning("end parse")

  if !empty(a:out)
    let result = eval(strpart(a:out, 0, strlen(a:out) - 1))

    call s:add_doc(result['docs'])
    call s:constract_word_list(result['order'])
  endif
endfunction

function! s:add_async_task(text, callback)
  if empty(s:async_task_queue)
    call s:gosh_comp.stdin.write(a:text)
    call add(s:async_task_queue, [a:callback])
  else
    call add(s:async_task_queue, [a:text, a:callback])
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

  if !empty(out) || !empty(err)
    let [Callback] = remove(s:async_task_queue, 0)
    call Callback(out, err)

    "execution next task
    let task = get(s:async_task_queue, 0)
    if task isnot 0
      call s:gosh_comp.stdin.write(task[0])
      call remove(task, 0)
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
