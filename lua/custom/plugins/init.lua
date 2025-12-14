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
}


