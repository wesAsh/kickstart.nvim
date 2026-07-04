-- img-clip.nvim — paste an image straight from the system clipboard into a file:
-- it saves the image to disk AND inserts a markdown link at the cursor.
--
-- WSL note: nvim runs in WSL but the screenshot lives in the *Windows* clipboard.
-- img-clip advertises WSL compatibility and reaches the Windows clipboard via
-- PowerShell under the hood — no xclip/wl-clipboard needed on the Linux side.
-- If a paste ever comes back empty, that PowerShell bridge is the thing to check.
--
-- <leader>p pastes the clipboard image (verified free of other mappings).
return {
  'HakonHarnes/img-clip.nvim',
  event = 'VeryLazy',
  opts = {
    default = {
      dir_path = 'assets', -- images saved under ./assets next to the note...
      relative_to_current_file = true, -- ...resolved relative to the file, not cwd
      use_absolute_path = false,
      file_name = '%Y-%m-%d-%H-%M-%S',
      prompt_for_file_name = false,
    },
    filetypes = {
      markdown = {
        url_encode_path = true,
        template = '![$CURSOR]($FILE_PATH)',
        download_images = false,
      },
    },
  },
  keys = {
    { '<leader>p', '<cmd>PasteImage<cr>', desc = 'Paste image from clipboard' },
  },
}
