-- Overrides nvim-lspconfig's terraformls on_attach, which calls the
-- 0.12-only vim.lsp.codelens.enable() and errors on 0.11.
vim.lsp.config("terraformls", {
  on_attach = function(_, bufnr)
    if vim.lsp.codelens and vim.lsp.codelens.enable then
      vim.lsp.codelens.enable(true, { bufnr = bufnr })
    end
  end,
})

vim.lsp.enable({
  "lua_ls",
  "vimls",
  "pyright",
  "vtsls",
  "cssls",
  "clojure_lsp",
  "jsonls",
  "sqls",
  "sourcekit",
  "jdtls",
  "terraformls",
  "prisma"
})


vim.diagnostic.config({
    virtual_lines = false,
    virtual_text = false,
    underline = false,
    update_in_insert = false,
    severity_sort = true,
    float = {
        border = "rounded",
        source = true,
    },
    signs = {
        text = {
            [vim.diagnostic.severity.ERROR] = "󰅚 ",
            [vim.diagnostic.severity.WARN] = "󰀪 ",
            [vim.diagnostic.severity.INFO] = "󰋽 ",
            [vim.diagnostic.severity.HINT] = "󰌶 ",
        },
        numhl = {
            [vim.diagnostic.severity.ERROR] = "ErrorMsg",
            [vim.diagnostic.severity.WARN] = "WarningMsg",
        },
    },
})

vim.opt.updatetime = 250

vim.api.nvim_create_autocmd("CursorHold", {
    callback = function()
        vim.diagnostic.open_float(nil, { focusable = false })
    end,
})
