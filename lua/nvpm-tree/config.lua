-- nvpm-tree.nvim: default configuration
-- Mirrors the options exposed by vpm-tree.vim (g:vpm_tree_*)

local M = {}

M.defaults = {
  width = 35,
  position = "left", -- "left" or "right"
  show_hidden = false,
  max_depth = -1, -- -1 = unlimited
  sort_by = "name", -- "name", "size", "modified"
  ignore_patterns = {
    ".git",
    "node_modules",
    ".venv",
    "venv",
    "__pycache__",
    "*.pyc",
    ".DS_Store",
    "Thumbs.db",
    "dist",
    "build",
    "target",
    ".idea",
    ".vscode",
  },
  include_git = true,
  auto_close = false, -- close tree window after opening a file
  icons = {
    directory_closed = "▶",
    directory_open = "▼",
    symlink = "🔗",
    default_file = "",
    extensions = {
      vim = "󰈔",
      lua = "",
      py = "",
      js = "",
      ts = "",
      go = "",
      rs = "",
      md = "",
      json = "",
      yml = "",
      yaml = "",
      toml = "",
      txt = "",
      sh = "",
    },
  },
}

-- Active configuration (populated by setup())
M.options = vim.deepcopy(M.defaults)

--- Merge user options into the active configuration.
---@param opts table|nil
function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), opts or {})
  return M.options
end

return M
