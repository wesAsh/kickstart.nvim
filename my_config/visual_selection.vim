
" Cursor shapes:
"   Normal mode: block
"   Visual mode: vertical bar (works best with selection=exclusive)
"   Insert mode: thin vertical bar
set guicursor=n:lCursor-blinkon0,v:ver40-vCursor-blinkon0,i-c:ver10-iCursor-blinkon0

" Visual mode:
"   . , extend/reduce selection by character
vnoremap . <S-Right>
vnoremap , <S-Left>

" Visual mode:
"   h/l select previous/next word (muscle memory from old Vim config)
vnoremap l e
vnoremap h b

" Visual selection excludes the character under the cursor (diff than default 'inclusive')
" Looks more natural with a vertical-bar visual cursor.
set selection=exclusive

" Shift+arrows start/extend a selection like a GUI editor.
set keymodel=startsel,stopsel

" Allow arrows, Backspace and Space to continue across line boundaries.
" Needed so Shift+Left/Right selections can flow to previous/next lines.
set whichwrap=b,s,<,>,[,]

