" Window / tmux-pane navigation functions.
" When the current buffer is a TMUX terminal, hand the motion off to tmux
" (<M-;> / <M-a>); otherwise move between nvim windows.
" Mappings live in mappings/window_movement.vim.

function! WindowRight(is_normal_mode)
    if bufname('%') =~# 'TMUX'
	    if (a:is_normal_mode)
		    startinsert
	    endif
        call feedkeys("\<M-;>", "n")
    else
	    wincmd w
    endif
endfunction

function! WindowLeft(is_normal_mode)
    if bufname('%') =~# 'TMUX'
	if (a:is_normal_mode)
		startinsert
	endif
        call feedkeys("\<M-a>", "n")
    else
	wincmd W
    endif
endfunction
