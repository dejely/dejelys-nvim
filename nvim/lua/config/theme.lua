local M = {}
M.terminal_colors = {
  '#101216', '#963747', '#35633e', '#70551c',
  '#28528a', '#754378', '#24616d', '#d8dee9',
  '#818898', '#f28b9b', '#a6da95', '#eed49f',
  '#8aadf4', '#f5bde6', '#91d7e3', '#f5f5f5',
}

function M.apply_terminal_colors(buf)
  for i, color in ipairs(M.terminal_colors) do
    if buf then
      vim.b[buf]['terminal_color_' .. (i - 1)] = color
    else
      vim.g['terminal_color_' .. (i - 1)] = color
    end
  end
end

function M.setup()
  require('catppuccin').setup({
    flavour = 'macchiato',
    integrations = { cmp = true, gitsigns = true, nvimtree = true, treesitter = true },
    custom_highlights = function()
      local highlights = {}
      for _, group in ipairs({ 'Normal', 'NormalNC', 'SignColumn', 'LineNr', 'EndOfBuffer',
        'NvimTreeNormal', 'NvimTreeNormalNC', 'NvimTreeEndOfBuffer', 'WinSeparator' }) do
        highlights[group] = { bg = '#1e1e1e' }
      end
      highlights.CursorLine = { bg = '#282828' }
      highlights.CursorLineNr = { fg = '#c6a0f6', bg = '#282828' }
      highlights.IblIndent = { fg = '#45475a' }
      return highlights
    end,
  })
  vim.cmd.colorscheme('catppuccin-macchiato')
  M.apply_terminal_colors()
  vim.api.nvim_create_autocmd('TermOpen', {
    group = vim.api.nvim_create_augroup('CustomTerminalColors', { clear = true }),
    callback = function(event) M.apply_terminal_colors(event.buf) end,
  })
end

return M
