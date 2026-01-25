echom printf("Hi from nvim")
echom printf("$VIM = %s", $VIM)
echom printf("$VIMRUNTIME = %s", $VIMRUNTIME)

" vim.opt.clipboard = "unnamedplus"
set clipboard=unnamedplus

" scroll up:   <C-y> <C-u>
" scroll down: <C-e> <C-d>
nnoremap <C-r> <C-y>

nnoremap <A-Space> :

" lua require('plugins')
nnoremap <space>f :Oil<CR>

finish
████████████████████████████████████████████████████████████

nnoremap ; i
nnoremap j h
nnoremap k j
nnoremap i k

vnoremap <C-c> "+y
vnoremap c "+y

" if (filereadable("$VIM/runtime/mswin.vim"))
	" source $VIM/runtime/mswin.vim
" endif
if (filereadable(expand("$VIMRUNTIME/mswin.vim")))
	source $VIMRUNTIME/mswin.vim
else
	echom "$VIMRUNTIME/mswin.vim not found"
endif


if (0) " or:
	source C:/nvim/share/nvim/runtime/mswin.vim
	source /usr/share/nvim/runtime/mswin.vim
endif
" source C:/nvim/xvim/open_files.lua


