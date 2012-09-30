"=============================================================================
" FILE: gdev.vim
" AUTHOR:  aharisu <foo.yobina@gmail.com>
" Last Modified: 30 Sep 2012.
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

if exists("loaded_gdev")
  finish
endif
let loaded_gdev = 1

let s:save_cpo = &cpo
set cpo&vim

nnoremap <silent> <Plug>(gosh_goto_define) :call gdev#gosh_goto_define(bufnr('%'), expand('<cword>'), 0)<CR>
nnoremap <silent> <Plug>(gosh_goto_define_split) :call gdev#gosh_goto_define(bufnr('%'), expand('<cword>'), 1)<CR>

let &cpo = s:save_cpo

