-- nvpm-tree.nvim: buffer-local key mappings
-- Equivalent to autoload/vpmtree/keymap.vim

local core = require("nvpm-tree.core")
local file_ops = require("nvpm-tree.file_ops")

local M = {}

local HELP_LINES = {
  "nvpm-tree Key Bindings:",
  "",
  "<CR>, o    - Open file/directory (toggle expand/collapse on dirs)",
  "l          - Expand directory",
  "h          - Collapse directory",
  "<Space>    - Toggle expand/collapse",
  "",
  "a          - Create new file",
  "A          - Create new directory",
  "d          - Delete file/directory",
  "r          - Rename file/directory",
  "",
  "R, <F5>    - Refresh tree",
  "q          - Close tree",
  "j/k        - Navigate up/down",
  "-, u       - Go to parent directory",
  "C          - Change root to current directory",
  "?          - Show this help",
}

local function show_help()
  vim.api.nvim_echo({ { table.concat(HELP_LINES, "\n"), "Title" } }, false, {})
end

--- Install buffer-local key mappings on the tree buffer.
---@param bufnr integer
function M.setup(bufnr)
  local function map(lhs, rhs, desc)
    vim.keymap.set("n", lhs, rhs, { buffer = bufnr, silent = true, nowait = true, desc = desc })
  end

  map("<CR>", core.open_at_cursor, "Open file/toggle directory")
  map("o", core.open_at_cursor, "Open file/toggle directory")

  map("l", core.expand_at_cursor, "Expand directory")
  map("h", core.collapse_at_cursor, "Collapse directory")

  map("<Space>", core.open_at_cursor, "Toggle expand/collapse")
  map("za", core.open_at_cursor, "Toggle expand/collapse")

  map("a", file_ops.create_file, "Create new file")
  map("A", file_ops.create_directory, "Create new directory")
  map("d", file_ops.delete, "Delete file/directory")
  map("r", file_ops.rename, "Rename file/directory")

  map("R", core.refresh, "Refresh tree")
  map("<F5>", core.refresh, "Refresh tree")

  map("q", core.close, "Close tree")

  map("-", core.go_to_parent, "Go to parent directory")
  map("u", core.go_to_parent, "Go to parent directory")

  map("C", core.change_root, "Change root to current directory")

  map("?", show_help, "Show help")
end

return M
