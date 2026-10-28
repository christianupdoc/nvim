-- updoc: server/ declares the eslint plugins but not eslint itself, and the repo's own
-- eslint-plugins/ plugin requires typescript without installing it. Point eslint at the copy pnpm
-- installed, and let plugins fall back to server/node_modules for anything else.
-- Lives in after/ so it wins over nvim-lspconfig's lsp/eslint.lua; cmd is a plain list because
-- lspconfig's cmd function starts the process itself and ignores cmd_env.
local updoc = vim.fn.expand('~/Desktop/updoc')

-- The pinned eslint 9 only reads flat configs, but dto/ still has a legacy .eslintrc.yaml (and no
-- eslint install), so lspconfig attaches there and every diagnostic request fails with -32603.
-- Inside updoc, only attach where a flat config exists; elsewhere keep lspconfig's behaviour.
local flat_config_files = {
  'eslint.config.js',
  'eslint.config.mjs',
  'eslint.config.cjs',
  'eslint.config.ts',
  'eslint.config.mts',
  'eslint.config.cts',
}
local default_root_dir = dofile(vim.api.nvim_get_runtime_file('lsp/eslint.lua', false)[1]).root_dir

return {
  cmd = { 'vscode-eslint-language-server', '--stdio' },
  cmd_env = {
    NODE_PATH = updoc .. '/server/node_modules',
  },
  settings = {
    nodePath = updoc .. '/node_modules/.pnpm/eslint@9.18.0_jiti@2.6.1/node_modules',
    -- client/eslint.config.js enables @typescript-eslint/no-unused-vars without registering the
    -- plugin, so every client diagnostic request fails with -32603. Rules set to "off" skip
    -- plugin validation, so disabling it here unblocks the rest of the client rules.
    -- Core no-undef/no-unused-vars (from js.configs.recommended) misfire on TS types and
    -- constructor params; typescript-eslint recommends them off for TS, so drop them too.
    options = {
      overrideConfig = {
        rules = {
          ['@typescript-eslint/no-unused-vars'] = 'off',
          ['no-undef'] = 'off',
          ['no-unused-vars'] = 'off',
        },
      },
    },
  },
  root_dir = function(bufnr, on_dir)
    local filename = vim.api.nvim_buf_get_name(bufnr)
    if not vim.startswith(filename, updoc .. '/') then
      return default_root_dir(bufnr, on_dir)
    end
    local has_flat_config = vim.fs.find(flat_config_files, {
      path = filename,
      type = 'file',
      limit = 1,
      upward = true,
      stop = vim.fs.dirname(updoc),
    })[1]
    if has_flat_config then
      on_dir(updoc)
    end
  end,
}
