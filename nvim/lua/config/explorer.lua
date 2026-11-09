local M = {}

function M.setup()
  local api = require('nvim-tree.api')
  require('nvim-tree').setup({
    disable_netrw = true,
    hijack_netrw = true,
    hijack_directories = { enable = false },
    sync_root_with_cwd = true,
    -- Refresh on entry rather than spending filesystem watches on large projects.
    filesystem_watchers = { enable = false },
    reload_on_bufenter = true,
    view = { width = 30 },
    renderer = { group_empty = false },
    filters = { dotfiles = false, git_ignored = false, custom = {
      '^node_modules$', [[^\.git$]], '^build$', '^dist$', '^target$',
      [[^\.next$]], [[^\.expo$]], '^__pycache__$',
    } },
    on_attach = function(buf)
      api.config.mappings.default_on_attach(buf)
      local opts = { buffer = buf, silent = true, nowait = true }
      vim.keymap.set('n', 'C', api.tree.change_root_to_node, opts)
      vim.keymap.set('n', 'u', api.tree.change_root_to_parent, opts)
      vim.keymap.set('n', 'f', api.tree.toggle_custom_filter, opts)
    end,
  })
  vim.keymap.set('n', '<C-n>', api.tree.toggle, { desc = 'Toggle explorer' })
  vim.keymap.set('n', '<leader>e', function() api.tree.find_file({ open = true, focus = true }) end,
    { desc = 'Reveal current file' })
  vim.api.nvim_create_user_command('NERDTreeToggle', api.tree.toggle, {})
  vim.api.nvim_create_user_command('NERDTreeFind', function()
    api.tree.find_file({ open = true, focus = true })
  end, {})
  vim.api.nvim_create_user_command('NERDTreeCWD', function()
    api.tree.open()
    api.tree.change_root(vim.fn.getcwd())
  end, {})
end

return M
