local M = { reading_stdin = false }
local directory_file = vim.fn.stdpath('state') .. '/last-directory'

local function restore_directory()
  if vim.fn.argc() ~= 0 then return end
  local ok, lines = pcall(vim.fn.readfile, directory_file, '', 1)
  if ok and lines[1] and vim.fn.isdirectory(lines[1]) == 1 then
    vim.api.nvim_set_current_dir(lines[1])
  end
end

local function save_directory()
  -- Background checks must not overwrite the last interactive directory.
  if not M.opened then return end
  local directory = vim.fn.getcwd()
  if vim.fn.isdirectory(directory) ~= 1 then return end
  vim.fn.mkdir(vim.fn.fnamemodify(directory_file, ':h'), 'p')
  local temporary = directory_file .. '.' .. vim.fn.getpid() .. '.tmp'
  if vim.fn.writefile({ directory }, temporary) == 0 then
    vim.fn.rename(temporary, directory_file)
  end
  local sessions = require('config.sessions')
  if M.session_enabled and sessions.autosave then
    local ok, err = sessions.save()
    if not ok and err ~= 'No named file buffers to save' then vim.notify(err, vim.log.levels.WARN) end
  end
end

local function focus_editor()
  if M.editor and vim.api.nvim_win_is_valid(M.editor)
    and vim.api.nvim_win_get_tabpage(M.editor) == vim.api.nvim_get_current_tabpage() then
    vim.api.nvim_set_current_win(M.editor)
  end
  vim.cmd.stopinsert()
end

local function terminal_windows()
  local wins = {}
  if M.terminal_buf and vim.api.nvim_buf_is_valid(M.terminal_buf) then
    for _, win in ipairs(vim.fn.win_findbuf(M.terminal_buf)) do
      if vim.api.nvim_win_get_tabpage(win) == vim.api.nvim_get_current_tabpage() then
        wins[#wins + 1] = win
      end
    end
  end
  return wins
end

function M.show_terminal(focus)
  local wins = terminal_windows()
  if #wins > 0 then
    if focus then vim.api.nvim_set_current_win(wins[1]); vim.cmd.startinsert() end
    return
  end
  local changing = M.changing_layout
  M.changing_layout = true
  vim.cmd('botright 10new')
  local win = vim.api.nvim_get_current_win()
  for name, value in pairs({ number = false, relativenumber = false, signcolumn = 'no',
    cursorline = false, winfixheight = true }) do vim.wo[win][name] = value end
  if M.terminal_buf and vim.api.nvim_buf_is_valid(M.terminal_buf) then
    local blank = vim.api.nvim_get_current_buf()
    vim.api.nvim_win_set_buf(win, M.terminal_buf)
    vim.api.nvim_buf_delete(blank, { force = true })
  else
    local terminal = vim.api.nvim_get_current_buf()
    M.terminal_buf = terminal
    vim.bo[terminal].bufhidden = 'hide'
    vim.fn.jobstart({ vim.o.shell }, {
      term = true,
      on_exit = function()
        vim.schedule(function()
          if M.terminal_buf == terminal then M.terminal_buf = nil end
          if not vim.api.nvim_buf_is_valid(terminal) then return end
          local focused = vim.api.nvim_get_current_buf() == terminal
          for _, terminal_win in ipairs(vim.fn.win_findbuf(terminal)) do
            local tab = vim.api.nvim_win_get_tabpage(terminal_win)
            if #vim.api.nvim_tabpage_list_wins(tab) > 1 then vim.api.nvim_win_close(terminal_win, true) end
          end
          vim.api.nvim_buf_delete(terminal, { force = true })
          if focused then focus_editor() end
        end)
      end,
    })
  end
  M.changing_layout = changing
  if focus then vim.cmd.startinsert() else focus_editor() end
end

function M.toggle_terminal()
  local wins = terminal_windows()
  if #wins == 0 then M.show_terminal(true); return end
  if #vim.api.nvim_tabpage_list_wins(0) == 1 then
    vim.cmd('aboveleft new')
    M.editor = vim.api.nvim_get_current_win()
  end
  for _, win in ipairs(wins) do vim.api.nvim_win_close(win, true) end
  focus_editor()
end

local function layout()
  M.changing_layout = true
  M.editor = vim.api.nvim_get_current_win()
  require('nvim-tree.api').tree.open({ focus = false })
  vim.api.nvim_set_current_win(M.editor)
  M.show_terminal(false)
  M.changing_layout = false
end

function M.restore_session()
  local ok, err = require('config.sessions').restore()
  if not ok then return false, err end
  layout()
  M.opened, M.session_enabled = true, true
  return true
end

function M.open()
  if M.reading_stdin or vim.o.diff or vim.v.this_session ~= '' or M.opened then return end
  M.opened = true
  restore_directory()
  local path = vim.fn.argc() == 1 and vim.fn.argv(0) or nil
  local directory_argument = path and vim.fn.isdirectory(path) == 1
  M.session_enabled = vim.fn.argc() == 0 or directory_argument
  if directory_argument then
    path = vim.fn.fnamemodify(path, ':p')
    vim.cmd.enew()
    vim.api.nvim_set_current_dir(path)
  end
  if M.session_enabled then
    local ok, err = require('config.sessions').restore()
    if not ok and err ~= 'No session saved for this directory' then vim.notify(err, vim.log.levels.WARN) end
  end
  layout()
end

function M.setup()
  vim.keymap.set({ 'n', 'i', 't' }, '<C-`>', function()
    vim.cmd.stopinsert()
    M.toggle_terminal()
  end, { desc = 'Toggle terminal panel' })
  vim.keymap.set('n', '<leader>ft', M.toggle_terminal, { desc = 'Toggle terminal panel' })
  vim.api.nvim_create_user_command('TerminalToggle', M.toggle_terminal, {})
  local group = vim.api.nvim_create_augroup('CustomStartupLayout', { clear = true })
  vim.api.nvim_create_autocmd('WinEnter', {
    group = group, callback = function()
      if not M.changing_layout and vim.bo.buftype == '' then M.editor = vim.api.nvim_get_current_win() end
    end,
  })
  vim.api.nvim_create_autocmd('StdinReadPre', {
    group = group,
    callback = function() M.reading_stdin = true end,
  })
  vim.api.nvim_create_autocmd('VimEnter', {
    group = group,
    callback = function()
      -- Installation and headless checks do not need an interactive shell.
      if #vim.api.nvim_list_uis() > 0 then vim.schedule(M.open) end
    end,
  })
  vim.api.nvim_create_autocmd('VimLeavePre', {
    group = group,
    callback = save_directory,
  })
end

return M
