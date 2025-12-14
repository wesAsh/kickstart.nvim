echom printf("Hi from nvim")
echom printf("$VIM = %s", $VIM)
echom printf("$VIMRUNTIME = %s", $VIMRUNTIME)

nnoremap ; i
nnoremap j h
nnoremap k j
nnoremap i k

vnoremap <C-c> "+y
vnoremap c "+y

if (filereadable("$VIM/runtime/mswin.vim"))
	source $VIM/runtime/mswin.vim
endif
if (0) " or:
	source C:/nvim/share/nvim/runtime/mswin.vim
endif
" source C:/nvim/xvim/open_files.lua

nnoremap <C-r> <C-y>

" lua require('plugins')
nnoremap <space>f :Oil<CR>
