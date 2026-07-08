-- agent-watch.nvim ------------------------------------------------------------
-- Watch all terminal buffers running AI CLIs (Claude Code, Codex, etc.),
-- classify each as WORKING / BLOCKED / IDLE, alert on "needs your Y/N",
-- and jump to the blocked one with one keypress.
--
-- Alert channels (all independent, configurable in setup):
--   notify = true   toast/message when a session enters BLOCKED
--   popup  = false  floating window listing blocked agents while any are blocked
--   echo   = false  continuously show active (blocked+working) agents in the echo line
--
-- Zero dependencies. Drop into ~/.config/nvim/lua/agent_watch.lua and call:
--   require("agent_watch").setup()
--------------------------------------------------------------------------------

local M = {}

local defaults = {
  poll_ms = 1000, -- how often to scan terminal buffers
  tail_lines = 40, -- how many trailing lines to pull from the buffer
  active_lines = 8, -- of those, how many trailing NON-blank lines to actually match
  notify = true, -- vim.notify (toast/message) when a session enters BLOCKED
  popup = false, -- also pop a floating window listing blocked agents
  echo = false, -- continuously show active (blocked+working) agents in the echo line
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
local popup_win, popup_buf = nil, nil
local echo_shown = false -- do we currently occupy the echo line?
local had_blocked = false -- was anything blocked on the previous scan?

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

-- Group current sessions by state, each list sorted by bufnr (stable order) ---
local function collect()
  local g = { blocked = {}, working = {}, idle = {} }
  for buf, s in pairs(M.sessions) do
    if g[s.state] then
      g[s.state][#g[s.state] + 1] = { buf = buf, name = s.name }
    end
  end
  for _, list in pairs(g) do
    table.sort(list, function(a, b) return a.buf < b.buf end)
  end
  return g
end

-- Floating popup (opt-in) ------------------------------------------------------
local function close_popup()
  if popup_win and vim.api.nvim_win_is_valid(popup_win) then
    vim.api.nvim_win_close(popup_win, true)
  end
  popup_win = nil
end
M.close_popup = close_popup

local function open_popup(blocked)
  local lines = { ' ' .. M.opts.icons.blocked .. ' agent needs you ' }
  for _, e in ipairs(blocked) do
    lines[#lines + 1] = '   • ' .. e.name
  end
  lines[#lines + 1] = ' [<leader>ab] jump '

  local width = 0
  for _, l in ipairs(lines) do
    width = math.max(width, vim.fn.strdisplaywidth(l))
  end

  if not (popup_buf and vim.api.nvim_buf_is_valid(popup_buf)) then
    popup_buf = vim.api.nvim_create_buf(false, true)
  end
  vim.bo[popup_buf].modifiable = true
  vim.api.nvim_buf_set_lines(popup_buf, 0, -1, false, lines)
  vim.bo[popup_buf].modifiable = false

  local cfg = {
    relative = 'editor',
    anchor = 'NE',
    row = 1,
    col = math.max(0, vim.o.columns - 1),
    width = width,
    height = #lines,
    style = 'minimal',
    border = 'rounded',
    focusable = false,
    zindex = 200,
  }
  if popup_win and vim.api.nvim_win_is_valid(popup_win) then
    vim.api.nvim_win_set_config(popup_win, cfg)
  else
    cfg.noautocmd = true
    popup_win = vim.api.nvim_open_win(popup_buf, false, cfg)
    vim.wo[popup_win].winhighlight = 'Normal:NormalFloat,FloatBorder:DiagnosticError'
  end
end

-- Echo-line summary (opt-in): "agents  🔴 claude  🟡 codex" --------------------
local function render_echo(g)
  if not M.opts.echo then return end
  -- Never clobber the command line while the user is typing a command.
  if vim.fn.mode():sub(1, 1) == 'c' then return end

  local chunks = {}
  local function add(list, icon, hl)
    for _, e in ipairs(list) do
      chunks[#chunks + 1] = { (#chunks > 0 and '  ' or '') .. icon .. ' ' .. e.name, hl }
    end
  end
  add(g.blocked, M.opts.icons.blocked, 'ErrorMsg')
  add(g.working, M.opts.icons.working, 'MoreMsg')

  if #chunks == 0 then
    if echo_shown then
      vim.api.nvim_echo({ { '' } }, false, {})
      echo_shown = false
    end
    return
  end
  table.insert(chunks, 1, { 'agents ', 'Comment' })
  vim.api.nvim_echo(chunks, false, {}) -- false = don't add to :messages history
  echo_shown = true
end

-- Poll loop --------------------------------------------------------------------
local function scan()
  local seen = {}
  local newly_blocked = {}
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].buftype == 'terminal' then
      seen[buf] = true
      local state = classify(buf)
      local prev = M.sessions[buf]
      if not prev or prev.state ~= state then
        M.sessions[buf] = { state = state, name = term_title(buf), changed_at = os.time() }
        -- Collect NEW blocks (transitions), so we notify once, not every poll.
        if state == 'blocked' and prev then
          newly_blocked[#newly_blocked + 1] = M.sessions[buf].name
        end
      end
    end
  end
  -- Drop sessions whose buffers were wiped.
  for buf in pairs(M.sessions) do
    if not seen[buf] then M.sessions[buf] = nil end
  end

  local g = collect()
  local any_blocked = #g.blocked > 0

  -- (1) Toast on each new block.
  if M.opts.notify then
    for _, name in ipairs(newly_blocked) do
      vim.notify(('%s agent needs you: %s'):format(M.opts.icons.blocked, name), vim.log.levels.WARN, { title = 'agent-watch' })
    end
  end

  -- (2) Popup: show while anything is blocked, close when clear.
  if M.opts.popup then
    if any_blocked then
      open_popup(g.blocked)
    else
      close_popup()
    end
  end

  -- Clear the lingering "needs you" message once nothing is blocked anymore.
  -- (No-op for toast notifiers; fixes the sticky default-notifier cmdline.)
  if had_blocked and not any_blocked and not M.opts.echo then
    if vim.fn.mode():sub(1, 1) ~= 'c' then
      vim.api.nvim_echo({ { '' } }, false, {})
    end
  end
  had_blocked = any_blocked

  -- (3) Continuous echo-line summary of active sessions.
  render_echo(g)

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
      close_popup() -- acting on it dismisses the popup
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

  -- Reset transient UI state so re-running setup() is clean.
  close_popup()
  had_blocked = false
  echo_shown = false

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
