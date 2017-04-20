" Vim indent file
" Language:        AWK Script
" Maintainer:      Clavelito <maromomo@hotmail.com>
" Id:              $Date: 2014-01-07 12:49:27+09 $
"                  $Revision: 1.46 $


if exists("b:did_indent")
  finish
endif
let b:did_indent = 1

setlocal indentexpr=GetAwkIndent()
setlocal indentkeys-=0#

if exists("*GetAwkIndent")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

function GetAwkIndent()
  let lnum = prevnonblank(v:lnum - 1)
  if lnum == 0
    return 0
  endif

  let cline = getline(v:lnum)
  if cline =~ '^#'
    return 0
  endif

  let line = getline(lnum)
  if  line =~ '^\s*#' && cline =~ '^\s*$'
    let ind = indent(lnum)
    return ind
  endif

  let ind = s:ContinueLineIndent(line, lnum)
  let stop = lnum
  let [line, lnum] = s:JoinContinueLine(
        \ line, lnum, '\\$\|\%(&&\|||\|,\)\s*\%(#.*\)\=$', 0)
  let [pline, pnum] = s:JoinContinueLine(
        \ line, lnum, '\\$\|\%(&&\|||\|,\)\s*\%(#.*\)\=$', 1)
  let ind = s:MorePrevLineIndent(pline, pnum, line, lnum, ind)
  let ind = s:PrevLineIndent(line, lnum, stop, ind)
  let ind = s:CurrentLineIndent(cline, line, lnum, pline, pnum, ind)

  return ind
endfunction

function s:ContinueLineIndent(line, lnum)
  let [pline, line, ind] = s:PreContinueLine(a:line, a:lnum)
  if line =~ '(\s*\%(\S\+\s*,\s*\)\+\%(#.*\)\=$'
        \ || line =~ '(\s*\%(\S\+\s*,\s*\)\+\\$'
    let ind = s:GetMatchWidth(line, '(')
    let line = substitute(line, '^.*(', '', '')
    let ind = ind + match(line, '\S') + 1
  elseif line =~ '\S\+\s*,\s*\%(#.*\)\=$' || line =~ '\S\+\s*,\s*\\$'
    let ind = s:GetMatchWidth(line, '\S\+\s*,')
  elseif line =~# '^\s*\%(function\s\+\)\=\h\w*(\s*\\$'
    let ind = s:GetMatchWidth(line, '(') + 1
  elseif line =~# '^\s*\%(if\|else\s\+if\|for\|}\=\s*while\)\>'
        \ && line =~ '\\$\|\%(&&\|||\)\s*\%(#.*\)\=$'
    let ind = ind + &sw * 2
  elseif ind && pline !~ '\\$' && line =~ '\\$'
    let ind = ind + &sw
  elseif ind && pline =~ '\\$' && line !~ '\\$\|\%(&&\|||\|,\)\s*\%(#.*\)\=$'
    let ind = ind - &sw
  endif

  return ind
endfunction

