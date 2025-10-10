-- Telescope
local builtin = require('telescope.builtin')

-- All files
vim.keymap.set('n', '<leader>ff', builtin.find_files, {})

-- Git files
vim.keymap.set('n', '<C-p>', builtin.git_files, {})

-- Live Grep
vim.keymap.set('n', '<leader>fg', builtin.live_grep, {})

return {
  "nvim-telescope/telescope.nvim", tag = '0.1.8',
  dependencies = { 'nvim-lua/plenary.nvim' }
}
