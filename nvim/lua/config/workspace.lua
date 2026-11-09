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
end

function M.open()
  if M.reading_stdin or vim.o.diff or vim.v.this_session ~= '' or M.opened then
    return
  end
  M.opened = true
  restore_directory()
  local path = vim.fn.argc() == 1 and vim.fn.argv(0) or nil
  if path and vim.fn.isdirectory(path) == 1 then
    path = vim.fn.fnamemodify(path, ':p')
    vim.cmd.enew()
    vim.api.nvim_set_current_dir(path)
  end
  local editor = vim.api.nvim_get_current_win()
  require('nvim-tree.api').tree.open({ focus = false })
  vim.api.nvim_set_current_win(editor)
  vim.cmd('botright 10new')
  local terminal = vim.api.nvim_get_current_buf()
  local win = vim.api.nvim_get_current_win()
  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].signcolumn = 'no'
  vim.wo[win].cursorline = false
  vim.wo[win].winfixheight = true
  M.terminal_buf = terminal
  vim.fn.jobstart({ vim.o.shell }, {
    term = true,
    on_exit = function()
      vim.schedule(function()
        if vim.api.nvim_buf_is_valid(terminal) then
          for _, terminal_win in ipairs(vim.fn.win_findbuf(terminal)) do
            if #vim.api.nvim_tabpage_list_wins(0) > 1 then
              vim.api.nvim_win_close(terminal_win, true)
            end
          end
          if vim.api.nvim_buf_is_valid(terminal) then
            vim.api.nvim_buf_delete(terminal, { force = true })
          end
        end
      end)
    end,
  })
  vim.api.nvim_set_current_win(editor)
  vim.cmd.stopinsert()
end

function M.setup()
  local group = vim.api.nvim_create_augroup('CustomStartupLayout', { clear = true })
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
