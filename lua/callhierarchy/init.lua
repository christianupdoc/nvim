-- callhierarchy: LSP call hierarchy as an expandable tree in a floating
-- modal, with a code preview on the right (same layout as Telescope).
local M = {}

local ns = vim.api.nvim_create_namespace("callhierarchy")
local state

local METHODS = {
  incoming = "callHierarchy/incomingCalls",
  outgoing = "callHierarchy/outgoingCalls",
}

-- Incoming: show where the caller calls us. Outgoing: show the callee itself.
local function location(node)
  if node.call_uri then return node.call_uri, node.call_range end
  return node.item.uri, node.item.selectionRange
end

local function node_at_cursor()
  if not (state and vim.api.nvim_win_is_valid(state.tree_win)) then return end
  return state.line_nodes[vim.api.nvim_win_get_cursor(state.tree_win)[1]]
end

local function close()
  if not state then return end
  local s = state
  state = nil
  for _, win in ipairs({ s.tree_win, s.preview_win }) do
    if vim.api.nvim_win_is_valid(win) then vim.api.nvim_win_close(win, true) end
  end
  for _, buf in pairs(s.previews) do
    if vim.api.nvim_buf_is_valid(buf) then vim.api.nvim_buf_delete(buf, { force = true }) end
  end
end

local function preview_buf(path)
  if state.previews[path] then return state.previews[path] end
  local lines
  local existing = vim.fn.bufnr(path)
  if existing ~= -1 and vim.api.nvim_buf_is_loaded(existing) then
    lines = vim.api.nvim_buf_get_lines(existing, 0, -1, false)
  else
    local ok, read = pcall(vim.fn.readfile, path)
    lines = ok and read or { "[could not read " .. path .. "]" }
  end

  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = "hide"
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  -- Highlight without setting 'filetype', so no FileType autocmds/LSP fire.
  local ft = vim.filetype.match({ filename = path, buf = buf })
  local lang = ft and vim.treesitter.language.get_lang(ft)
  if not (lang and pcall(vim.treesitter.start, buf, lang)) and ft then
    vim.bo[buf].syntax = ft
  end
  state.previews[path] = buf
  return buf
end

local function update_preview()
  local node = node_at_cursor()
  if not node or not vim.api.nvim_win_is_valid(state.preview_win) then return end
  local uri, range = location(node)
  local path = vim.uri_to_fname(uri)
  local buf = preview_buf(path)
  local win = state.preview_win
  local lnum = math.min(range.start.line + 1, vim.api.nvim_buf_line_count(buf))

  vim.api.nvim_win_set_buf(win, buf)
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  vim.api.nvim_buf_set_extmark(buf, ns, lnum - 1, 0, { line_hl_group = "Visual" })
  vim.api.nvim_win_set_cursor(win, { lnum, 0 })
  vim.api.nvim_win_call(win, function() vim.cmd("normal! zz") end)
  vim.api.nvim_win_set_config(win, {
    title = " " .. vim.fn.fnamemodify(path, ":~:.") .. ":" .. lnum .. " ",
    title_pos = "center",
  })
end

