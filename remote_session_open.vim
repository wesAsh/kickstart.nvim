let s:path = expand('<sfile>:p') " Absolute path of script file

let g:_file_default_bufnum = bufadd("/work/wshabso/.main/.help/files_to_open.txt")

func Session01()
	terminal
	file TMUX
	terminal
	file Claude
endfunc

func Get_current_buffer_path()
	let str = printf("[%s] Choose path", s:path)
	let choice = confirm(str, "&Full path\n&Git root path\n&Name only", 1)
	if (1 == choice)
		let @+ =  expand("%:p")
	elseif (2 == choice)
		echo "no"
	elseif (3 == choice)
		let @+ = expand("%:p:t")
	endif
endfunc

func BufferDelete()
	let bufnum = bufnr()
	exe printf("b %d", g:_file_default_bufnum)
	exe printf("bd %d", bufnum)
endfunc

nnoremap cp :call Get_current_buffer_path()<CR>


finish
source % | call Session01()

