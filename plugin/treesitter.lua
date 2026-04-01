vim.treesitter.language.register('swift', 'swift')

local installed_cache = {}
local skip_ft = {
  [""] = true, notify = true, noice = true, lazy = true, mason = true,
  NvimTree = true, TelescopePrompt = true, quickfix = true, help = true,
  checkhealth = true, lspinfo = true, man = true,
}

vim.api.nvim_create_autocmd("FileType", {
  callback = function(args)
    local ft = vim.bo[args.buf].filetype
    if skip_ft[ft] then return end

    local lang = vim.treesitter.language.get_lang(ft) or ft

    if not installed_cache[lang] and not pcall(vim.treesitter.language.inspect, lang) then
      installed_cache[lang] = true
      local available = require("nvim-treesitter").get_available()
      if not vim.list_contains(available, lang) then return end
      vim.schedule(function()
        require("nvim-treesitter").install({ lang })
      end)
      return
    end

    pcall(vim.treesitter.start, args.buf)
  end,
})

require('nvim-ts-autotag').setup({
    autotag = {
        enable = true,
        enable_close_on_slash = true,
    }
})
