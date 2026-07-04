-- :Banner — insert an ASCII-art text banner (pyfiglet) at the cursor.
-- Handy for section headers in markdown notes; output is plain text so it works
-- anywhere. Companion browser: my_config/scripts/figlet-nice.sh (the good fonts).
--
--   :Banner Hello World          → ansi_shadow banner, inserted below the line
--   :Banner -f pagga Section      → pick a font (Tab-completes the nice fonts)
--
-- Needs pyfiglet (pip install --user pyfiglet). Machine-local dep.

local default_font = 'ansi_shadow'

-- The block/box-drawing fonts (from figlet-nice.sh --list) — offered as -f completions.
local nice_fonts = {
  'ansi_regular', 'ansi_shadow', 'bigmono12', 'bigmono9', 'blocky', 'bloody',
  'calvin_s', 'delta_corps_priest_1', 'dos_rebel', 'double_blocky', 'electronic',
  'elite', 'emboss', 'emboss2', 'future', 'mono12', 'mono9', 'pagga', 'smblock',
  'smbraille', 'smmono12', 'smmono9', 'the_edge', 'this',
}

-- pyfiglet may be a pip --user install; fall back to its ~/.local/bin path since
-- Neovim's inherited PATH doesn't always include it.
local function pyfiglet_bin()
  if vim.fn.executable('pyfiglet') == 1 then return 'pyfiglet' end
  local local_bin = vim.fn.expand('~/.local/bin/pyfiglet')
  if vim.fn.executable(local_bin) == 1 then return local_bin end
  return nil
end

local function banner(opts)
  local args = opts.fargs
  local font = default_font
  if args[1] == '-f' then
    if not args[2] then
      vim.notify('Banner: -f needs a font name', vim.log.levels.ERROR)
      return
    end
    font = args[2]
    args = vim.list_slice(args, 3)
  end

  local text = table.concat(args, ' ')
  if text == '' then
    vim.notify('Banner: no text given', vim.log.levels.WARN)
    return
  end

  local bin = pyfiglet_bin()
  if not bin then
    vim.notify('Banner: pyfiglet not found (pip install --user pyfiglet)', vim.log.levels.ERROR)
    return
  end

  local out = vim.fn.systemlist({ bin, '-f', font, text })
  if vim.v.shell_error ~= 0 then
    vim.notify('Banner: pyfiglet failed (bad font "' .. font .. '"?)\n' .. table.concat(out, '\n'), vim.log.levels.ERROR)
    return
  end

  -- Trim trailing blank lines pyfiglet appends.
  while #out > 0 and out[#out]:match('^%s*$') do
    table.remove(out)
  end
  if #out == 0 then
    vim.notify('Banner: empty output', vim.log.levels.WARN)
    return
  end

  -- Insert linewise, below the current line.
  vim.api.nvim_put(out, 'l', true, true)
end

vim.api.nvim_create_user_command('Banner', banner, {
  nargs = '+',
  complete = function(arglead)
    return vim.tbl_filter(function(f)
      return f:find(arglead, 1, true) == 1
    end, nice_fonts)
  end,
  desc = 'Insert an ASCII-art banner at the cursor (pyfiglet, default ansi_shadow; -f <font>)',
})
