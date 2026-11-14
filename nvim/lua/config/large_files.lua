local M = { max_bytes = 1024 * 1024, max_line_bytes = 10000 }
local cache = {}

function M.is_large(buf)
  buf = buf == 0 and vim.api.nvim_get_current_buf() or buf
  if not vim.api.nvim_buf_is_valid(buf) or vim.bo[buf].buftype ~= '' then return false end
  if not vim.api.nvim_buf_is_loaded(buf) then
    local stat = vim.uv.fs_stat(vim.api.nvim_buf_get_name(buf))
    return stat ~= nil and stat.size > M.max_bytes
  end
  local tick = vim.api.nvim_buf_get_changedtick(buf)
  if cache[buf] and cache[buf].tick == tick then return cache[buf].large end
  local count = vim.api.nvim_buf_line_count(buf)
  local large = vim.api.nvim_buf_get_offset(buf, count) > M.max_bytes
  if not large then
    for first = 0, count - 1, 256 do
      for _, line in ipairs(vim.api.nvim_buf_get_lines(buf, first, math.min(first + 256, count), false)) do
        if #line > M.max_line_bytes then large = true; break end
      end
      if large then break end
    end
  end
  cache[buf] = { tick = tick, large = large }
  return large
end

function M.start_treesitter(buf)
  if M.is_large(buf) then return end
  local lang = vim.treesitter.language.get_lang(vim.bo[buf].filetype)
  if lang then
    local ok, available = pcall(vim.treesitter.language.add, lang)
    if ok and available then vim.treesitter.start(buf, lang) end
  end
end

-- Preserve each server's existing root logic, including Rust sysroot reuse.
function M.guard_root(config)
  local root = config.root_dir
  return function(buf, on_dir)
    if M.is_large(buf) then return end
    local attach = vim.schedule_wrap(function(directory)
      if vim.api.nvim_buf_is_valid(buf) and not M.is_large(buf) then on_dir(directory) end
    end)
    if type(root) == 'function' then root(buf, attach)
    else attach(root or vim.fs.root(buf, config.root_markers or {})) end
  end
end

function M.refresh(buf)
  local large = M.is_large(buf)
  local previous = vim.b[buf].large_file
  vim.b[buf].large_file = large
  if large then
    pcall(vim.treesitter.stop, buf)
    -- get_bufnrs prevents new indexes; close an existing index after growth.
    local source = package.loaded.cmp_buffer
    local index = source and source.buffers[buf]
    if index and not index.closed then index:close() end
    if package.loaded.ibl then require('ibl').setup_buffer(buf, { enabled = false }) end
    for _, client in ipairs(vim.lsp.get_clients({ bufnr = buf })) do
      vim.lsp.buf_detach_client(buf, client.id)
      -- Retain servers still serving other buffers in this project.
      vim.schedule(function()
        if not next(client.attached_buffers) then client:stop(true) end
      end)
    end
  elseif previous then
    if package.loaded.ibl then require('ibl').clear_buffer_state(buf); require('ibl').refresh(buf) end
    M.start_treesitter(buf)
    vim.api.nvim_exec_autocmds('FileType', { buffer = buf, modeline = false })
  end
end

function M.setup()
  -- Neovim's bundled Lua/Markdown ftplugins call start() themselves. Guard
  -- that entry point as well, before they can allocate a large syntax tree.
  if not M.guarded then
    local start = vim.treesitter.start
    vim.treesitter.start = function(buf, lang)
      if not M.is_large(buf or 0) then return start(buf, lang) end
    end
    M.guarded = true
  end
  local group = vim.api.nvim_create_augroup('CustomLargeFiles', { clear = true })
  vim.api.nvim_create_autocmd({ 'BufReadPost', 'BufNewFile', 'TextChanged', 'TextChangedI', 'BufWritePost' }, {
    group = group, callback = function(event) M.refresh(event.buf) end,
  })
  vim.api.nvim_create_autocmd('BufWipeout', {
    group = group, callback = function(event) cache[event.buf] = nil end,
  })
end
return M
