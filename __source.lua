
-- Usage (no need to specify type)
source_file 'my_config/init_my.lua'
source_file 'my_config/init_legacy.vim'

source_file 'my_config/telescope_bufferline.lua'
source_file 'my_config/tmp_movement.vim'
-- source_file 'my_config/clipboard.lua'
source_file 'my_config/clipboard_V2.lua'

source_file 'my_config/remote_session_open.vim'

local source = debug.getinfo(1, "S").source
local dirPath = vim.fs.dirname(source:sub(2))
local file_path = dirPath .. "/my_config/remote_session_open.vim"

if vim.fn.filereadable(file_path) == 1 then
  vim.cmd.edit(file_path)
end


--[[
in vimscript:

let dirPath = expand('<sfile>:p:h')  " file directory path

exe printf("luafile %s/init_tmp.lua", dirPath)
exe printf("source  %s/init_tmp.vim", dirPath)
exe printf("source  %s/tmp_movement.vim", dirPath)

" luafile ~/.config/nvim/init_tmp.lua

let file_path = dirPath . "/remote_session_open.vim"
if filereadable(file_path)
	exe printf("e %s", file_path)
endif

--]]
