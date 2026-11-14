local M = {}
function M.setup()
  local cmp = require('cmp')
  cmp.setup({
    preselect = cmp.PreselectMode.None,
    snippet = { expand = function(args) vim.snippet.expand(args.body) end },
    mapping = cmp.mapping.preset.insert({
      ['<C-Space>'] = cmp.mapping.complete(),
      ['<C-@>'] = cmp.mapping.complete(),
      ['<Tab>'] = cmp.mapping(function(fallback)
        if cmp.visible() then cmp.select_next_item() else fallback() end
      end, { 'i', 's' }),
      ['<S-Tab>'] = cmp.mapping(function(fallback)
        if cmp.visible() then cmp.select_prev_item() else fallback() end
      end, { 'i', 's' }),
      ['<CR>'] = cmp.mapping.confirm({ select = false }),
    }),
    sources = cmp.config.sources({ { name = 'nvim_lsp' }, { name = 'path' } }, { { name = 'buffer', option = { get_bufnrs = function()
      return require('config.large_files').is_large(0) and {} or { vim.api.nvim_get_current_buf() }
    end } } }),
  })
  cmp.setup.filetype({ 'TelescopePrompt', 'NvimTree' }, { enabled = false })
end
return M
