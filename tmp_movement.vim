func __WordRightOnLineSmall()
"⌠
	if (col('.') == col('$'))
		normal! g_l
		return
	endif
	
	let curLine = line('.')
	let lastCol = col('$')
	normal! w
	if (curLine != line('.'))
		call cursor(curLine, lastCol)
	endif
endfunc "⌡
func __WordLeftOnLineSmall()
"⌠
	if (1 == col('.'))
		normal! ^
		return
	endif
	
	let curLine = line('.')
	normal! b
	if (curLine != line("."))
		call cursor(curLine, 1)
	endif
endfunc "⌡


" maybe should be elsewhere
func __HitEnter()
"⌠
	let startFold = foldclosed('.')
	if (-1 != startFold)
		call cursor(startFold, 1)
	endif
	
	let spaces1 = matchstr(getline('.'), "^\\s*")
	exe "normal! i\<CR>"
	let spaces2 = matchstr(getline('.'), "^\\s*")
	if (spaces1 != spaces2)
		call setline(line('.'), substitute(getline('.'), "^\\s*", spaces1, ''))
	endif
	normal! g^
endfunc "⌡
func __HitAlt_O()
"⌠
	let lastFold = foldclosedend('.')
	if (-1 != lastFold)
		call cursor(lastFold, 1)
	endif
	let spaces = matchstr(getline('.'), "^\\s*")
	call append(line('.'), spaces)
	normal! j$l
endfunc "⌡



nnoremap <silent> l :silent! call __WordRightOnLineSmall()<CR>
nnoremap <silent> h :silent! call __WordLeftOnLineSmall()<CR>
nnoremap <silent> <CR> :call __HitEnter()<CR>
nnoremap <silent> <A-o> :silent! call __HitAlt_O()<CR>

