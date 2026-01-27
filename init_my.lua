-- vim.keymap.set('n', '<A-j>', ':m .+1<CR>==', { desc = 'Move line down' })
-- vim.keymap.set('n', '<A-k>', ':m .-2<CR>==', { desc = 'Move line up' })

vim.keymap.set('n', 'E', ':m .-2<CR>==', { desc = 'Move line up' })
vim.keymap.set('n', 'D', ':m .+1<CR>==', { desc = 'Move line down' })

if vim.fn.has('nvim-0.11') == 1 then
  return
end

