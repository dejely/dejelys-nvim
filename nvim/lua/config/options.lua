local o = vim.opt
o.number = true
o.relativenumber = false
o.cursorline = true
o.signcolumn = 'yes'
o.termguicolors = true
o.background = 'dark'
o.showmode = false
o.laststatus = 2
o.ruler = true
o.expandtab = true
o.tabstop = 4
o.shiftwidth = 4
o.smartindent = true
o.autoindent = true
o.wrap = true
o.scrolloff = 8
o.mouse = 'a'
o.splitbelow = true
o.splitright = true
o.incsearch = true
o.ignorecase = true
o.smartcase = true
o.hidden = true
o.undofile = true
local undo_dir = vim.fn.stdpath('state') .. '/undo'
vim.fn.mkdir(undo_dir, 'p', 448)
o.undodir = undo_dir .. '//'
vim.g.editorconfig = true
o.showmatch = true
o.wildmenu = true
o.showcmd = false
o.updatetime = 300
o.shortmess:append('c')
o.completeopt = { 'menu', 'menuone', 'noselect' }
local shell = vim.env.SHELL
if shell and vim.fn.executable(shell) == 1 then
    o.shell = shell
else
    o.shell = vim.fn.exepath('zsh') ~= '' and vim.fn.exepath('zsh') or vim.fn.exepath('sh')
end

-- Vim's Ctrl+W window commands also work while typing in a terminal.
vim.keymap.set('t', '<C-w>', [[<C-\><C-n><C-w>]], { desc = 'Window command' })

-- Cycle the visible Bufferline tabs with Ctrl+period/comma.
vim.keymap.set({ 'n', 'i' }, '<C-.>', '<cmd>BufferLineCycleNext<CR>', { desc = 'Next tab' })
vim.keymap.set({ 'n', 'i' }, '<C-,>', '<cmd>BufferLineCyclePrev<CR>', { desc = 'Previous tab' })
vim.keymap.set('t', '<C-.>', [[<C-\><C-n><cmd>BufferLineCycleNext<CR>]], { desc = 'Next tab' })
vim.keymap.set('t', '<C-,>', [[<C-\><C-n><cmd>BufferLineCyclePrev<CR>]], { desc = 'Previous tab' })

vim.keymap.set({ 'n', 'i' }, '<C-s>', '<cmd>write<CR>', { desc = 'Save file' })
