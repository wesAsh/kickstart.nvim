-- vim.keymap.set('n', '<A-j>', ':m .+1<CR>==', { desc = 'Move line down' })
-- vim.keymap.set('n', '<A-k>', ':m .-2<CR>==', { desc = 'Move line up' })

vim.keymap.set('n', 'E', ':m .-2<CR>==', { desc = 'Move line up' })
vim.keymap.set('n', 'D', ':m .+1<CR>==', { desc = 'Move line down' })

local function xclip_health_problem()
  -- check if xclip binary is in PATH
  if vim.fn.executable 'xclip' == 0 then return false end

  -- check if xclip actually runs without errors
  local handle = io.popen 'echo test | xclip -selection clipboard'
  if handle then
    local ok, _, code = handle:close()
    return ok and code == 0
  end

  return false
end

local function xclip_health()
  if vim.fn.executable 'xclip' == 0 then
    vim.notify('✗ no exe xclip', vim.log.levels.INFO)
    return false
  end
  vim.notify('✓ has exe xclip', vim.log.levels.INFO)

  -- try a small test copy, check exit code
  local ok, code = os.execute 'echo test | xclip -selection clipboard'
  -- os.execute returns true if exit code is 0, or number on some Lua versions
  if ok == true or ok == 0 then
    vim.notify('✓ xclip os.execute works: ' .. ok, vim.log.levels.INFO)
    return true
  end
  vim.notify('✗ xclip os.execute fail: ' .. ok, vim.log.levels.INFO)

  return false
end

vim.notify('vim.fn.has("unix"): ' .. vim.fn.has 'unix', vim.log.levels.INFO)
if vim.env.SSH_CONNECTION then vim.notify('vim.env.SSH_CONNECTION: ' .. vim.env.SSH_CONNECTION, vim.log.levels.INFO) end
if vim.env.WSL_DISTRO_NAME then vim.notify('vim.env.WSL_DISTRO_NAME: ' .. vim.env.WSL_DISTRO_NAME, vim.log.levels.INFO) end

--[
if xclip_health() then
  vim.notify('using xlip --selection clipboard', vim.log.levels.INFO)
  vim.g.clipboard = {
    name = 'xclip',
    copy = {
      ['+'] = { ['+'] = 'xclip -selection clipboard', ['*'] = 'xclip -selection primary' },
      ['*'] = { ['+'] = 'xclip -selection clipboard', ['*'] = 'xclip -selection primary' },
    },
    paste = {
      ['+'] = 'xclip -selection clipboard -o',
      ['*'] = 'xclip -selection primary -o',
    },
  }
else
  if vim.fn.has 'unix' == 1 and vim.env.SSH_CONNECTION and not vim.env.WSL_DISTRO_NAME then
    vim.notify('using osc52', vim.log.levels.INFO)
    vim.g.clipboard = {
      name = 'osc52',
      copy = {
        ['+'] = require('vim.ui.clipboard.osc52').copy '+',
        ['*'] = require('vim.ui.clipboard.osc52').copy '*',
      },
      paste = {
        ['+'] = function() return {} end,
        ['*'] = function() return {} end,
      },
    }
  end
end
--]]

if vim.fn.has 'nvim-0.11' == 1 then return end
