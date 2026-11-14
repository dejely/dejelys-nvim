return {
  { 'mfussenegger/nvim-dap', lazy = true,
    keys = require('config.debugging').keys(),
    cmd = { 'DapContinue', 'DapToggleBreakpoint', 'DapTerminate', 'DapShowLog' },
    config = function() require('config.debugging').setup() end },
  { 'folke/which-key.nvim',
    config = function() require('config.shortcuts').setup() end },
  { 'stevearc/conform.nvim',
    config = function() require('config.formatting').setup() end },
  { 'catppuccin/nvim', name = 'catppuccin', priority = 1000,
    config = function() require('config.theme').setup() end },
  { 'nvim-tree/nvim-web-devicons', opts = {} },
  { 'nvim-lualine/lualine.nvim', dependencies = { 'nvim-tree/nvim-web-devicons' },
    opts = { options = { theme = 'catppuccin-macchiato' } } },
  { 'akinsho/bufferline.nvim', dependencies = { 'nvim-tree/nvim-web-devicons' },
    opts = function() return { highlights = require('catppuccin.special.bufferline').get_theme(),
      options = { diagnostics = 'nvim_lsp', offsets = {
      { filetype = 'NvimTree', text = 'Files', highlight = 'Directory' },
    } } } end },
  { 'nvim-tree/nvim-tree.lua', dependencies = { 'nvim-tree/nvim-web-devicons' },
    config = function() require('config.explorer').setup() end },
  { 'ibhagwan/fzf-lua', dependencies = { 'nvim-tree/nvim-web-devicons' },
    config = function()
      local fzf = require('fzf-lua')
      fzf.setup({ winopts = { split = 'botright new', height = 0.4 } })
      for key, action in pairs({ ['<C-p>'] = 'files', ['<leader>ff'] = 'files',
        ['<leader>fb'] = 'buffers', ['<leader>fg'] = 'live_grep' }) do
        vim.keymap.set('n', key, fzf[action], { desc = action })
      end
      for name, action in pairs({ Files = 'files', Buffers = 'buffers', Rg = 'live_grep' }) do
        vim.api.nvim_create_user_command(name, function() fzf[action]() end, {})
      end
    end },
  { 'lukas-reineke/indent-blankline.nvim', main = 'ibl',
    config = function()
      local hooks = require('ibl.hooks')
      hooks.register(hooks.type.ACTIVE, function(buf) return not require('config.large_files').is_large(buf) end)
      require('ibl').setup({ indent = { char = '│', highlight = 'IblIndent' },
        scope = { enabled = false }, exclude = {
          filetypes = { 'help', 'NvimTree', 'markdown', 'json', 'jsonc', 'lazy', 'mason' },
          buftypes = { 'terminal', 'nofile', 'prompt', 'quickfix' },
        } })
      vim.keymap.set('n', '<leader>i', '<cmd>IBLToggle<CR>', { desc = 'Toggle indentation guides' })
    end },
  { 'nvim-treesitter/nvim-treesitter', lazy = false, build = ':TSUpdate',
    config = function()
      require('nvim-treesitter').setup({})
      vim.treesitter.language.register('json', 'jsonc')
      vim.api.nvim_create_autocmd('FileType', {
        group = vim.api.nvim_create_augroup('CustomTreesitter', { clear = true }),
        callback = function(event)
          require('config.large_files').start_treesitter(event.buf)
        end,
      })
    end },
  { 'lewis6991/gitsigns.nvim',
    config = function()
      local gs = require('gitsigns')
      gs.setup({ sign_priority = 5, signs = { add = { text = '+' }, change = { text = '~' },
        delete = { text = '_' }, topdelete = { text = '‾' }, changedelete = { text = '~' } },
        on_attach = function(buf)
          vim.keymap.set('n', ']h', function() gs.nav_hunk('next') end, { buffer = buf, desc = 'Next Git change' })
          vim.keymap.set('n', '[h', function() gs.nav_hunk('prev') end, { buffer = buf, desc = 'Previous Git change' })
          vim.keymap.set('n', '<leader>hp', gs.preview_hunk, { buffer = buf, desc = 'Preview Git change' })
        end })
    end },
  { 'hrsh7th/nvim-cmp', dependencies = { 'hrsh7th/cmp-nvim-lsp', 'hrsh7th/cmp-buffer',
    'hrsh7th/cmp-path' }, config = function() require('config.completion').setup() end },
  { 'neovim/nvim-lspconfig', dependencies = { 'mason-org/mason.nvim',
    'mason-org/mason-lspconfig.nvim', 'hrsh7th/cmp-nvim-lsp' },
    config = function() require('config.lsp').setup() end },
}
