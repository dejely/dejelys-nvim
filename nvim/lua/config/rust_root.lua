local M = {}

local function is_standard_library(path)
  return path and vim.fs.normalize(path):find('/lib/rustlib/src/rust/', 1, true) ~= nil
end

function M.wrap(default_root)
  return function(buf, on_dir)
    local filename = vim.api.nvim_buf_get_name(buf)
    filename = vim.uv.fs_realpath(filename) or filename
    if is_standard_library(filename) then
      -- Rust library manifests use unstable Cargo features, even on stable.
      -- Browse them through an existing project client, never as a new crate.
      for _, client in ipairs(vim.lsp.get_clients({ name = 'rust_analyzer' })) do
        local root = client.config.root_dir
        if root and root ~= '' and not is_standard_library(root .. '/') then
          on_dir(root)
          return
        end
      end
      return
    end
    default_root(buf, on_dir)
  end
end

return M
