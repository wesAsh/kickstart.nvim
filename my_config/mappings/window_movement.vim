" Window / tab navigation mappings.
" Functions live in functions/window_movement.vim (must be sourced first).

" Move between nvim windows / tmux panes
tnoremap <silent> <A-;> <C-\><C-O>:call WindowRight(0)<CR>
nnoremap <silent> <A-;> :call WindowRight(1)<CR>
tnoremap <silent> <A-a> <C-\><C-O>:call WindowLeft(0)<CR>
nnoremap <silent> <A-a> :call WindowLeft(1)<CR>

" Move out of a terminal window with <C-w>h / <C-w>l
tnoremap <C-w>h <C-\><C-n><C-w>h
tnoremap <C-w>l <C-\><C-n><C-w>l

" Tab-page navigation
nnoremap <C-1> gT
tnoremap <C-1> <C-\><C-O>gT
inoremap <C-1> <C-O>gT
nnoremap <C-2> gt
tnoremap <C-2> <C-\><C-O>gt
inoremap <C-2> <C-O>gt
