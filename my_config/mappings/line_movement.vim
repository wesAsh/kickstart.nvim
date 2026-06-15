" Word motion that stays on the current line.
" Functions live in functions/line_movement.vim (must be sourced first).

nnoremap <silent> l :silent! call __WordRightOnLineSmall()<CR>
nnoremap <silent> h :silent! call __WordLeftOnLineSmall()<CR>
