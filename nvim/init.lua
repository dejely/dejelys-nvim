vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

require('config.options')

local lazy = vim.fn.stdpath('data') .. '/lazy/lazy.nvim'
if not vim.uv.fs_stat(lazy) then
  local result = vim.fn.system({ 'git', 'clone', '--filter=blob:none', '--branch=stable',
    'https://github.com/folke/lazy.nvim.git', lazy })
  if vim.v.shell_error ~= 0 then
    error('Could not install lazy.nvim: ' .. result)
  end
end
vim.opt.rtp:prepend(lazy)
require('lazy').setup('plugins', {
  change_detection = { notify = false },
  checker = { enabled = false },
  rocks = { enabled = false },
})
require('config.sessions').setup()
require('config.workspace').setup()
