local M = {}
function M.keys()
  local keys = {}
  for key, action in pairs({ ['<C-p>'] = 'files', ['<leader>ff'] = 'files',
    ['<leader>fb'] = 'buffers', ['<leader>fg'] = 'live_grep',
    ['<leader>fp'] = 'commands', ['<leader>fk'] = 'keymaps',
    ['<leader>dx'] = 'diagnostics_workspace' }) do
    keys[#keys + 1] = { key, function() require('fzf-lua')[action]() end, desc = action }
  end
  keys[#keys + 1] = { '<C-S-p>', function() require('fzf-lua').commands() end,
    mode = { 'n', 'i' }, desc = 'Command palette' }
  return keys
end
function M.setup()
  local fzf = require('fzf-lua')
  fzf.setup({ winopts = { split = 'botright new', height = 0.4 } })
  fzf.register_ui_select()
  for name, action in pairs({ Files = 'files', Buffers = 'buffers', Rg = 'live_grep' }) do
    vim.api.nvim_create_user_command(name, function() fzf[action]() end, {})
  end
end
return M
