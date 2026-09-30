-- nvpm-tree.nvim: public entry point
--
-- A Neovim-native reimplementation of vpm-tree.vim
-- (https://github.com/ue555/vpm-tree.vim): a fast file tree explorer with
-- git status integration, written entirely in Lua (no external Go binary
-- required).

local config = require("nvpm-tree.config")
local core = require("nvpm-tree.core")

local M = {}

--- Configure nvpm-tree.nvim. Safe to call multiple times.
---@param opts table|nil see lua/nvpm-tree/config.lua for available options
function M.setup(opts)
  config.setup(opts)
end

M.open = core.open
M.close = core.close
M.toggle = core.toggle
M.refresh = core.refresh
M.focus = core.focus
M.find_file = core.find_file

return M
