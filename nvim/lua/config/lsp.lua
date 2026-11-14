local M = {}
function M.setup()
  vim.diagnostic.config({
    virtual_text = true,
    virtual_lines = false,
    update_in_insert = false,
    severity_sort = true,
    float = { border = 'rounded', source = true },
    signs = { priority = 10, text = {
      [vim.diagnostic.severity.ERROR] = '●',
      [vim.diagnostic.severity.WARN] = '▲',
      [vim.diagnostic.severity.INFO] = 'i',
      [vim.diagnostic.severity.HINT] = '·',
    } },
  })
  require('mason').setup({})
  vim.lsp.config('*', { capabilities = require('cmp_nvim_lsp').default_capabilities() })
  local rust_analyzer = vim.fn.exepath('rust-analyzer')
  if rust_analyzer ~= '' then
    vim.lsp.config('rust_analyzer', { cmd = { rust_analyzer },
      root_dir = require('config.rust_root').wrap(vim.lsp.config.rust_analyzer.root_dir) })
  end
  vim.lsp.config('lua_ls', {
    root_dir = function(buf, on_dir)
      local filename = vim.api.nvim_buf_get_name(buf)
      local config_dir = vim.fn.stdpath('config')
      if vim.startswith(filename, config_dir .. '/') then
        on_dir(config_dir)
        return
      end
      local root = vim.fs.root(buf, { '.luarc.json', '.luarc.jsonc', '.git' })
      on_dir(root and root ~= vim.env.HOME and root or vim.fs.dirname(filename))
    end,
    settings = { Lua = {
    runtime = { version = 'LuaJIT' },
    diagnostics = { globals = { 'vim' } },
    workspace = { library = { vim.env.VIMRUNTIME }, checkThirdParty = false },
    telemetry = { enable = false },
  } } })
  for _, name in ipairs({ 'rust_analyzer', 'ts_ls', 'pyright', 'jsonls', 'lua_ls' }) do
    vim.lsp.config(name, { root_dir = require('config.large_files').guard_root(vim.lsp.config[name]) })
  end
  require('mason-lspconfig').setup({
    ensure_installed = { 'ts_ls', 'pyright', 'jsonls', 'lua_ls' },
    automatic_enable = { 'ts_ls', 'pyright', 'jsonls', 'lua_ls' },
  })
  if rust_analyzer ~= '' then vim.lsp.enable('rust_analyzer') end
  vim.api.nvim_create_autocmd('LspAttach', {
    group = vim.api.nvim_create_augroup('CustomLspKeys', { clear = true }),
    callback = function(event)
      local function map(key, action, desc)
        vim.keymap.set('n', key, action, { buffer = event.buf, desc = desc })
      end
      map('gd', vim.lsp.buf.definition, 'Go to definition')
      map('gr', vim.lsp.buf.references, 'Find references')
      map('K', vim.lsp.buf.hover, 'Documentation')
      map('<leader>rn', vim.lsp.buf.rename, 'Rename symbol')
      map('<leader>ca', vim.lsp.buf.code_action, 'Code action')
    end,
  })
  vim.keymap.set('n', '[d', function() vim.diagnostic.jump({ count = -1, float = true }) end,
    { desc = 'Previous diagnostic' })
  vim.keymap.set('n', ']d', function() vim.diagnostic.jump({ count = 1, float = true }) end,
    { desc = 'Next diagnostic' })
  vim.keymap.set('n', '<leader>dd', vim.diagnostic.setloclist, { desc = 'List diagnostics' })
  vim.api.nvim_create_autocmd('CursorHold', {
    group = vim.api.nvim_create_augroup('CustomDiagnosticHover', { clear = true }),
    callback = function() vim.diagnostic.open_float(nil, { focusable = false, scope = 'cursor' }) end,
  })
end
return M
