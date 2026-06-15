" Indent/fold-aware newline helpers.
" Mappings live in mappings/editing.vim.

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
