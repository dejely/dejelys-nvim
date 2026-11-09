-- Run after Lazy restore so every required plugin is present.
local registry = require('mason-registry')
local tools = {
  'typescript-language-server', 'pyright', 'json-lsp', 'lua-language-server',
  'stylua', 'prettier', 'ruff', 'codelldb',
}
local refresh_done, refresh_ok = false, false
registry.refresh(function(ok)
  refresh_ok, refresh_done = ok, true
end)
assert(vim.wait(120000, function() return refresh_done end, 100), 'Mason registry refresh timed out')
assert(refresh_ok, 'Mason registry refresh failed; check :MasonLog')
for _, name in ipairs(tools) do
  local package = registry.get_package(name)
  if not package:is_installed() and not package:is_installing() then package:install() end
end
assert(vim.wait(300000, function()
  for _, name in ipairs(tools) do
    local package = registry.get_package(name)
    if package:is_installing() or not package:is_installed() then return false end
  end
  return true
end, 200), 'Language tool installation failed or timed out; check :MasonLog')

local parsers = {
  'rust', 'javascript', 'typescript', 'tsx', 'python', 'json',
  'lua', 'vim', 'vimdoc', 'markdown', 'markdown_inline', 'bash', 'html', 'css', 'yaml',
}
require('nvim-treesitter').install(parsers):wait(300000)
local installed = require('nvim-treesitter').get_installed()
for _, parser in ipairs(parsers) do
  assert(vim.tbl_contains(installed, parser), 'Parser installation failed: ' .. parser)
end
print('Language servers, formatters, CodeLLDB, and syntax parsers installed.')
