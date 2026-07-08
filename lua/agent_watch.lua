-- agent-watch.nvim ------------------------------------------------------------
-- Watch terminal buffers that are running an AI CLI (Claude Code, Codex, ...),
-- classify each as WORKING / BLOCKED / IDLE, alert when one needs you (a Y/N
-- prompt) or finishes (working -> idle), and jump to it with one keypress.
--
-- Only terminals matching an "agent signature" (see agent_patterns) are watched,
-- so plain shells are ignored.
--
-- Alert channels (all independent, configurable in setup):
--   notify     = true   toast/message on a new blocked / finished session
--   popup      = false  floating window listing agents needing attention
--   echo       = false  continuously show active agents in the echo line
--   alert_done = true   treat working -> idle ("finished") as attention too
--
-- Zero dependencies. Drop into ~/.config/nvim/lua/agent_watch.lua and call:
--   require("agent_watch").setup()
--------------------------------------------------------------------------------

local M = {}

local defaults = {
  poll_ms = 1000, -- how often to scan terminal buffers
  tail_lines = 40, -- how many trailing lines to pull from the buffer
  active_lines = 8, -- of those, how many trailing NON-blank lines to actually match
  hook_ttl = 30, -- seconds a hook-reported state (M.report) stays authoritative before falling back to TUI scraping
  done_debounce = 2, -- seconds a session must stay idle before it's announced as "finished" (absorbs premature Stop / quick resume)
  notify = true, -- vim.notify (toast/message) on new blocked / finished session
  hud = false, -- persistent top-right float listing every ACTIVE agent (working/blocked/done)
  popup = false, -- attention-only float (blocked/done); superseded by `hud` when hud=true
  echo = false, -- continuously show active agents in the echo line (transient; often clobbered by terminal redraws)
  alert_done = true, -- treat working -> idle ("finished") as an attention event
  icons = { working = '🟡', blocked = '🔴', idle = '🟢', done = '✅', unknown = '⚪' },

  -- A terminal is only watched once its content matches one of these. They are
  -- Claude-Code-oriented signatures that persist in the transcript (so an idle
  -- agent is still recognized) and don't appear in a plain shell. Once matched,
  -- the buffer is remembered as an agent for its lifetime.
  agent_patterns = {
    'esc to interrupt',
    'thinking more',
    'Cogitated for',
    '⎿', -- Claude result/tip gutter
    '✻', '✽', '✶', '✳', -- spinner glyphs (safe as literal full-string patterns)
    '%(%d+s', -- live elapsed timer, e.g. "(43s"
  },

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
    'esc to interrupt', -- Claude Code while streaming/generating
    -- Live elapsed timer "(43s · …". Present only while working; the finished
    -- summary reads "Cogitated for 1m 15s" (no parenthesized timer), so this
    -- cleanly separates WORKING from DONE. (Lua patterns match bytes, so a class
    -- of multibyte spinner glyphs would false-match prompt chars like ❯ — hence
    -- we key on the timer, not the glyph.)
    '%(%d+s',
    'thinking more', -- "(Ns · thinking more)" after a nudge
  },
}

M.opts = vim.deepcopy(defaults)
M.sessions = {} -- bufnr -> { state, name, changed_at, done }
M.agents = {} -- bufnr -> true (terminals confirmed to be agents)
M.reported = {} -- bufnr -> { state, at } (deterministic state pushed by a Claude hook)

local timer = nil
local popup_win, popup_buf = nil, nil
local echo_shown = false -- do we currently occupy the echo line?
local had_attention = false -- was anything blocked/done on the previous scan?

-- Read the tail window of a buffer as { lines, joined-active-tail } -----------
local function buf_tail(buf)
  local total = vim.api.nvim_buf_line_count(buf)
  local from = math.max(0, total - M.opts.tail_lines)
  return vim.api.nvim_buf_get_lines(buf, from, total, false)
end

-- Is this terminal an AI agent? Cached once matched. -------------------------
local function is_agent(buf)
  if M.agents[buf] then return true end
  local tail = table.concat(buf_tail(buf), '\n')
  for _, pat in ipairs(M.opts.agent_patterns) do
    if tail:find(pat) then
      M.agents[buf] = true
      return true
    end
  end
  return false
end

