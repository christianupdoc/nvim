-- funcsearch: live grep, but only for function definitions.
-- Wraps ripgrep with per-language "function definition" regexes and
-- shows results in a Telescope picker with the usual preview pane.
local M = {}

-- Characters allowed in a function name (covers lua M.foo / M:foo,
-- clojure ->foo! / valid? and js $foo).
local NAME_CHARS = [=[[\w$!?*<>.:-]*]=]

-- Each pattern contains `NAME`, which is swapped for the escaped query.
local PATTERNS = {
  -- Lua
  [=[^\s*(local\s+)?function\s+NAME\s*\(]=],
  [=[^\s*(local\s+)?NAME\s*=\s*function\b]=],
  -- Python
  [=[^\s*(async\s+)?def\s+NAME\s*\(]=],
  -- JS/TS: function declarations
  [=[^\s*(export\s+)?(default\s+)?(async\s+)?function\s*\*?\s*NAME\s*[(<]]=],
  -- JS/TS: const foo = () => / function / async
  [=[^\s*(export\s+)?(const|let|var)\s+NAME\s*(:[^=]+)?=\s*(async\s+)?(function\b|\([^)]*(\)\s*(:[^=]+)?=>|$)|[\w$]+\s*=>|<)]=],
  -- JS/TS: class / object methods
  [=[^\s*((public|private|protected|static|async|readonly|override|abstract|get|set)\s+)*NAME\s*(<[^>]*>)?\([^)]*\)\s*(:\s*[^{;]+)?\{\s*$]=],
  -- Clojure
  [=[^\s*\((defn-?|defmacro|defmulti|defmethod|defprotocol)\s+(\^\S+\s+)?NAME]=],
  -- Go / Swift
  [=[\bfunc\s+(\([^)]*\)\s*)?NAME\s*[(<\[]]=],
  -- Rust
  [=[\bfn\s+NAME\s*[(<]]=],
  -- Java
  [=[^\s*((public|private|protected|static|final|abstract|synchronized|default)\s+)+[\w<>\[\],.? ]+\s+NAME\s*\(]=],
}

-- Control-flow lines the JS method pattern can catch on an empty query.
local KEYWORDS = { "if", "for", "while", "switch", "catch", "return", "else", "with" }

local function is_keyword_line(text)
  local word = (text or ""):match("^%s*([%w_]+)")
  return word ~= nil and vim.tbl_contains(KEYWORDS, word)
end

local function escape_regex(s)
  return (s:gsub("[%^%$%(%)%.%[%]%*%+%-%?%{%}%|\\#&~]", "\\%0"))
end

local function build_cmd(prompt)
  local name = NAME_CHARS .. escape_regex(prompt) .. NAME_CHARS
  local cmd = {
    "rg", "--color=never", "--no-heading", "--with-filename",
    "--line-number", "--column", "--max-columns=300",
    prompt:match("%u") and "--case-sensitive" or "--ignore-case",
  }
  for _, p in ipairs(PATTERNS) do
    table.insert(cmd, "-e")
    -- function replacement so `%` in the name isn't treated specially
    table.insert(cmd, (p:gsub("NAME", function() return name end)))
  end
  return cmd
end

function M.search(opts)
  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local make_entry = require("telescope.make_entry")
  local sorters = require("telescope.sorters")
  local conf = require("telescope.config").values

  opts = opts or {}
  opts.cwd = opts.cwd or vim.uv.cwd()

  local vimgrep_entry = make_entry.gen_from_vimgrep(opts)
  local entry_maker = function(line)
    local entry = vimgrep_entry(line)
    if entry and is_keyword_line(entry.text) then return nil end
    return entry
  end

  pickers.new(opts, {
    prompt_title = "Find Functions",
    finder = finders.new_job(function(prompt)
      return build_cmd(prompt or "")
    end, entry_maker, nil, opts.cwd),
    previewer = conf.grep_previewer(opts),
    sorter = sorters.highlighter_only(opts),
  }):find()
end

return M
