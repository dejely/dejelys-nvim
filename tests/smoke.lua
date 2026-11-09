-- Run inside an installed copy, in an isolated HOME/XDG environment.
assert(vim.o.undofile, 'Persistent undo is disabled')
assert(vim.fn.isdirectory(vim.fn.stdpath('state') .. '/undo') == 1)
assert(vim.fn.exists(':BufferLineCycleNext') == 2)
assert(vim.fn.exists(':ConformInfo') == 2)
assert(vim.fn.exists(':NvimTreeToggle') == 2)
for _, mode in ipairs({ 'n', 'i', 't' }) do
  assert(vim.fn.maparg('<C-.>', mode):find('BufferLineCycleNext', 1, true))
  assert(vim.fn.maparg('<C-,>', mode):find('BufferLineCyclePrev', 1, true))
end

local directory = vim.fn.tempname()
vim.fn.mkdir(directory, 'p')
vim.fn.writefile({ 'root = true', '[*]', 'indent_style = space', 'indent_size = 2' },
  directory .. '/.editorconfig')
local fixtures = {
  ['sample.lua'] = { 'local banana={1,2,3}', 'print(banana)' },
  ['sample.js'] = { 'const banana={a:1,b:2}' },
  ['sample.py'] = { 'banana={"a":1,"b":2}' },
}
for filename, content in pairs(fixtures) do
  local path = directory .. '/' .. filename
  vim.fn.writefile(content, path)
  vim.cmd.edit(path)
  assert(vim.bo.shiftwidth == 2, 'EditorConfig failed: ' .. filename)
  local error
  require('conform').format({ async = false, timeout_ms = 15000, lsp_format = 'never' },
    function(err) error = err end)
  assert(not error, vim.inspect(error))
  assert(not vim.deep_equal(content, vim.api.nvim_buf_get_lines(0, 0, -1, false)),
    'Formatter made no change: ' .. filename)
  vim.bo.modified = false
end
vim.cmd.edit(vim.fn.stdpath('config') .. '/lua/config/options.lua')
assert(vim.wait(30000, function()
  for _, client in ipairs(vim.lsp.get_clients({ bufnr = 0, name = 'lua_ls' })) do
    if client.initialized then
      assert(client.config.root_dir == vim.fn.stdpath('config'))
      return true
    end
  end
  return false
end, 100), 'Lua language server did not initialize')
vim.fn.delete(directory, 'rf')
print('Smoke checks passed: config, mappings, formatting, EditorConfig, Lua LSP.')
