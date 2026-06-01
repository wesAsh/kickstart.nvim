vim.keymap.set('n', '<C-j>', '<cmd>BufferLineCycleNext<cr>')
vim.keymap.set('n', '<C-k>', '<cmd>BufferLineCyclePrev<cr>')
vim.keymap.set('i', '<C-j>', '<C-o><cmd>BufferLineCycleNext<cr>')
vim.keymap.set('i', '<C-k>', '<C-o><cmd>BufferLineCyclePrev<cr>')
vim.keymap.set('t', '<C-j>', [[<C-\><C-n><cmd>BufferLineCycleNext<cr>]])
vim.keymap.set('t', '<C-k>', [[<C-\><C-n><cmd>BufferLineCyclePrev<cr>]])

vim.keymap.set('n', '<C-l>', '<cmd>BufferLineCycleNext<cr>')
vim.keymap.set('n', '<C-h>', '<cmd>BufferLineCyclePrev<cr>')
vim.keymap.set('i', '<C-l>', '<C-o><cmd>BufferLineCycleNext<cr>')
vim.keymap.set('i', '<C-h>', '<C-o><cmd>BufferLineCyclePrev<cr>')
vim.keymap.set('t', '<C-l>', [[<C-\><C-n><cmd>BufferLineCycleNext<cr>]])
vim.keymap.set('t', '<C-h>', [[<C-\><C-n><cmd>BufferLineCyclePrev<cr>]])

vim.keymap.set('x', 'x', '"_x', { desc = 'Delete without yanking' })
vim.keymap.set('x', '<BS>', '"_d', { desc = 'Delete selection without yanking' })

vim.keymap.set('n', '<leader>u', function() require('telescope.builtin').buffers { initial_mode = 'normal' } end, { desc = '[ ] Find existing buffers' })

vim.keymap.set(
  { 'n', 'i', 't' },
  '<A-s>',
  function()
    require('telescope.builtin').buffers {
      initial_mode = 'normal',
      select_current = true,
      sorting_strategy = 'ascending',
      layout_config = {
        prompt_position = 'top',
      },
    }
  end,
  { desc = 'Find existing buffers' }
)

if false then
  local function next_buffer()
    vim.cmd 'BufferLineCycleNext'
    vim.notify(vim.fn.bufname '%', vim.log.levels.INFO, {
      title = 'Buffer',
      timeout = 500,
    })
  end

  local function prev_buffer()
    vim.cmd 'BufferLineCyclePrev'
    vim.notify(vim.fn.bufname '%', vim.log.levels.INFO, {
      title = 'Buffer',
      timeout = 500,
    })
  end

  vim.keymap.set({ 'n', 'i', 't' }, '<C-l>', next_buffer)
  -- vim.keymap.set({ 'n', 'i', 't' }, '<C-k>', prev_buffer)
end

