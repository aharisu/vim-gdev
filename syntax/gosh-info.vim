" Vim syntax file
" Language:	gosh-info
" Last Change:	2012 May 5
" Maintainer:	aharisu <foo.yobina@gmail.com>
"
if version < 600
  syntax clear
elseif exists("b:current_syntax")
  finish
endif

syn case match

syn keyword gosh_infoKeyword Function Method Variable Constant Parameter Class Macro

syn match gosh_infoTag oneline ,^\s*\a[a-zA-Z ]*:$,
syn match gosh_infoLabel oneline ,^--.*--$,
syn match gosh_infoSlots oneline ,^[ 0-9][0-9]*:.*$,

" Define the default highlighting.
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet
if version >= 508 || !exists("did_gosh_info_syntax_inits")
  if version < 508
    let did_gosh_info_syntax_inits = 1
    command -nargs=+ HiLink hi link <args>
  else
    command -nargs=+ HiLink hi def link <args>
  endif

  HiLink gosh_infoKeyword		Comment
  HiLink gosh_infoTag		Function
  HiLink gosh_infoLabel		Statement
  HiLink gosh_infoSlots		Constant

  delcommand HiLink
endif

let b:current_syntax = "gosh-info"
