local M = { autosave = true }

function M.path()
  local directory = vim.uv.fs_realpath(vim.fn.getcwd()) or vim.fn.getcwd()
  return vim.fn.stdpath('state') .. '/sessions/' .. vim.fn.sha256(directory) .. '.vim'
end

function M.save()
  local has_file = false
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    local name = vim.api.nvim_buf_get_name(buf)
    if vim.bo[buf].buflisted and vim.bo[buf].buftype == '' and name ~= ''
      and vim.fn.isdirectory(name) == 0 then
      has_file = true
      break
    end
  end
  -- An empty launch must not replace an existing project session.
  if not has_file then return false, 'No named file buffers to save' end
  local path = M.path()
  vim.fn.mkdir(vim.fs.dirname(path), 'p', 448)
  local temporary = path .. '.' .. vim.fn.getpid() .. '.tmp'
  local options, previous_session = vim.o.sessionoptions, vim.v.this_session
  -- Exclude terminals, explorer/picker windows, and plugin/runtime settings.
  vim.o.sessionoptions = 'buffers,curdir,folds,tabpages,winsize'
  local ok, err = pcall(vim.cmd.mksession, { temporary, bang = true })
  vim.o.sessionoptions, vim.v.this_session = options, previous_session
  if not ok then return false, tostring(err) end
  if vim.fn.rename(temporary, path) ~= 0 then
    vim.fn.delete(temporary)
    return false, 'Could not write session: ' .. path
  end
  return true
end

function M.restore()
  local path = M.path()
  if vim.fn.filereadable(path) ~= 1 then return false, 'No session saved for this directory' end
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.bo[buf].modified then return false, 'Save or discard modified buffers before restoring' end
  end
  local ok, err = pcall(vim.cmd.source, path)
  if not ok then return false, tostring(err) end
  return true
end

function M.setup()
  local function save()
    local ok, err = M.save()
    vim.notify(ok and 'Session saved' or err, ok and vim.log.levels.INFO or vim.log.levels.WARN)
  end
  local function restore()
    local ok, err = require('config.workspace').restore_session()
    if not ok then vim.notify(err, vim.log.levels.WARN) end
  end
  local function stop()
    M.autosave = false
    vim.notify('Session autosave stopped until Neovim restarts')
  end
  vim.keymap.set('n', '<leader>ss', save, { desc = 'Save session' })
  vim.keymap.set('n', '<leader>sr', restore, { desc = 'Restore session' })
  vim.keymap.set('n', '<leader>sd', stop, { desc = 'Stop session autosave' })
  vim.api.nvim_create_user_command('SessionSave', save, {})
  vim.api.nvim_create_user_command('SessionRestore', restore, {})
  vim.api.nvim_create_user_command('SessionStop', stop, {})
end

return M
