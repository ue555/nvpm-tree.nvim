-- nvpm-tree.nvim: tree window/buffer management
-- Equivalent to autoload/vpmtree/buffer.vim

local config = require("nvpm-tree.config")

local M = {}

--- Create a brand-new tree buffer in a fresh vertical split.
---@return integer bufnr
function M.create_tree()
  if config.options.position == "left" then
    vim.cmd("topleft vertical new")
  else
    vim.cmd("botright vertical new")
  end
  vim.cmd("vertical resize " .. config.options.width)

  local bufnr = vim.api.nvim_get_current_buf()

  vim.bo[bufnr].buftype = "nofile"
  vim.bo[bufnr].bufhidden = "hide"
  vim.bo[bufnr].swapfile = false
  vim.bo[bufnr].buflisted = false
  vim.bo[bufnr].filetype = "nvpmtree"
  vim.wo.wrap = false
  vim.wo.cursorline = true
  vim.wo.number = false
  vim.wo.relativenumber = false
  vim.wo.signcolumn = "no"
  vim.wo.foldcolumn = "0"
  vim.bo[bufnr].modifiable = false

  vim.api.nvim_buf_set_name(bufnr, "NvpmTree")

  return bufnr
end

--- Show an already-existing tree buffer in a new split, unless a window
--- displaying it is already visible.
---@param bufnr integer
function M.show_tree(bufnr)
  if vim.fn.bufwinid(bufnr) > 0 then
    return
  end

  if config.options.position == "left" then
    vim.cmd("topleft vertical split")
  else
    vim.cmd("botright vertical split")
  end
  vim.cmd("vertical resize " .. config.options.width)
  vim.cmd("buffer " .. bufnr)
end

return M
