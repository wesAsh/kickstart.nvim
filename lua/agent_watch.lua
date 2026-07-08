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
  notify = true, -- master switch for vim.notify toasts (set false for "float only, no noise")
  notify_blocked = true, -- toast when an agent needs you (gated by `notify`)
  notify_done = true, -- toast when an agent finishes (gated by `notify`)
  hud = false, -- floating display: working agents at `hud_pos`, attention at `attention_pos`
  popup = false, -- show only the attention float (blocked/done); `hud` also adds the working corner
  hud_pos = 'NE', -- corner for the passive working list: 'NE' | 'NW' | 'SE' | 'SW'
  attention_pos = 'center', -- where blocked/finished pop: 'center' | 'NE' | 'NW' | 'SE' | 'SW'
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
local hud_win, hud_buf = nil, nil -- passive working list (corner)
local att_win, att_buf = nil, nil -- blocked/finished (center by default)
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

-- Floating status windows -----------------------------------------------------
-- Two independent floats, both driven by `hud`/`popup`:
--   working list -> `hud_pos` corner (passive)
--   blocked/finished -> `attention_pos` (center by default, to grab attention)
-- If the two positions are equal they merge into one float to avoid overlap.
local function place(pos, width, height)
  local cols, lines = vim.o.columns, vim.o.lines
  local bottom = math.max(1, lines - vim.o.cmdheight - 1)
  local cfg = { relative = 'editor', width = width, height = height, style = 'minimal', border = 'rounded', focusable = false, zindex = 200 }
  if pos == 'center' then
    cfg.anchor, cfg.row, cfg.col = 'NW', math.max(0, math.floor((lines - height) / 2) - 1), math.max(0, math.floor((cols - width) / 2))
  elseif pos == 'NW' then
    cfg.anchor, cfg.row, cfg.col = 'NW', 1, 0
  elseif pos == 'SE' then
    cfg.anchor, cfg.row, cfg.col = 'SE', bottom, cols - 1
  elseif pos == 'SW' then
    cfg.anchor, cfg.row, cfg.col = 'SW', bottom, 0
  else -- 'NE' (default)
    cfg.anchor, cfg.row, cfg.col = 'NE', 1, cols - 1
  end
  return cfg
end

-- Draw (or close) one float; returns the (win, buf) to store back.
local function draw(win, buf, lines, pos, border_hl)
  if #lines == 0 then
    if win and vim.api.nvim_win_is_valid(win) then vim.api.nvim_win_close(win, true) end
    return nil, buf
  end
  local width = 0
  for _, l in ipairs(lines) do
    width = math.max(width, vim.fn.strdisplaywidth(l))
  end
  if not (buf and vim.api.nvim_buf_is_valid(buf)) then
    buf = vim.api.nvim_create_buf(false, true)
  end
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  local cfg = place(pos, width, #lines)
  if win and vim.api.nvim_win_is_valid(win) then
    vim.api.nvim_win_set_config(win, cfg)
  else
    cfg.noautocmd = true
    win = vim.api.nvim_open_win(buf, false, cfg)
  end
  vim.wo[win].winhighlight = 'Normal:NormalFloat,FloatBorder:' .. border_hl
  return win, buf
end

local function close_float()
  hud_win, hud_buf = draw(hud_win, hud_buf, {}, 'NE', '')
  att_win, att_buf = draw(att_win, att_buf, {}, 'NE', '')
end
M.close_popup = close_float

local function line_for(icon, name)
  return ' ' .. icon .. ' ' .. name .. ' '
end

local function render_float(g)
  local show_done = M.opts.alert_done and g.done or {}
  local show_working = M.opts.hud
  local show_attention = M.opts.hud or M.opts.popup

  local working_lines = {}
  for _, e in ipairs(g.working) do
    working_lines[#working_lines + 1] = line_for(M.opts.icons.working, e.name)
  end
  local att_lines = {}
  for _, e in ipairs(g.blocked) do
    att_lines[#att_lines + 1] = line_for(M.opts.icons.blocked, e.name)
  end
  for _, e in ipairs(show_done) do
    att_lines[#att_lines + 1] = line_for(M.opts.icons.done, e.name)
  end
  if #att_lines > 0 then att_lines[#att_lines + 1] = ' [<leader>ab] jump ' end
  local att_hl = (#g.blocked > 0 and 'DiagnosticError') or 'DiagnosticOk'

  -- Merge into one corner float when both target the same position.
  if show_working and show_attention and M.opts.hud_pos == M.opts.attention_pos then
    local merged = {}
    for _, l in ipairs(att_lines) do merged[#merged + 1] = l end
    for _, l in ipairs(working_lines) do merged[#merged + 1] = l end
    local hl = (#g.blocked > 0 and 'DiagnosticError') or (#show_done > 0 and 'DiagnosticOk') or 'DiagnosticWarn'
    hud_win, hud_buf = draw(hud_win, hud_buf, merged, M.opts.hud_pos, hl)
    att_win, att_buf = draw(att_win, att_buf, {}, 'NE', '') -- close the other
    return
  end

  hud_win, hud_buf = draw(hud_win, hud_buf, show_working and working_lines or {}, M.opts.hud_pos, 'DiagnosticWarn')
  att_win, att_buf = draw(att_win, att_buf, show_attention and att_lines or {}, M.opts.attention_pos, att_hl)
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

      -- "done" = finished working. Start the finish countdown only on a real
      -- idle SIGNAL: a hook Stop/idle_prompt (rep == 'idle'), or a scraped
      -- working->idle for agents with no hooks. A transient scrape-idle gap
      -- during hook-driven work (e.g. the spinner blink at the tool->response
      -- boundary) is NOT "finished". The countdown is then debounced, so a
      -- premature Stop or a quick resume never flashes a false "finished".
      local was_done = prev and prev.done or false
      local pending_since = prev and prev.pending_since or nil
      local is_hooked = M.reported[buf] ~= nil
      local done = false
      if state ~= 'idle' then
        pending_since = nil -- working/blocked cancels any pending finish
      elseif was_done then
        done = true -- already announced; stay done
      else
        local eligible = (rep == 'idle') or (not is_hooked and prev and prev.state == 'working')
        if pending_since then
          if (os.time() - pending_since) >= M.opts.done_debounce then done = true end
        elseif eligible then
          pending_since = os.time() -- begin the debounce countdown
        end
      end
      if buf == cur then
        done, pending_since = false, nil -- viewing it = acknowledged
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
        pending_since = pending_since,
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
    if M.opts.notify_blocked then
      for _, name in ipairs(newly_blocked) do
        vim.notify(('%s agent needs you: %s'):format(M.opts.icons.blocked, name), vim.log.levels.WARN, { title = 'agent-watch' })
      end
    end
    if M.opts.alert_done and M.opts.notify_done then
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
