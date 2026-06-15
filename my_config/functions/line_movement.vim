" Motions that stay on the current line (word-wise for now; start/end-of-line
" helpers can be added here later).
" Mappings live in mappings/line_movement.vim.

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
