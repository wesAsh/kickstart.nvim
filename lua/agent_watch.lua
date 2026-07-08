-- agent-watch.nvim ------------------------------------------------------------
-- Watch all terminal buffers running AI CLIs (Claude Code, Codex, etc.),
-- classify each as WORKING / BLOCKED / IDLE, notify on "needs your Y/N",
-- and jump to the blocked one with one keypress.
--
-- Zero dependencies. Drop into ~/.config/nvim/lua/agent_watch.lua and call:
--   require("agent_watch").setup()
--------------------------------------------------------------------------------

local M = {}

local defaults = {
  poll_ms = 1000, -- how often to scan terminal buffers
  tail_lines = 40, -- how many trailing lines to pull from the buffer
  active_lines = 8, -- of those, how many trailing NON-blank lines to actually match
  notify = true, -- vim.notify when a session transitions to BLOCKED
  icons = { working = '🟡', blocked = '🔴', idle = '🟢', unknown = '⚪' },
  -- Order matters: first match wins. Checked only against the active bottom of
  -- the buffer (last `active_lines` non-blank lines) so stale prompts and quoted
  -- example text up in the scrollback don't false-trigger. Tune for your agents.
  blocked_patterns = {
    'Do you want', -- Claude Code permission prompts
    '❯ 1%. Yes', -- Claude Code numbered choice menu
    '%f[%w][Yy]/[Nn]%f[%W]', -- generic y/n
    '%(y/n%)',
    '%[y/N%]',
    '%[Y/n%]',
    'Proceed%?',
    'Continue%?',
    'Allow%?',
    'waiting for your input',
    'Press Enter to continue',
    'password:',
    'passphrase', -- ssh/sudo prompts count as blocked too
  },
  working_patterns = {
    'esc to interrupt', -- Claude Code while streaming
    -- NOTE: no spinner-glyph pattern here. Lua patterns match bytes, not
    -- UTF-8 codepoints, so a class of multibyte glyphs false-matches common
    -- prompt chars (e.g. ❯). Rely on the textual cues below instead.
    'Thinking',
    'Running',
    'tokens',
  },
}

M.opts = vim.deepcopy(defaults)
M.sessions = {} -- bufnr -> { state, name, changed_at }
local timer = nil

-- Classify a terminal buffer by the text at its active bottom -----------------
-- We pull a tail window, drop trailing blank lines (terminal buffers pad the
-- bottom), then match only the last `active_lines` non-blank lines. A live
-- prompt sits at the active bottom; matching the whole scrollback would trip on
-- answered prompts and on quoted/example text (even this tool's own docs).
local function classify(buf)
  local total = vim.api.nvim_buf_line_count(buf)
  local from = math.max(0, total - M.opts.tail_lines)
  local lines = vim.api.nvim_buf_get_lines(buf, from, total, false)

  -- Trim trailing blank lines.
  while #lines > 0 and lines[#lines]:match '^%s*$' do
    lines[#lines] = nil
  end
  -- Keep only the last `active_lines` of what remains.
  while #lines > M.opts.active_lines do
    table.remove(lines, 1)
  end
  local tail = table.concat(lines, '\n')

  for _, pat in ipairs(M.opts.blocked_patterns) do
    if tail:find(pat) then return 'blocked' end
  end
  for _, pat in ipairs(M.opts.working_patterns) do
    if tail:find(pat) then return 'working' end
  end
  return 'idle'
end

-- Exposed for tuning/debugging: :lua print(require('agent_watch').classify(0))
M.classify = classify

local function term_title(buf)
  local name = vim.api.nvim_buf_get_name(buf) -- term://cwd//pid:cmd
  local cmd = name:match 'term://.-//%d+:(.*)' or name
  return cmd:sub(1, 40)
end

-- Poll loop --------------------------------------------------------------------
local function scan()
  local seen = {}
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].buftype == 'terminal' then
      seen[buf] = true
      local state = classify(buf)
      local prev = M.sessions[buf]
      if not prev or prev.state ~= state then
        M.sessions[buf] = {
          state = state,
          name = term_title(buf),
          changed_at = os.time(),
        }
        -- Notify only on the transition INTO blocked, not every poll.
        if state == 'blocked' and M.opts.notify and prev then
          vim.notify(('%s agent needs you: %s'):format(M.opts.icons.blocked, term_title(buf)), vim.log.levels.WARN, { title = 'agent-watch' })
        end
      end
    end
  end
  -- Drop sessions whose buffers were wiped.
  for buf in pairs(M.sessions) do
    if not seen[buf] then M.sessions[buf] = nil end
  end
  vim.cmd 'redrawstatus'
end

-- Statusline component: e.g. "🔴1 🟡2 🟢1" --------------------------------------
function M.statusline()
  local counts = { blocked = 0, working = 0, idle = 0 }
  for _, s in pairs(M.sessions) do
    counts[s.state] = (counts[s.state] or 0) + 1
  end
  local parts = {}
  for _, k in ipairs { 'blocked', 'working', 'idle' } do
    if counts[k] > 0 then parts[#parts + 1] = M.opts.icons[k] .. counts[k] end
  end
  return table.concat(parts, ' ')
end

-- Picker: list sessions, jump to the chosen one ---------------------------------
function M.pick()
  local items, bufs = {}, {}
  for buf, s in pairs(M.sessions) do
    bufs[#bufs + 1] = buf
    items[#items + 1] = ('%s  %s  (%s, %ds)'):format(M.opts.icons[s.state], s.name, s.state, os.time() - s.changed_at)
  end
  if #items == 0 then
    vim.notify('agent-watch: no terminal sessions', vim.log.levels.INFO)
    return
  end
  vim.ui.select(items, { prompt = 'Agent sessions' }, function(_, idx)
    if not idx then return end
    local buf = bufs[idx]
    -- Reuse a window already showing it, else open in current window.
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      if vim.api.nvim_win_get_buf(win) == buf then
        vim.api.nvim_set_current_win(win)
        return
      end
    end
    vim.api.nvim_set_current_buf(buf)
    vim.cmd 'startinsert' -- straight into the prompt, answer that Y/N
  end)
end

-- Jump to the first blocked session directly ------------------------------------
function M.jump_blocked()
  for buf, s in pairs(M.sessions) do
    if s.state == 'blocked' then
      for _, win in ipairs(vim.api.nvim_list_wins()) do
        if vim.api.nvim_win_get_buf(win) == buf then
          vim.api.nvim_set_current_win(win)
          vim.cmd 'startinsert'
          return
        end
      end
      vim.api.nvim_set_current_buf(buf)
      vim.cmd 'startinsert'
      return
    end
  end
  vim.notify('agent-watch: nothing blocked 🎉', vim.log.levels.INFO)
end

-- Setup --------------------------------------------------------------------------
function M.setup(opts)
  M.opts = vim.tbl_deep_extend('force', vim.deepcopy(defaults), opts or {})

  if timer then
    timer:stop()
    timer:close()
  end
  timer = vim.uv.new_timer()
  timer:start(M.opts.poll_ms, M.opts.poll_ms, vim.schedule_wrap(scan))

  vim.api.nvim_create_user_command('AgentWatch', M.pick, {})
  vim.api.nvim_create_user_command('AgentBlocked', M.jump_blocked, {})

  vim.keymap.set('n', '<leader>aa', M.pick, { desc = 'Agent sessions picker' })
  vim.keymap.set('n', '<leader>ab', M.jump_blocked, { desc = 'Jump to blocked agent' })
end

return M
