
-- Usage (no need to specify type)
source_file 'my_config/init_my.lua'
source_file 'my_config/init_legacy.vim'

-- functions before mappings that call them
source_file 'my_config/functions/window_movement.vim'
source_file 'my_config/functions/line_movement.vim'
source_file 'my_config/functions/editing.vim'
source_file 'my_config/functions/terminal.vim'
source_file 'my_config/mappings/window_movement.vim'
source_file 'my_config/mappings/line_movement.vim'
source_file 'my_config/mappings/editing.vim'
source_file 'my_config/mappings/terminal.vim'

source_file 'my_config/telescope_bufferline.lua'
source_file 'my_config/visual_selection.vim'
-- source_file 'my_config/clipboard.lua'
source_file 'my_config/clipboard_V2.lua'

-- :Banner — pyfiglet ASCII-art text banners (default font ansi_shadow)
source_file 'my_config/banner.lua'

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
