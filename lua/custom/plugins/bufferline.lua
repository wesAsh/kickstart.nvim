-- vim: fdm=indent fmr=⌠↓,↑⌡ ts=2 sts=2 sw=2 expandtab
return {
  'akinsho/bufferline.nvim',
  version = '*',
  dependencies = 'nvim-tree/nvim-web-devicons',
  config = function()
    require('bufferline').setup({
      options = {
        mode = 'buffers', -- or 'tabs'
        numbers = 'ordinal', -- shows 1,2,3...
        close_command = 'bdelete! %d',
        diagnostics = 'nvim_lsp', -- shows LSP errors
        separator_style = 'slant', -- or 'thick', 'thin'
        show_buffer_close_icons = false,
        show_close_icon = false,
        
        -- Group buffers by directory/project
        groups = {
          items = {
            require('bufferline.groups').builtin.pinned:with({ icon = '' }),
          },
        },
        
        -- Offsets for file explorers
        offsets = {
          {
            filetype = 'oil',
            text = 'File Explorer',
            highlight = 'Directory',
            separator = true,
          },
        },
      },
    })

    -- Navigate buffers
    vim.keymap.set('n', '<S-l>', '<cmd>BufferLineCycleNext<cr>', { desc = 'Next buffer' })
    vim.keymap.set('n', '<S-h>', '<cmd>BufferLineCyclePrev<cr>', { desc = 'Previous buffer' })
    
    -- Move buffers
    vim.keymap.set('n', '<leader>bn', '<cmd>BufferLineMoveNext<cr>', { desc = 'Move buffer right' })
    vim.keymap.set('n', '<leader>bp', '<cmd>BufferLineMovePrev<cr>', { desc = 'Move buffer left' })
    
    -- Jump to buffer by number
    vim.keymap.set('n', '<leader>1', '<cmd>BufferLineGoToBuffer 1<cr>', { desc = 'Go to buffer 1' })
    vim.keymap.set('n', '<leader>2', '<cmd>BufferLineGoToBuffer 2<cr>', { desc = 'Go to buffer 2' })
    vim.keymap.set('n', '<leader>3', '<cmd>BufferLineGoToBuffer 3<cr>', { desc = 'Go to buffer 3' })
    -- etc...
    
    -- Pin/unpin buffer
    vim.keymap.set('n', '<leader>bP', '<cmd>BufferLineTogglePin<cr>', { desc = 'Pin buffer' })
    
    -- Pick buffer interactively
    vim.keymap.set('n', '<leader>bb', '<cmd>BufferLinePick<cr>', { desc = 'Pick buffer' })
    
    -- Close other buffers
    vim.keymap.set('n', '<leader>bo', '<cmd>BufferLineCloseOthers<cr>', { desc = 'Close other buffers' })
  end,
}
