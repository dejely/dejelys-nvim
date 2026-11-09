local M = {}

function M.keys()
  local bindings = {
    { '<F5>', 'continue', 'Start / continue debugger' },
    { '<F10>', 'step_over', 'Step over' },
    { '<F11>', 'step_into', 'Step into' },
    { '<S-F11>', 'step_out', 'Step out' },
    { '<leader>bb', 'breakpoint', 'Toggle breakpoint' },
    { '<leader>bc', 'condition', 'Conditional breakpoint' },
    { '<leader>bp', 'pause', 'Pause debugger' },
    { '<leader>bu', 'toolbar', 'Toggle debug toolbar' },
    { '<leader>bv', 'scopes', 'Inspect variables' },
    { '<leader>be', 'hover', 'Inspect expression' },
    { '<leader>br', 'repl', 'Toggle debug output / REPL' },
    { '<leader>bq', 'stop', 'Stop debugger' },
  }
  local keys = {}
  for _, binding in ipairs(bindings) do
    local action = binding[2]
    keys[#keys + 1] = { binding[1], function() M.action(action) end, desc = binding[3], mode = 'n' }
  end
  return keys
end

function M.action(action)
  local dap = require('dap')
  if action == 'breakpoint' then dap.toggle_breakpoint()
  elseif action == 'condition' then
    vim.ui.input({ prompt = 'Breakpoint condition: ' }, function(value)
      if value and value ~= '' then dap.set_breakpoint(value) end
    end)
  elseif action == 'toolbar' then require('config.debug_toolbar').toggle()
  elseif action == 'stop' then
    dap.terminate()
  elseif action == 'repl' then dap.repl.toggle({}, 'botright 10split')
  elseif action == 'continue' then
    if not dap.session() and vim.fn.executable('codelldb') ~= 1 then
      vim.notify('Run :MasonInstall codelldb before debugging', vim.log.levels.ERROR)
      return
    end
    dap.continue()
  elseif not dap.session() then vim.notify('Start debugging with F5 first', vim.log.levels.INFO)
  elseif action == 'scopes' then require('config.debug_toolbar').scopes()
  elseif action == 'hover' then require('dap.ui.widgets').hover()
  else dap[action]() end
end

function M.setup()
  local dap = require('dap')
  dap.adapters.codelldb = function(callback)
    local executable = vim.fn.exepath('codelldb')
    if executable == '' then
      vim.notify('CodeLLDB is missing. Run :MasonInstall codelldb, then retry F5.', vim.log.levels.ERROR)
      return
    end
    callback({ type = 'server', port = '${port}',
      executable = { command = executable, args = { '--port', '${port}' } } })
  end
  -- Accept VS Code's native CodeLLDB adapter name as well.
  dap.adapters.lldb = dap.adapters.codelldb
  local configuration = {
    name = 'Launch executable', type = 'codelldb', request = 'launch',
    program = function()
      local ok, path = pcall(vim.fn.input, 'Executable: ', vim.fn.getcwd() .. '/', 'file')
      if not ok or path == '' then return dap.ABORT end
      path = vim.fn.fnamemodify(vim.fn.expand(path), ':p')
      if vim.fn.executable(path) ~= 1 or vim.fn.isdirectory(path) == 1 then
        vim.notify('Choose a compiled executable (build with debug symbols first)', vim.log.levels.WARN)
        return dap.ABORT
      end
      return path
    end,
    cwd = '${workspaceFolder}', args = {}, terminal = 'console', stopOnEntry = false,
  }
  for _, filetype in ipairs({ 'rust', 'c', 'cpp' }) do
    dap.configurations[filetype] = { vim.deepcopy(configuration) }
  end
  local vscode = require('dap.ext.vscode')
  vscode.type_to_filetypes.codelldb = { 'rust', 'c', 'cpp' }
  vscode.type_to_filetypes.lldb = { 'rust', 'c', 'cpp' }
  vim.fn.sign_define('DapBreakpoint', { text = '●', texthl = 'DiagnosticError' })
  vim.fn.sign_define('DapStopped', { text = '▶', texthl = 'DiagnosticWarn', linehl = 'Visual' })
  require('config.debug_toolbar').setup(dap)
end

return M
