-- nvpm-tree.nvim: user commands, <Plug> mappings, and autocommands
-- Equivalent to plugin/vpm-tree.vim

if vim.g.loaded_nvpm_tree then
  return
end
vim.g.loaded_nvpm_tree = 1

if vim.fn.has("nvim-0.9") ~= 1 then
  vim.notify("nvpm-tree.nvim requires Neovim >= 0.9", vim.log.levels.ERROR)
  return
end

local nvpmtree = require("nvpm-tree")
local core = require("nvpm-tree.core")

vim.api.nvim_create_user_command("NvpmTreeToggle", nvpmtree.toggle, {})
vim.api.nvim_create_user_command("NvpmTreeOpen", nvpmtree.open, {})
vim.api.nvim_create_user_command("NvpmTreeClose", nvpmtree.close, {})
vim.api.nvim_create_user_command("NvpmTreeRefresh", nvpmtree.refresh, {})
vim.api.nvim_create_user_command("NvpmTreeFocus", nvpmtree.focus, {})
vim.api.nvim_create_user_command("NvpmTreeFind", function()
  nvpmtree.find_file(vim.fn.expand("%:p"))
end, {})

vim.keymap.set("n", "<Plug>(nvpm-tree-toggle)", nvpmtree.toggle, { silent = true })
vim.keymap.set("n", "<Plug>(nvpm-tree-open)", nvpmtree.open, { silent = true })
vim.keymap.set("n", "<Plug>(nvpm-tree-close)", nvpmtree.close, { silent = true })
vim.keymap.set("n", "<Plug>(nvpm-tree-refresh)", nvpmtree.refresh, { silent = true })
vim.keymap.set("n", "<Plug>(nvpm-tree-focus)", nvpmtree.focus, { silent = true })
vim.keymap.set("n", "<Plug>(nvpm-tree-find)", function()
  nvpmtree.find_file(vim.fn.expand("%:p"))
end, { silent = true })

local group = vim.api.nvim_create_augroup("NvpmTree", { clear = true })
vim.api.nvim_create_autocmd("BufEnter", {
  group = group,
  callback = function()
    core.on_buf_enter()
  end,
})
