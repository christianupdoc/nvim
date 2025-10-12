require'nvim-treesitter.configs'.setup {
  ensure_installed = { "c", "lua", "vim", "vimdoc", "query", "css", "cpp", "python", "javascript", "html", "css", "json"},
  sync_install = false,
  auto_install = true,
  highlight = {
    enable = true,
    additional_vim_regex_highlighting = false,
  },
  indent = {
    enable = true,
  },
}

require('nvim-ts-autotag').setup({
    autotag = {
        enable = true,
        -- enable_close = true,
        enable_close_on_slash = true,
    }
})
