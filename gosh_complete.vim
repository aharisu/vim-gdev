let s:source = {
      \ 'name' : 'gosh-complete',
      \ 'kind' : 'ftplugin',
      \ 'filetypes' : {'scheme' : 1},
      \}

let s:neocom_sources_directory = expand("<sfile>:p:h")
let s:gosh_complete_path = get(g:, 'gosh_complete_path', s:neocom_sources_directory . "/gosh_complete.scm")
let s:async_task_queue = []
let s:word_list = []

function! s:source.initialize()
  if neocomplcache#util#has_vimproc()
    let s:enable = 1
    call s:init_proc()

    augroup neocomplcache
      autocmd FileType scheme call s:doc_parce_proc()
      autocmd CursorHold * call s:cursor_handler('hold')
      autocmd CursorHoldI * call s:cursor_handler('holdi')
      autocmd CursorMoved * call s:cursor_handler('move')
      autocmd CursorMovedI * call s:cursor_handler('movei')
    augroup END

    call s:doc_parce_proc()
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
    return neocomplcache#keyword_filter(copy(s:word_list), a:cur_keyword_str)
  elseif
    return []
  endif
endfunction

function! neocomplcache#sources#gosh_complete#define()
  return s:source
endfunction 

function! s:cursor_handler(type)
  "call neocomplcache#print_warning(a:type)

  call s:check_async_task()
endfunction

function! s:add_doc_list(docs)
  let comp_word_list = []
  let doc_name_list = []

  for doc in a:docs
    let units = doc["units"]
    call map(units, '{"word":v:val["name"], 
          \ "menu":"[" . s:get_unit_module_name(doc["name"])  . "]",  
          \ "kind": s:get_unit_type_kind(v:val["type"]),  
          \ "info" : s:get_unit_info(v:val),
          \ "module" : doc["name"]}')

    call extend(comp_word_list, units)
    call add(doc_name_list, doc["name"])
  endfor

  call filter(s:word_list, '!s:any_doc_name(doc_name_list, v:val)')
  call extend(s:word_list, comp_word_list)
endfunction

function! s:any_doc_name(name_list, word)
  for name in a:name_list
    if a:word["module"] ==# name
      return 1
    endif
  endfor
  return 0
endfunction

function! s:get_unit_type_kind(type)
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
endfunction

function! s:get_unit_module_name(module)
  if match(a:module, '^#') == -1
    return a:module
  else
    return fnamemodify(a:module[2 :], ':t:r')
  endif
endfunction

function! s:get_unit_info(unit)

  let type = a:unit["type"]
  if type ==# 'Function' || type ==# 'Method'
    let info = "(" . a:unit["name"] .  " " . join(map(a:unit["params"], 'v:val["name"]'), ' ') . ")"
  elseif type ==# 'Class'
    let info = a:unit["name"] .  " :" . join(map(a:unit["slots"], 'v:val["name"]'), ' :')
  else
    let info = a:unit["name"]
  endif
    
  if !empty(a:unit["description"])
    let info .= "\n" . a:unit["description"]
  endif

  return info
endfunction

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

function! s:doc_parce_proc()
  let bufnumber = bufnr('%')
  let filename = bufname(bufnumber)
  if empty(filename)
    let filename = '[No Name]'
  endif

  call s:add_async_task("#stdin #" . bufnumber . filename . "\n" .
        \ join(getbufline('%', 1, '$'), "\n") . "\n" .
        \ "#stdin-eof\n", 
        \ function('s:doc_parce_proc_end_callback'))
endfunction

function! s:doc_parce_proc_end_callback(out, err)
  call neocomplcache#print_warning("end parse")

  if !empty(a:out)
    let docs = eval(strpart(a:out, 0, strlen(a:out) - 1))
    call s:add_doc_list(docs)
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