local function render()
  if not (state and vim.api.nvim_buf_is_valid(state.tree_buf)) then return end
  local current = node_at_cursor()
  local lines, hls, line_nodes = {}, {}, {}

  local function walk(node)
    local icon
    if node.children and #node.children == 0 then
      icon = "  "
    else
      icon = node.expanded and "▾ " or "▸ "
    end
    local indent = string.rep("  ", node.depth)
    local name = node.item.name
    local uri, range = location(node)
    local suffix = "  " .. vim.fn.fnamemodify(vim.uri_to_fname(uri), ":~:.") .. ":" .. (range.start.line + 1)
    if node.count and node.count > 1 then suffix = suffix .. " ×" .. node.count end
    if node.loading then suffix = suffix .. "  loading…" end

    local prefix = indent .. icon
    table.insert(lines, prefix .. name .. suffix)
    line_nodes[#lines] = node
    table.insert(hls, { #lines - 1, #prefix, #prefix + #name, node.depth == 0 and "Title" or "Function" })
    table.insert(hls, { #lines - 1, #prefix + #name, -1, "Comment" })

    if node.expanded and node.children then
      for _, child in ipairs(node.children) do walk(child) end
    end
  end
  walk(state.root)

  local buf = state.tree_buf
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  for _, h in ipairs(hls) do
    vim.api.nvim_buf_set_extmark(buf, ns, h[1], h[2], {
      end_col = h[3] == -1 and #lines[h[1] + 1] or h[3],
      hl_group = h[4],
    })
  end
  state.line_nodes = line_nodes

  for lnum, node in pairs(line_nodes) do
    if node == current then
      vim.api.nvim_win_set_cursor(state.tree_win, { lnum, 0 })
      break
    end
  end

  vim.api.nvim_win_set_config(state.tree_win, {
    title = (state.direction == "incoming" and " Incoming calls " or " Outgoing calls "),
    title_pos = "center",
  })
end

local function expand(node)
  if not node or (node.children and #node.children == 0) then return end
  node.expanded = true
  if node.children or node.loading then return render() end

  node.loading = true
  render()
  local s = state
  s.client:request(METHODS[s.direction], { item = node.item }, function(err, result)
    if state ~= s then return end
    node.loading = false
    node.children = {}
    if err then
      vim.notify("Call hierarchy: " .. err.message, vim.log.levels.WARN)
    end
    for _, call in ipairs(result or {}) do
      local item = call.from or call.to
      local child = { item = item, depth = node.depth + 1, parent = node, count = #(call.fromRanges or {}) }
      if s.direction == "incoming" and call.fromRanges and call.fromRanges[1] then
        child.call_uri, child.call_range = item.uri, call.fromRanges[1]
      end
      table.insert(node.children, child)
    end
    table.sort(node.children, function(a, b)
      local ua, ra = location(a)
      local ub, rb = location(b)
      if ua ~= ub then return ua < ub end
      return ra.start.line < rb.start.line
    end)
    render()
    update_preview()
  end, s.bufnr)
end

local function collapse(node)
  if not node then return end
  if node.expanded and node.depth > 0 then
    node.expanded = false
    return render()
  end
  local parent = node.parent
  if parent then
    for lnum, n in pairs(state.line_nodes) do
      if n == parent then return vim.api.nvim_win_set_cursor(state.tree_win, { lnum, 0 }) end
    end
  end
end

local function set_root(item, direction)
  state.direction = direction
  state.root = { item = item, depth = 0 }
  render()
  vim.api.nvim_win_set_cursor(state.tree_win, { 1, 0 })
  expand(state.root)
  update_preview()
end

local function jump(split_cmd)
  local node = node_at_cursor()
  if not node then return end
  local uri, range = location(node)
  local encoding = state.client.offset_encoding
  close()
  vim.cmd("normal! m'")
  if split_cmd then vim.cmd(split_cmd) end
  vim.lsp.util.show_document({ uri = uri, range = range }, encoding, { focus = true })
  vim.cmd("normal! zz")
end

local function open_ui(client, bufnr, item, direction)
  close()
  local width = math.floor(vim.o.columns * 0.85)
  local height = math.floor(vim.o.lines * 0.8)
  local row = math.floor((vim.o.lines - height) / 2) - 1
  local col = math.floor((vim.o.columns - width) / 2)
  local tree_width = math.floor(width * 0.4)

  local tree_buf = vim.api.nvim_create_buf(false, true)
  vim.bo[tree_buf].bufhidden = "wipe"
  vim.bo[tree_buf].filetype = "callhierarchy"

  local tree_win = vim.api.nvim_open_win(tree_buf, true, {
    relative = "editor", row = row, col = col, width = tree_width, height = height,
    border = "rounded", style = "minimal",
    footer = " <CR> jump  l/h open/close  t in/out  f focus  q quit ", footer_pos = "center",
  })
  vim.wo[tree_win].cursorline = true
  vim.wo[tree_win].wrap = false

  local preview_win = vim.api.nvim_open_win(vim.api.nvim_create_buf(false, true), false, {
    relative = "editor", row = row, col = col + tree_width + 2,
    width = width - tree_width - 2, height = height,
    border = "rounded", focusable = false,
  })
  vim.wo[preview_win].number = true
  vim.wo[preview_win].wrap = false
  vim.wo[preview_win].signcolumn = "no"

  state = {
    client = client, bufnr = bufnr, tree_buf = tree_buf, tree_win = tree_win,
    preview_win = preview_win, previews = {}, line_nodes = {},
  }

  local function map(keys, fn)
    for _, k in ipairs(keys) do
      vim.keymap.set("n", k, fn, { buffer = tree_buf, nowait = true, silent = true })
    end
  end
  map({ "<CR>", "o" }, function() jump() end)
  map({ "<C-v>" }, function() jump("vsplit") end)
  map({ "<C-x>" }, function() jump("split") end)
  map({ "l", "<Tab>", "<Right>" }, function() expand(node_at_cursor()) end)
  map({ "h", "<S-Tab>", "<Left>" }, function() collapse(node_at_cursor()) end)
  map({ "t" }, function()
    set_root(state.root.item, state.direction == "incoming" and "outgoing" or "incoming")
  end)
  map({ "f" }, function()
    local node = node_at_cursor()
    if node then set_root(node.item, state.direction) end
  end)
  map({ "q", "<Esc>" }, close)

  vim.api.nvim_create_autocmd("CursorMoved", { buffer = tree_buf, callback = update_preview })
  vim.api.nvim_create_autocmd("WinLeave", {
    buffer = tree_buf, once = true, callback = function() vim.schedule(close) end,
  })

  set_root(item, direction)
end

---@param direction? "incoming"|"outgoing"
function M.open(direction)
  direction = direction or "incoming"
  local bufnr = vim.api.nvim_get_current_buf()
  local client = vim.lsp.get_clients({ bufnr = bufnr, method = "textDocument/prepareCallHierarchy" })[1]
  if not client then
    return vim.notify("No attached LSP supports call hierarchy", vim.log.levels.WARN)
  end
  local params = vim.lsp.util.make_position_params(0, client.offset_encoding)
  client:request("textDocument/prepareCallHierarchy", params, function(err, result)
    if err or not result or #result == 0 then
      return vim.notify("No function under cursor", vim.log.levels.INFO)
    end
    open_ui(client, bufnr, result[1], direction)
  end, bufnr)
end

return M
