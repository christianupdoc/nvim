-- BUFFERLINE
vim.opt.termguicolors = true

local cp = require("catppuccin.palettes").get_palette() -- current flavour (macchiato)

-- Make the SELECTED buffer a catppuccin-blue slant. Everything else keeps the
-- themed look. Setting every `*_selected` group to the same bg avoids colour
-- bleed inside the tab (incl. the `*_diagnostic_selected` groups that the
-- diagnostic count uses, otherwise it renders on a dark `base` patch).
local accent = cp.blue
local selected = {}
for _, group in ipairs({
    "buffer_selected", "numbers_selected", "duplicate_selected",
    "close_button_selected", "modified_selected", "indicator_selected",
    "diagnostic_selected", "hint_selected", "info_selected",
    "warning_selected", "error_selected",
    "error_diagnostic_selected", "warning_diagnostic_selected",
    "info_diagnostic_selected", "hint_diagnostic_selected",
}) do
    selected[group] = { fg = cp.crust, bg = accent }
end
selected.buffer_selected.style = { "bold" }
selected.numbers_selected.style = { "bold" }
-- The slant glyph fades the accent tab into the bar's fill (crust), so there is
-- no leftover separator block after the buffer.
selected.separator_selected = { fg = cp.crust, bg = accent }

require("bufferline").setup({
    -- Themed highlights so slants blend into the bar instead of rendering as a
    -- dark block (the artifact from un-themed `padded_slant`).
    highlights = require("catppuccin.special.bufferline").get_theme({
        custom = { all = selected },
    }),
    options = {
        separator_style = "slant",
        diagnostics = "nvim_lsp",
        diagnostics_indicator = function(count, level)
            local icon = level:match("error") and " " or " "
            return " " .. icon .. count
        end
    }
})
