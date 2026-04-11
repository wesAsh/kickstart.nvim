let s:path = expand('<sfile>:p') " Absolute path of script file

echom printf("[%s] Hi from nvim", s:path)
echom printf("$VIM = %s", $VIM)
echom printf("$VIMRUNTIME = %s", $VIMRUNTIME)

" vim.opt.clipboard = "unnamedplus"
set clipboard=unnamedplus
set fileformats=unix,dos

" scroll up:   <C-y> <C-u>
" scroll down: <C-e> <C-d>
" nnoremap <C-r> <C-y>

nnoremap <A-Space> :

" lua require('plugins')
nnoremap <space>f :Oil<CR>

nnoremap <space>of :Oil<CR>
nnoremap <space>od :Oil /work/wshabso/<CR>
nnoremap <Space>oh :Oil ~<CR>

vnoremap ya "ay
nnoremap pa "agP
vnoremap c  "+y
vnoremap <C-c> "+y
nnoremap <C-v> "+gP
cnoremap <C-v> <C-R>+
inoremap <C-v> <C-O>"+gP

tnoremap jk <C-\><C-n>
nnoremap <C-a> :buffer #<CR>
tnoremap <C-a> <C-\><C-O>:buffer #<CR>
inoremap <C-a> <C-O>:buffer #<CR>

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


