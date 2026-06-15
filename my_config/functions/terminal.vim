" Terminal-buffer helpers.
" Mappings live in mappings/terminal.vim.

func __Hit_q()
	if (&buftype == 'terminal')
		startinsert
		call feedkeys('q')
	endif
endfunc
