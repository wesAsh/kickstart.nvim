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
tnoremap <A-Space> <C-\><C-O>:

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

tnoremap <Esc><Esc> <C-\><C-n>
tnoremap jk <C-\><C-n>
nnoremap <C-a> :buffer #<CR>
tnoremap <C-a> <C-\><C-O>:buffer #<CR>
inoremap <C-a> <C-O>:buffer #<CR>

nnoremap <A-BS> u
" nnoremap u :Telescope buffers<CR>

nnoremap <C-r> <C-y>


nnoremap . <right>
nnoremap , <left>

set virtualedit=onemore,block

" Annoying -- SELECT -- mode where esc doesn't work...
set selectmode=mouse,key
set selectmode=



set scrolloff=8      | " keep X lines above and below the cursor when scrolling
set scrolloff=0
set sidescrolloff=8

nnoremap <C-s> :update<CR>

nnoremap cfp :let @+ = expand("%:p")<CR>



hi BufferLineBufferSelected  guifg=#ffffff guibg=#3b4261 gui=bold
hi BufferLineNumbersSelected guifg=#ffffff guibg=#3b4261 gui=bold

" How NOT to do it (yank-hack, shadowed by the line below):
" nnoremap g<Space> ^v$"pygj:<C-R>p<CR>
nnoremap g<Space> :<C-U>execute trim(getline('.'))<CR>gj

nnoremap . <right>
nnoremap , <left>

nnoremap cl V"py"pgP

" Insert an underscore (window movement lives in mappings/window_movement.vim)
inoremap <A-d> _
cnoremap <A-d> _
tnoremap <A-d> _


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


