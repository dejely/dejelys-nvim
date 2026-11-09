local M = {}
function M.setup()
  local conform = require('conform')
  conform.setup({
    formatters_by_ft = {
      lua = { 'stylua' },
      python = { 'ruff_format' },
      rust = { 'rustfmt' },
      javascript = { 'prettier' },
      javascriptreact = { 'prettier' },
      typescript = { 'prettier' },
      typescriptreact = { 'prettier' },
      json = { 'prettier' },
      jsonc = { 'prettier' },
      html = { 'prettier' },
      css = { 'prettier' },
      markdown = { 'prettier' },
      yaml = { 'prettier' },
    },
  })
  vim.keymap.set({ 'n', 'v' }, '<leader>fm', function()
    conform.format({ async = true, lsp_format = 'fallback' })
  end, { desc = 'Format file or selection' })
end
return M
