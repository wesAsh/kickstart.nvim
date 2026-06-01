--[[
for WSL2 we can use win32yank.exe:

curl -sLo /tmp/win32yank.zip https://github.com/equalsraf/win32yank/releases/latest/download/win32yank-x64.zip
unzip /tmp/win32yank.zip -d /tmp/win32yank
sudo mv /tmp/win32yank/win32yank.exe /usr/local/bin/
sudo chmod +x /usr/local/bin/win32yank.exe

--]]



local function xclip_health()
  if vim.fn.executable 'xclip' == 0 then
    vim.notify('✗ no exe xclip', vim.log.levels.INFO)
    return false
  end
  vim.notify('✓ has exe xclip', vim.log.levels.INFO)

  local ok, _, code = os.execute 'echo test | xclip -selection clipboard 2>/dev/null'
  if ok == true or code == 0 then
    vim.notify('✓ xclip works', vim.log.levels.INFO)
    return true
  end
  vim.notify('✗ xclip failed (no display?)', vim.log.levels.INFO)
  return false
end

local is_unix     = vim.fn.has 'unix' == 1
local is_wsl      = vim.env.WSL_DISTRO_NAME ~= nil
local is_ssh      = vim.env.SSH_CONNECTION ~= nil

vim.notify('unix=' .. tostring(is_unix) .. ' wsl=' .. tostring(is_wsl) .. ' ssh=' .. tostring(is_ssh), vim.log.levels.INFO)

if xclip_health() then
  -- X server available (e.g. VcXsrv running in WSL2, or native Linux with display)
  vim.notify('using xclip', vim.log.levels.INFO)
  vim.g.clipboard = {
    name = 'xclip',
    copy = {
      ['+'] = 'xclip -selection clipboard',
      ['*'] = 'xclip -selection primary',
    },
    paste = {
      ['+'] = 'xclip -selection clipboard -o',
      ['*'] = 'xclip -selection primary -o',
    },
  }
elseif is_wsl then
  -- WSL2 without X server: use Windows clip.exe / PowerShell
  vim.notify('using win32yank / clip.exe', vim.log.levels.INFO)
  if vim.fn.executable 'win32yank.exe' == 1 then
    vim.g.clipboard = {
      name = 'win32yank',
      copy  = { ['+'] = 'win32yank.exe -i --crlf', ['*'] = 'win32yank.exe -i --crlf' },
      paste = { ['+'] = 'win32yank.exe -o --lf',   ['*'] = 'win32yank.exe -o --lf'   },
    }
  else
    vim.g.clipboard = {
      name = 'clip.exe',
      copy  = { ['+'] = 'clip.exe', ['*'] = 'clip.exe' },
      paste = {
        ['+'] = { 'powershell.exe', '-NoProfile', '-c', '[Console]::OutputEncoding=[Text.Encoding]::UTF8;[Console]::Out.Write($(Get-Clipboard -Raw))' },
        ['*'] = { 'powershell.exe', '-NoProfile', '-c', '[Console]::OutputEncoding=[Text.Encoding]::UTF8;[Console]::Out.Write($(Get-Clipboard -Raw))' },
      },
    }
  end
elseif is_ssh and is_unix then
  -- Remote SSH without WSL: OSC52
  vim.notify('using osc52', vim.log.levels.INFO)
  vim.g.clipboard = {
    name  = 'osc52',
    copy  = { ['+'] = require('vim.ui.clipboard.osc52').copy '+', ['*'] = require('vim.ui.clipboard.osc52').copy '*' },
    paste = { ['+'] = function() return {} end, ['*'] = function() return {} end },
  }
end


-- vim: fdm=indent ts=2 sts=2 sw=2 et
