-- You can add your own plugins here or in other files in this directory!
--  I promise not to create any merge conflicts in this directory :)
--
-- See the kickstart.nvim README for more information
return {
  {
    "jlanzarotta/bufexplorer",
    init = function()
      -- Optional settings, just examples
      vim.g.bufExplorerDefaultHelp = 0
      vim.g.bufExplorerShowRelativePath = 1
      vim.g.bufExplorerSortBy = "name"
    end,
  },
  
  -- nvim-ufo for better code folding
  {
    'kevinhwang91/nvim-ufo',
    dependencies = {
      'kevinhwang91/promise-async',
    },
    config = function()
      -- Set fold settings
      vim.o.foldcolumn = '1' -- '0' to hide
      vim.o.foldlevel = 99
      vim.o.foldlevelstart = 99
      vim.o.foldenable = true

      -- Setup nvim-ufo
      require('ufo').setup {
        provider_selector = function(bufnr, filetype, buftype)
          return { 'treesitter', 'indent' }
        end,
      }

      -- Optional: keymaps for folding
      vim.keymap.set('n', 'zR', require('ufo').openAllFolds)
      vim.keymap.set('n', 'zM', require('ufo').closeAllFolds)
    end,
  },
}

-- vim: fdm=indent fmr=⌠↓,↑⌡ ts=2 sts=2 sw=2 expandtab
