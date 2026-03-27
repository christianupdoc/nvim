vim.treesitter.language.register('swift', 'swift')

-- Auto-install parsers when opening a file
vim.api.nvim_create_autocmd("FileType", {
  callback = function(args)
    pcall(vim.treesitter.start, args.buf)
  end,
})

require('nvim-ts-autotag').setup({
    autotag = {
        enable = true,
        -- enable_close = true,
        enable_close_on_slash = true,
    }
})