function s:MorePrevLineIndent(pline, pnum, line, lnum, ind)
  if a:line =~ '\\$\|\%(&&\|||\|,\)\s*\%(#.*\)\=$'
    return a:ind
  endif

  let [pline, pnum, ind] = s:PreMorePrevLine(a:pline, a:pnum, a:line, a:lnum)
  while pnum
        \ &&
        \ (pline =~# '^\s*\%(if\|else\s\+if\|for\|while\)\s*(.*)\s*\%(#.*\)\=$'
        \ || pline =~# '^\s*}\=\s*else\>\s*\%(#.*\)\=$'
        \ || pline =~# '^\s*do\>\s*\%(#.*\)\=$'
        \ || pline =~# '^\s*}\s*\%(else\s\+if\|while\)\s*(.*)\s*\%(#.*\)\=$')
    let ind = indent(pnum)
    if pline =~# '^\s*do\>\s*\%(#.*\)\=$'
          \ && s:NoClosedPair(pnum, '\C\<do\>', '\C\<while\>', a:lnum)
      break
    elseif pline =~# '^\s*}\=\s*else\>'
      let [pline, pnum] = s:GetIfLine(pline, pnum)
    elseif pline =~# '^\s*}\=\s*while\>'
      let [pline, pnum] = s:GetDoLine(pline, pnum, pnum)
    endif
    let [pline, pnum] = s:JoinContinueLine(
          \ pline, pnum, '\\$\|\%(&&\|||\|,\)\s*\%(#.*\)\=$', 1)
  endwhile

  return ind
endfunction

function s:PrevLineIndent(line, lnum, stop, ind)
  let ind = a:ind
  if a:line =~# '^\s*\%(if\|else\s\+if\|for\)\s*(.*)\s*{\=\s*\%(#.*\)\=$'
        \ || a:line =~# '^\s*\%(else\|do\)\s*{\=\s*\%(#.*\)\=$'
        \ || a:line =~# '^\s*}\s*else\s*{\=\s*\%(#.*\)\=$'
        \ || a:line =~# '^\s*}\s*else\s\+if\s*(.*)\s*{\=\s*\%(#.*\)\=$'
        \ || a:line =~# '^\s*while\s*(.*)\s*{\s*\%(#.*\)\=$'
        \ || a:line =~# '^\s*while\s*(.*)\s*\%(#.*\)\=$'
        \ && get(s:GetDoLine(a:line, a:lnum, a:lnum), 1) == a:lnum
        \ || a:line =~ '^\s*{\s*\%(#.*\)\=$'
    let ind = indent(a:lnum) + &sw
  elseif a:line =~# '^\s*}\=\s*while\s*(.*)\s*\%(#.*\)\=$' && a:lnum != a:stop
    let [pline, pnum] = s:GetDoLine(a:line, a:lnum, a:lnum)
    let ind = indent(pnum)
    let ind = s:MorePrevLineIndent(pline, pnum, a:line, a:lnum, ind)
  elseif a:line =~ ')\s*{\s*\%(#.*\)\=$'
    let ind = indent(get(s:GetStartPairLine(a:line, ')', '(', a:lnum), 1)) + &sw
  elseif a:line =~ '{' && s:NoClosedPair(a:lnum, '{', '}', a:stop)
    let ind = indent(a:lnum) + &sw
  elseif a:line =~ '\S\+\s*}\s*\%(#.*\)\=$'
    let ind = indent(get(s:GetStartPairLine(a:line, '}', '{', a:lnum), 1))
  elseif a:line =~# '^\s*\%(function\s\+\)\=\h\w*('
        \ && a:line =~ '\%(,\s*\)\@<!\\$' && a:lnum != a:stop
    let ind = s:GetMatchWidth(a:line, '(')
  elseif a:line =~# '^\s*\(case\|default\)\>'
    let ind = ind + &sw
  endif

  return ind
endfunction

function s:CurrentLineIndent(cline, line, lnum, pline, pnum, ind)
  let ind = a:ind
  if a:cline =~ '^\s*}'
    let ind = ind - &sw
  elseif a:cline =~ '^\s*{\s*\%(#.*\)\=$'
        \ &&
        \ (a:line =~# '^\s*\%(if\|else\s\+if\|while\|for\)\s*(.*)\s*\%(#.*\)\=$'
        \ || a:line =~# '^\s*\%(else\|do\)\s*\%(#.*\)\=$'
        \ || a:line =~# '^\s*\(case\|default\)\>.*:\s*\%(#.*\)\=$')
    let ind = ind - &sw
  elseif a:cline =~# '^\s*else\>'
    let ind = s:CurrentElseIndent(a:line, a:lnum, a:pline, a:pnum)
  elseif a:cline =~# '^\s*\(case\|default\)\>'
        \ && a:line !~ '\({\|}\)\s*\%(#.*\)\=$'
    let ind = ind - &sw
  endif

  return ind
endfunction

function s:PreContinueLine(line, lnum)
  let [line, lnum] = s:SkipCommentLine(a:line, a:lnum)
  let pnum = prevnonblank(lnum - 1)
  let pline = getline(pnum)
  let [pline, pnum] = s:SkipCommentLine(pline, pnum)
  let ind = indent(lnum)

  return [pline, line, ind]
endfunction

function s:JoinContinueLine(line, lnum, item, prev)
  if a:prev && s:GetPrevNonBlank(a:lnum)
    let lnum = s:prev_lnum
    let line = getline(lnum)
  elseif a:prev
    let lnum = 0
    let line = ""
  else
    let line = a:line
    let lnum = a:lnum
  endif
  let [line, lnum] = s:SkipCommentLine(line, lnum)
  while lnum && s:GetPrevNonBlank(lnum)
    let pline = getline(s:prev_lnum)
    if pline !~ a:item
      break
    endif
    let lnum = s:prev_lnum
    let line = pline . line
  endwhile
  unlet! s:prev_lnum

  return [line, lnum]
endfunction

function s:SkipCommentLine(line, lnum)
  let line = a:line
  let lnum = a:lnum
  while lnum && line =~ '^\s*#' && s:GetPrevNonBlank(lnum)
    let lnum = s:prev_lnum
    let line = getline(lnum)
  endwhile
  unlet! s:prev_lnum

  return [line, lnum]
endfunction

function s:GetPrevNonBlank(lnum)
  let s:prev_lnum = prevnonblank(a:lnum - 1)

  return s:prev_lnum
endfunction

function s:PreMorePrevLine(pline, pnum, line, lnum)
  let lnum = a:lnum
  if a:line =~# '^\s*}\=\s*while\>'
    let [line, lnum] = s:GetDoLine(a:line, a:lnum, a:lnum)
  elseif a:line =~# '\s*}\=\s*else\>'
    let [line, lnum] = s:GetIfLine(a:line, a:lnum)
  elseif a:line =~ '^\s*}' || a:line =~ '\S\+\s*}\s*\%(#.*\)\=$'
    let [line, lnum] = s:GetStartBraceLine(a:line, a:lnum)
  elseif a:line =~ ')\s*\%(#.*\)\=$'
    let [line, lnum] = s:GetStartPairLine(a:line, ')', '(', a:lnum)
  endif
  if lnum != a:lnum
    let [pline, pnum] = s:JoinContinueLine(
          \ line, lnum, '\\$\|\%(&&\|||\|,\)\s*\%(#.*\)\=$', 1)
  else
    let pline = a:pline
    let pnum = a:pnum
  endif
  let ind = indent(lnum)

  return [pline, pnum, ind]
endfunction

function s:GetStartBraceLine(line, lnum)
  let line = a:line
  let lnum = a:lnum
  let [line, lnum] = s:GetStartPairLine(line, '}', '{', lnum)
  if line =~# '^\s*}\=\s*else\>'
    let [line, lnum] = s:GetIfLine(line, lnum)
  endif

  return [line, lnum]
endfunction

function s:GetStartPairLine(line, item1, item2, lnum)
  let save_cursor = getpos(".")
  call cursor(a:lnum, len(a:line))
  let lnum = search(a:item1, 'cbW', a:lnum)
  while lnum && s:InsideAwkItemOrCommentStr()
    let lnum = search(a:item1, 'bW', a:lnum)
  endwhile
  if lnum
    let lnum = searchpair(
          \ a:item2, '', a:item1, 'bW', 's:InsideAwkItemOrCommentStr()')
  endif
  if lnum > 0
    let line = getline(lnum)
    if line =~ ')\s*{' && a:item1 == '}' && a:item2 == '{'
      let [line, lnum] = s:GetStartPairLine(line, ')', '(', lnum)
    endif
  else
    let line = a:line
    let lnum = a:lnum
  endif
  call setpos('.', save_cursor)

  return [line, lnum]
endfunction

function s:GetIfLine(line, lnum)
  let save_cursor = getpos(".")
  call cursor(a:lnum, 1)
  let lnum = searchpair('\C\<if\>', '', '\C\<else\>', 'bW',
        \ 'getline(".") =~# "else\\s\\+if" ' .
        \ '|| indent(line(".")) > indent(a:lnum) ' .
        \ '|| s:InsideAwkItemOrCommentStr()')
  call setpos('.', save_cursor)
  if lnum > 0
    let line = getline(lnum)
    let nnum = lnum
    while nnum && line =~ '\\$\|\%(&&\|||\)\s*\%(#.*\)\=$'
      let nnum = nextnonblank(nnum + 1)
      let nline = getline(nnum)
      let line = line . nline
    endwhile
  else
    let line = a:line
    let lnum = a:lnum
  endif

  return [line, lnum]
endfunction

function s:GetDoLine(line, lnum, snum)
  let save_cursor = getpos(".")
  call cursor(a:lnum, 1)
  let lnum = s:SearchDoLoop(a:snum)
  call setpos('.', save_cursor)
  if lnum > 0
    let line = getline(lnum)
  else
    let line = a:line
    let lnum = a:lnum
  endif

  return [line, lnum]
endfunction

function s:SearchDoLoop(snum)
  let lnum = 0
  let onum = 0
  while search('\C^\s*do\>', 'ebW')
    let save_cursor = getpos(".")
    let lnum = searchpair('\C\<do\>', '', '\C\<while\>', 'W',
          \ 'indent(line(".")) > indent(get(save_cursor, 1)) ' .
          \ '|| s:InsideAwkItemOrCommentStr()', a:snum)
    if lnum < onum || lnum < 1
      let lnum = 0
      break
    elseif lnum == a:snum
      let lnum = get(save_cursor, 1)
      break
    else
      let onum = lnum
      let lnum = 0
    endif
    call setpos('.', save_cursor)
  endwhile

  return lnum
endfunction

function s:NoClosedPair(lnum, item1, item2, stop)
  let snum = 0
  let enum = 0
  let save_cursor = getpos(".")
  call cursor(a:lnum, 1)
  let snum = search(a:item1, 'cW', a:stop)
  while snum && s:InsideAwkItemOrCommentStr()
    let snum = search(a:item1, 'W', a:stop)
  endwhile
  if snum
    let enum = searchpair(
          \ a:item1, '', a:item2, 'W', 's:InsideAwkItemOrCommentStr()')
  endif
  call setpos('.', save_cursor)

  if snum == enum
    return 0
  else
    return 1
  endif
endfunction

function s:GetMatchWidth(line, item)
  let msum = match(a:line, a:item)
  let tsum = matchend(a:line, '\t*', 0)

  return msum - tsum + tsum * &sw
endfunction

function s:CurrentElseIndent(line, lnum, pline, pnum)
  if a:line =~# '^\s*\%(if\|else\s\+if\)\s*(.*)\s*\%([^#].*\)'
        \ && a:line !~ '{\s*\%(#.*\)\=$'
    let ind = indent(a:lnum)
  elseif a:line =~# '^\s*else\>\s\+\%([^#].*\)' && a:line !~ '{\s*\%(#.*\)\=$'
    let ind = indent(a:lnum) - &sw
  elseif a:pline =~# '^\s*\%(if\|}\=\s*else\s\+if\)\s*(.*)\s*\%(#.*\)\=$'
    let ind = indent(a:pnum)
  elseif a:pline =~# '^\s*\%(}\s*\)\=else\>\s*\%(#.*\)\=$'
    let ind = indent(a:pnum) - &sw
  else
    let ind = indent(get(s:GetIfLine(a:line, a:lnum), 1))
  endif

  return ind
endfunction

function s:InsideAwkItemOrCommentStr()
  let line = getline(line("."))
  let cnum = col(".")
  let sum = match(line, '\S')
  let slash = 0
  let dquote = 0
  let bracket = 0
  while sum < cnum
    let str = strpart(line, sum, 1)
    if str == '#' && !slash && !dquote
      return 1
    elseif str == '\' && (slash || dquote) && strpart(line, sum + 1, 1) == '\'
      let str = laststr
      let sum += 1
    elseif str == '[' && (slash || dquote) && !bracket && laststr != '\'
      let bracket = 1
      if strpart(line, sum + 1, 1) == ']'
        let str = ']'
        let sum += 1
      endif
    elseif str == ']' && (slash || dquote) && bracket && laststr != '\'
      let bracket = 0
    elseif str == '/' && !slash && !dquote
          \ && (!exists("nb_laststr")
          \ || nb_laststr =~ '\%(}\|(\|\%o176\|,\|=\|&\||\|!\)')
      let slash = 1
    elseif str == '/' && slash && laststr != '\' && !bracket
      let slash = 0
    elseif str == '"' && !dquote && !slash
      let dquote = 1
    elseif str == '"' && dquote && laststr != '\' && !bracket
      let dquote = 0
    endif
    if str !~ '\s'
      let nb_laststr = str
    endif
    let laststr = str
    let sum += 1
  endwhile

  if slash || dquote
    return 1
  else
    return 0
  endif
endfunction

let &cpo = s:cpo_save
unlet s:cpo_save

" vim: set sts=2 sw=2 expandtab smarttab:
