local M = {}
function M.setup()
  local wk = require('which-key')
  wk.setup({
    preset = 'modern',
    delay = 350,
    spec = {
      { '<leader>f', group = 'Files and formatting' },
      { '<leader>s', group = 'Sessions' },
      { '<leader>r', group = 'Refactor' },
      { '<leader>c', group = 'Code' },
      { '<leader>d', group = 'Diagnostics' },
      { '<leader>h', group = 'Git changes' },
    },
  })
  local function show() wk.show({ global = true }) end
  -- Normal mode only: preserve Backspace/Ctrl+H while typing and in shells.
  vim.keymap.set('n', '<C-h>', show, { desc = 'Show shortcut guide' })
  vim.keymap.set('n', '<leader>?', show, { desc = 'Show shortcut guide' })
end
return M
