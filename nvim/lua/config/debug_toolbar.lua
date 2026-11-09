local M = { hidden = false }
local dap

local function valid(win) return win and vim.api.nvim_win_is_valid(win) end

function M.close()
  if valid(M.win) then vim.api.nvim_win_close(M.win, true) end
  M.win = nil
end

local function editor_focus()
  if valid(M.editor) then vim.api.nvim_set_current_win(M.editor) end
end

local function click()
  local mouse = vim.fn.getmousepos()
  if mouse.winid ~= M.win then return end
  for _, button in ipairs(M.buttons or {}) do
    if mouse.column >= button.first and mouse.column <= button.last then
      editor_focus()
      require('config.debugging').action(button.action)
      return
    end
  end
  editor_focus()
end

function M.render()
  if not dap.session() or M.hidden then M.close(); return end
  local stopped = dap.session().stopped_thread_id ~= nil
  local items = {
    { stopped and '▶ Continue' or '⏸ Pause', stopped and 'continue' or 'pause' },
    { '↷ Over', 'step_over' }, { '↓ Into', 'step_into' },
    { '↑ Out', 'step_out' }, { '■ Stop', 'stop' },
  }
  local text = ' '
  M.buttons = {}
  for i, item in ipairs(items) do
    -- Narrow terminals keep the same actions, with icons instead of labels.
    local label = vim.o.columns < 65 and item[1]:match('^(%S+)') or item[1]
    M.buttons[#M.buttons + 1] = { first = #text + 1, last = #text + #label, action = item[2] }
    text = text .. label .. (i < #items and '  │  ' or ' ')
  end
  if not M.buf or not vim.api.nvim_buf_is_valid(M.buf) then
    M.buf = vim.api.nvim_create_buf(false, true)
    vim.bo[M.buf].buftype = 'nofile'
    vim.bo[M.buf].bufhidden = 'hide'
    vim.bo[M.buf].filetype = 'debug-toolbar'
    vim.keymap.set('n', '<LeftRelease>', click, { buffer = M.buf, silent = true })
    vim.keymap.set('n', '<Esc>', editor_focus, { buffer = M.buf })
  end
  vim.bo[M.buf].modifiable = true
  vim.api.nvim_buf_set_lines(M.buf, 0, -1, false, { text })
  vim.bo[M.buf].modifiable = false
  local width = math.max(1, math.min(vim.fn.strdisplaywidth(text), vim.o.columns - 4))
  local config = { relative = 'editor', row = vim.o.showtabline > 0 and 1 or 0,
    col = math.max(0, math.floor((vim.o.columns - width - 2) / 2)), width = width, height = 1,
    style = 'minimal', border = 'rounded', focusable = false, mouse = true, zindex = 60 }
  if valid(M.win) and vim.api.nvim_win_get_tabpage(M.win) ~= vim.api.nvim_get_current_tabpage() then M.close() end
  if valid(M.win) then vim.api.nvim_win_set_config(M.win, config)
  else M.win = vim.api.nvim_open_win(M.buf, false, config) end
  vim.wo[M.win].winhighlight = 'Normal:NormalFloat,FloatBorder:DiagnosticInfo'
end

function M.toggle()
  if not dap.session() then vim.notify('Start debugging with F5 first'); return end
  M.hidden = not M.hidden
  M.render()
end

function M.scopes()
  if M.scope_view then M.scope_view.close(); M.scope_view = nil; return end
  local widgets = require('dap.ui.widgets')
  M.scope_view = widgets.builder(widgets.scopes)
    .new_win(function(buf)
      local win = vim.api.nvim_open_win(buf, true, { relative = 'editor',
        width = math.max(1, math.min(70, vim.o.columns - 4)),
        height = math.max(1, math.min(16, vim.o.lines - 6)), row = 4,
        col = math.max(0, math.floor((vim.o.columns - math.min(70, vim.o.columns - 4)) / 2)),
        style = 'minimal', border = 'rounded', title = ' Variables ', title_pos = 'center' })
      for _, key in ipairs({ 'q', '<Esc>' }) do
        vim.keymap.set('n', key, function()
          if M.scope_view then M.scope_view.close(); M.scope_view = nil end
        end, { buffer = buf })
      end
      return win
    end).build()
  M.scope_view.open()
end

function M.cleanup()
  M.close()
  if M.scope_view then M.scope_view.close(); M.scope_view = nil end
  dap.repl.close()
end

function M.setup(client)
  dap = client
  local function redraw() vim.schedule(M.render) end
  dap.listeners.on_session['compact-toolbar'] = function(_, session)
    if not session then M.cleanup()
    else M.hidden = false; redraw() end
  end
  for _, event in ipairs({ 'event_initialized', 'event_continued', 'stackTrace', 'scopes' }) do
    dap.listeners.after[event]['compact-toolbar'] = redraw
  end
  dap.listeners.after.event_stopped['compact-toolbar'] = function(session, event)
    redraw()
    -- nvim-dap leaves explicitly paused threads unfocused. Select a user frame
    -- so Continue, stepping, and inspection work directly after toolbar Pause.
    if event.reason ~= 'pause' or not event.threadId then return end
    session.stopped_thread_id = event.threadId
    session:request('stackTrace', { threadId = event.threadId }, function(err, response)
      if err or not response or dap.session() ~= session then return end
      if session.stopped_thread_id ~= event.threadId then return end
      local frame = response.stackFrames[1]
      for _, candidate in ipairs(response.stackFrames) do
        if candidate.source and candidate.source.path and vim.fn.filereadable(candidate.source.path) == 1 then
          frame = candidate
          break
        end
      end
      if not frame then return end
      session.stopped_thread_id, session.current_frame = event.threadId, frame
      dap.focus_frame()
      redraw()
    end)
  end
  -- Close immediately on exit, even if the adapter's connection lingers.
  for _, event in ipairs({ 'event_exited', 'event_terminated' }) do
    dap.listeners.before[event]['compact-toolbar'] = function() M.cleanup() end
  end
  local group = vim.api.nvim_create_augroup('CompactDebugToolbar', { clear = true })
  vim.api.nvim_create_autocmd({ 'VimResized', 'TabEnter' }, { group = group, callback = redraw })
  vim.api.nvim_create_autocmd('WinEnter', { group = group, callback = function()
    local win = vim.api.nvim_get_current_win()
    if vim.api.nvim_win_get_config(win).relative == '' then M.editor = win end
  end })
  M.editor = vim.api.nvim_get_current_win()
end

return M
