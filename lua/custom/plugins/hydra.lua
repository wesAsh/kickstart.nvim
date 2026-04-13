--[[
Lazy reload hydra.nvim

option hint.border has been deprecated.
anohter thing, I want to back to hjkl and default options
are there other cool options for this plugin? can I quit with any key that is not defined in the heads?
lets add the whole options:

CTRL-E, CTRL-Y, zt, zz, zb, 
CTRL-U, CTRL-D, H, M, L

--]]

-- the previous example worked but this one seems not
return {
  'nvimtools/hydra.nvim',
  event = 'VeryLazy',
  config = function()
    -- Remove all hydra-generated keymaps before re-creating
      for _, map in ipairs(vim.api.nvim_get_keymap('n')) do
        if map.desc and map.desc:match('Hydra') then
          print('Removing hydra keymap:', map.lhs)
          pcall(vim.keymap.del, 'n', map.lhs)
        end
      end
  
    local Hydra = require('hydra')

    Hydra({
      name = 'View Scroll',
      mode = 'n',
      -- body = 'z',
      body = '<C-z>',
      hint = [[
 ╔════════════════════════════╗
 ║        View Movement       ║
 ╠════════════════════════════╣
 ║ _j_/_k_           line ↑/↓   ║
 ║ _u_ / _d_         half ↑/↓   ║
 ║ _H_ / _M_ / _L_ cur T/M/B  ║
 ║ _t_ / _z_ / _b_ view T/M/B ║
 ║                            ║
 ║     any other key: quit    ║
 ╚════════════════════════════╝
]],
      config = {
        color = 'red',
        invoke_on_body = true,
        hint = {
          type = 'window',
          position = 'top-right', show_name = true,
        },
      },
      heads = {
        -- Scroll up/down (single line)
        { 'j', '<C-y>', { desc = 'scroll up' } },
        { 'k', '<C-e>', { desc = 'scroll down' } },

        -- Half page up/down
        { 'u', '<C-u>', { desc = 'half page up' } },
        { 'd', '<C-d>', { desc = 'half page down' } },
      
        -- Move cursor to top/middle/bottom of screen
        { 'H', 'H', { desc = 'cursor to top' } },
        { 'M', 'M', { desc = 'cursor to middle' } },
        { 'L', 'L', { desc = 'cursor to bottom' } },

        -- Reposition view around cursor
        { 't', 'zt', { desc = 'view to top' } },
        { 'z', 'zz', { desc = 'view to middle' } },
        { 'b', 'zb', { desc = 'view to bottom' } },
      },
    })
  end,
}



--[[
return {
    Hydra({
      name = 'View Scroll',
      mode = 'n',
      body = 'z',
      config = {
        color = 'pink',
        invoke_on_body = true,
        hint = {
          type = 'window',
          position = 'top-right',
          border = 'rounded',
          show_name = true,
        },
      },
      heads = {
        -- Scroll up/down (single line)
        { 'i', '<C-y>', { desc = 'scroll up' } },
        { 'k', '<C-e>', { desc = 'scroll down' } },

        -- Half page up/down
        { 'I', '<C-u>', { desc = 'half page up' } },
        { 'K', '<C-d>', { desc = 'half page down' } },

        -- Cursor to top/middle/bottom of screen
        { 't', 'zt', { desc = 'cursor to top' } },
        { 'm', 'zz', { desc = 'cursor to middle' } },
        { 'b', 'zb', { desc = 'cursor to bottom' } },

        -- Horizontal scroll
        { 'j', '4zh', { desc = 'scroll left' } },
        { 'l', '4zl', { desc = 'scroll right' } },

        { 'q', nil, { exit = true, desc = 'quit' } },
      },
    })
  end,
}
--]]

--[[
 ╔═══════════════════════════╗
 ║      View Movement        ║
 ╠═══════════════════════════╣
 ║ _i_ / _k_  scroll ↑/↓    ║
 ║ _I_ / _K_  half page ↑/↓ ║
 ║ _t_ / _b_  top / bottom   ║
 ║ _m_        middle          ║
 ║ _j_ / _l_  scroll ←/→    ║
 ║                           ║
 ║ _q_  quit                 ║
 ╚═══════════════════════════╝
--]]