-- Classify a terminal buffer by the text at its active bottom -----------------
-- We drop trailing blank lines (terminal buffers pad the bottom), then match
-- only the last `active_lines` non-blank lines. A live prompt sits at the active
-- bottom; matching the whole scrollback would trip on answered prompts and on
-- quoted/example text (even this tool's own docs).
local function classify(buf)
  local lines = buf_tail(buf)
  while #lines > 0 and lines[#lines]:match '^%s*$' do
    lines[#lines] = nil
  end
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

-- A human-readable label for a terminal buffer. Priority:
--   1. an explicit rename (`:file X`) — the buffer name is no longer a term:// URI
--   2. a program-set title (OSC 0/2 -> b:term_title), e.g. the shell/agent's title
--   3. "cmd:cwd-basename" from the term:// URI, so identical shells stay distinguishable
local function term_title(buf)
  local name = vim.api.nvim_buf_get_name(buf) -- term://cwd//pid:cmd (until renamed)

  if not name:match '^term://' then
    return vim.fn.fnamemodify(name, ':t'):sub(1, 40)
  end

  local tt = vim.b[buf].term_title
  if type(tt) == 'string' and tt ~= '' and not tt:match '^term://' then
    return tt:sub(1, 40)
  end

  local cwd, cmd = name:match 'term://(.-)//%d+:(.*)'
  cmd = vim.fn.fnamemodify(cmd or name, ':t')
  local dir = cwd and vim.fn.fnamemodify(cwd, ':t') or ''
  local label = (dir ~= '' and cmd ~= '') and (cmd .. ':' .. dir) or (cmd ~= '' and cmd or dir)
  return label:sub(1, 40)
end

-- Group current sessions, each list sorted by bufnr (stable order) ------------
local function collect()
  local g = { blocked = {}, working = {}, idle = {}, done = {} }
  for buf, s in pairs(M.sessions) do
    if g[s.state] then
      g[s.state][#g[s.state] + 1] = { buf = buf, name = s.name }
    end
    if s.done then
      g.done[#g.done + 1] = { buf = buf, name = s.name }
    end
  end
  for _, list in pairs(g) do
    table.sort(list, function(a, b) return a.buf < b.buf end)
  end
  return g
end

-- Floating status window ------------------------------------------------------
-- `hud`   : persistent top-right float listing EVERY active agent.
-- `popup` : same window, but only appears when something needs attention.
local function close_float()
  if popup_win and vim.api.nvim_win_is_valid(popup_win) then
    vim.api.nvim_win_close(popup_win, true)
  end
  popup_win = nil
end
M.close_popup = close_float

local function render_float(g)
  local show_done = M.opts.alert_done and g.done or {}
  local attention = #g.blocked > 0 or #show_done > 0

  local show
  if M.opts.hud then
    show = (#g.blocked + #show_done + #g.working) > 0
  elseif M.opts.popup then
    show = attention
  else
    show = false
  end
  if not show then
    close_float()
    return
  end

  -- One line per active agent, highest-priority state first.
  local lines = {}
  local function add(list, icon)
    for _, e in ipairs(list) do
      lines[#lines + 1] = ' ' .. icon .. ' ' .. e.name .. ' '
    end
  end
  add(g.blocked, M.opts.icons.blocked)
  add(show_done, M.opts.icons.done)
  if M.opts.hud then add(g.working, M.opts.icons.working) end
  if attention then lines[#lines + 1] = ' [<leader>ab] jump ' end

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
  end
  -- Border color by priority: red blocked > green done > amber working.
  local border_hl = (#g.blocked > 0 and 'DiagnosticError')
    or (#show_done > 0 and 'DiagnosticOk')
    or 'DiagnosticWarn'
  vim.wo[popup_win].winhighlight = 'Normal:NormalFloat,FloatBorder:' .. border_hl
end

-- Echo-line summary (opt-in): "agents  🔴 claude  🟡 codex  ✅ aider" ----------
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
  if M.opts.alert_done then add(g.done, M.opts.icons.done, 'MoreMsg') end

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
  local newly_blocked, newly_done = {}, {}
  local cur = vim.api.nvim_get_current_buf()

  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].buftype == 'terminal' and is_agent(buf) then
      seen[buf] = true
      -- Reconcile the hook-reported state (M.report) with a fresh TUI scrape.
      -- Hooks give crisp enter-signals but no "un-blocked" event and can emit a
      -- premature Stop, so the screen corrects them:
      --   report 'idle'    but screen busy    -> trust the screen (not finished)
      --   report 'blocked' but screen working -> agent resumed after you answered
      local scr = classify(buf)
      local r = M.reported[buf]
      local rep = (r and (os.time() - r.at) <= M.opts.hook_ttl) and r.state or nil
      local state
      if not rep then
        state = scr
      elseif rep == 'working' then
        state = (scr == 'blocked') and 'blocked' or 'working'
      elseif rep == 'blocked' then
        state = (scr == 'working') and 'working' or 'blocked'
      else -- rep == 'idle' (Stop / idle_prompt)
        state = (scr ~= 'idle') and scr or 'idle'
      end

      local prev = M.sessions[buf]
      local name = term_title(buf) -- recompute each poll so renames/title changes show

      -- "done" = finished working, debounced so a premature Stop or a quick
      -- resume (e.g. right after answering a prompt) doesn't flash a false
      -- "finished". Cleared when it works again or you view its buffer.
      local was_done = prev and prev.done or false
      local done, pending = false, false
      if state == 'idle' then
        if was_done then
          done = true -- already announced; stay done
        elseif prev and prev.state == 'working' then
          pending = true -- just went idle; wait out the debounce
        elseif prev and prev.state == 'idle' and prev.finished_pending then
          if (os.time() - prev.changed_at) >= M.opts.done_debounce then
            done = true
          else
            pending = true
          end
        end
      end
      if buf == cur then
        done, pending = false, false -- viewing it = acknowledged
      end

      if state == 'blocked' and prev and prev.state ~= 'blocked' then
        newly_blocked[#newly_blocked + 1] = name
      end
      if done and not was_done then
        newly_done[#newly_done + 1] = name
      end

      local changed = (not prev) or prev.state ~= state
      M.sessions[buf] = {
        state = state,
        name = name,
        changed_at = changed and os.time() or prev.changed_at,
        done = done,
        finished_pending = pending,
      }
    end
  end

  -- Drop sessions / agent marks for buffers that are gone.
  for buf in pairs(M.sessions) do
    if not seen[buf] then M.sessions[buf] = nil end
  end
  for buf in pairs(M.agents) do
    if not vim.api.nvim_buf_is_valid(buf) then M.agents[buf] = nil end
  end
  for buf in pairs(M.reported) do
    if not seen[buf] then M.reported[buf] = nil end
  end

  local g = collect()
  local done_list = M.opts.alert_done and g.done or {}
  local attention = #g.blocked > 0 or #done_list > 0

  -- Toast on each new blocked / finished session.
  if M.opts.notify then
    for _, name in ipairs(newly_blocked) do
      vim.notify(('%s agent needs you: %s'):format(M.opts.icons.blocked, name), vim.log.levels.WARN, { title = 'agent-watch' })
    end
    if M.opts.alert_done then
      for _, name in ipairs(newly_done) do
        vim.notify(('%s agent finished: %s'):format(M.opts.icons.done, name), vim.log.levels.INFO, { title = 'agent-watch' })
      end
    end
  end

  -- Floating status window: HUD (all active) or attention-only popup.
  render_float(g)

  -- Clear the lingering alert message once nothing needs attention anymore.
  -- (No-op for toast notifiers; fixes the sticky default-notifier cmdline.)
  if had_attention and not attention and not M.opts.echo then
    if vim.fn.mode():sub(1, 1) ~= 'c' then
      vim.api.nvim_echo({ { '' } }, false, {})
    end
  end
  had_attention = attention

  render_echo(g)
  vim.cmd 'redrawstatus'
end

-- Deterministic state push from a Claude hook (hooks/nvim_agent_state.sh).
-- Keyed by the terminal job PID so it lands on the exact terminal buffer, then
-- refreshes immediately. o = { pid = <terminal_job_pid>, state = 'working'|'blocked'|'idle' }
function M.report(o)
  if type(o) ~= 'table' or not o.pid or not o.state then return end
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].buftype == 'terminal' and vim.b[buf].terminal_job_pid == o.pid then
      M.agents[buf] = true -- a hook firing proves this terminal is an agent
      M.reported[buf] = { state = o.state, at = os.time() }
      break
    end
  end
  scan()
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
    local tag = s.done and 'done' or s.state
    items[#items + 1] = ('%s  %s  (%s, %ds)'):format(M.opts.icons[tag] or M.opts.icons[s.state], s.name, tag, os.time() - s.changed_at)
  end
  if #items == 0 then
    vim.notify('agent-watch: no agent sessions', vim.log.levels.INFO)
    return
  end
  vim.ui.select(items, { prompt = 'Agent sessions' }, function(_, idx)
    if not idx then return end
    local buf = bufs[idx]
    if M.sessions[buf] then M.sessions[buf].done = false end
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

-- Jump to the first agent needing attention (blocked first, then finished) -----
function M.jump_blocked()
  local target
  for buf, s in pairs(M.sessions) do
    if s.state == 'blocked' then
      target = buf
      break
    end
  end
  if not target then
    for buf, s in pairs(M.sessions) do
      if s.done then
        target = buf
        break
      end
    end
  end
  if not target then
    vim.notify('agent-watch: nothing needs you 🎉', vim.log.levels.INFO)
    return
  end

  if M.sessions[target] then M.sessions[target].done = false end
  close_float() -- acting on it dismisses the float
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_buf(win) == target then
      vim.api.nvim_set_current_win(win)
      vim.cmd 'startinsert'
      return
    end
  end
  vim.api.nvim_set_current_buf(target)
  vim.cmd 'startinsert'
end

-- Setup --------------------------------------------------------------------------
function M.setup(opts)
  M.opts = vim.tbl_deep_extend('force', vim.deepcopy(defaults), opts or {})

  -- Reset transient state so re-running setup() is clean.
  close_float()
  M.agents = {}
  M.reported = {}
  had_attention = false
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
  vim.keymap.set('n', '<leader>ab', M.jump_blocked, { desc = 'Jump to agent needing attention' })
end

return M
