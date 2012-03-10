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

let s:ginfo_table = {}
let s:each_buf_data = {}

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

function! gosh_complete#get_loaded_module()
  let table = {}

  for [name, doc] in items(s:ginfo_table)
    let table[name] = doc['extend']
  endfor

  return table
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

  return filter(copy(a:list), expr)
endfunction
