let s:source = {
      \ 'name' : 'gosh-complete',
      \ 'kind' : 'ftplugin',
      \ 'filetypes' : {'scheme' : 1},
      \}

let s:gosh_complete_path = get(g:, 'gosh_complete_path', expand("<sfile>:p:h") . "/gosh_complete.scm")

function! s:source.initialize()
  if neocomplcache#util#has_vimproc()
    let s:enable = 1
    call s:init_proc()

    augroup neocomplcache
      autocmd FileType scheme call s:doc_parce_proc()
      autocmd CursorHold * call s:doc_parce_proc()
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
    let units = s:get_unit_list(a:cur_keyword_str)

    call map(units, '{"word" : v:val["name"], "menu" : "[gosh]"}')
    return units
  elseif
    return []
  endif
endfunction

function! neocomplcache#sources#gosh_complete#define()
  return s:source
endfunction 

"
" Communicate to gosh-complete.scm

function! s:init_proc()
  let s:gosh_comp = vimproc#popen3('gosh ' . s:gosh_complete_path)
endfunction

function! s:finale_proc()
  call s:gosh_comp.stdin.write("#exit\n")
  call s:gosh_comp.waitpid()
endfunction

function! s:get_unit_list(symbol)
  call s:gosh_comp.stdin.write(a:symbol . "\n")

  let [out, err] = s:read_output(s:gosh_comp)
  if !empty(err)
    "error
    return []
  endif
  
  "ok without a check?
  return  eval(strpart(out, 0, strlen(out) - 1))
endfunction

function! s:doc_parce_proc()
  call s:gosh_comp.stdin.write("#stdin " . bufnr('%') . "\n")
  call s:gosh_comp.stdin.write(join(getline(1, line('$')), "\n") . "\n")
  call s:gosh_comp.stdin.write("#stdin-eof\n")
  call s:check_error()
endfunction

function! s:check_error()
  let [out, err] = s:read_output(s:gosh_comp)

  if empty(err)
    return 0
  else
    call neocomplcache#print_warning("error:" . err)
    return 1
  endif
endfunction

let s:retry_count = 3
function! s:read_output(proc)
  let c = 0

  let res_out = a:proc.stdout.read()
  let res_err = a:proc.stderr.read()
  while c < s:retry_count
    if empty(res_out) && empty(res_err)
      let c += 1
    elseif !empty(res_out)
      let port = a:proc.stdout
      let out = res_out
      let port_kind = 1
      break
    else
      let port = a:proc.stderr
      let out = res_err
      let port_kind = 0
      break
    endif

    let res_out = a:proc.stdout.read()
    let res_err = a:proc.stderr.read()
  endwhile

  if exists('port')
    let res_out = port.read()
    while !empty(res_out)
      let out .= res_out
      let res_out = port.read()
    endwhile

    return port_kind ? [out, ""] : ["", out]
  else
    return ["", ""]
  endif
endfunction

