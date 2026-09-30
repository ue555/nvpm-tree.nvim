-- nvpm-tree.nvim: file operations (create / delete / rename)
-- Equivalent to autoload/vpmtree/file_ops.vim

local core = require("nvpm-tree.core")

local M = {}

--- Normalize a path for buffer-name comparisons (absolute, no trailing "/").
---@param path string
---@return string
local function normalize_path(path)
  return (vim.fs.normalize(vim.fn.fnamemodify(path, ":p")):gsub("/$", ""))
end

--- Resolve a directory + user-typed name/relative-path into an absolute path.
---@param target_path string
---@param input_path string
---@return string
local function resolve_path(target_path, input_path)
  local relative = input_path
  if relative:sub(1, 2) == "./" then
    relative = relative:sub(3)
  end
  return vim.fs.normalize(vim.fs.joinpath(target_path, relative))
end

--- Prompt the user for input, temporarily moving focus out of the (fixed
--- width, unmodifiable) tree window so `input()` behaves normally.
---@param message string
---@param default_value string|nil
---@return string
local function prompt(message, default_value)
  local tree_winid = vim.fn.win_getid()
  local ok, result = pcall(vim.fn.input, message, default_value or "")
  if vim.fn.win_getid() ~= tree_winid and vim.api.nvim_win_is_valid(tree_winid) then
    vim.fn.win_gotoid(tree_winid)
  end
  return ok and result or ""
end

--- Determine the directory that new files/dirs should be created in, based
--- on the node under the cursor (its own path if a directory, else its
--- parent), falling back to cwd.
---@return string
local function target_dir_at_cursor()
  local node = core.get_node_at_line(vim.api.nvim_win_get_cursor(0)[1])
  if not node then
    return vim.fn.getcwd()
  end
  if node.type == "directory" then
    return node.path
  end
  return vim.fn.fnamemodify(node.path, ":h")
end

--- Create a new file, prompting for its name relative to the cursor node
--- (or `parent_path` if given).
---@param parent_path string|nil
function M.create_file(parent_path)
  local target_path = parent_path or target_dir_at_cursor()
  local filename = prompt("Enter file name: ")

  if filename == "" then
    vim.notify("File creation cancelled", vim.log.levels.INFO)
    return
  end

  local filepath = resolve_path(target_path, filename)

  if vim.fn.filereadable(filepath) == 1 or vim.fn.isdirectory(filepath) == 1 then
    vim.notify("File or directory already exists: " .. filename, vim.log.levels.ERROR)
    return
  end

  local ok, err = pcall(function()
    vim.fn.mkdir(vim.fn.fnamemodify(filepath, ":h"), "p")
    vim.fn.writefile({}, filepath)
  end)

  if ok then
    vim.notify("Created file: " .. filepath, vim.log.levels.INFO)
    core.refresh()
  else
    vim.notify("Failed to create file: " .. tostring(err), vim.log.levels.ERROR)
  end
end

--- Create a new directory, prompting for its name relative to the cursor
--- node (or `parent_path` if given).
---@param parent_path string|nil
function M.create_directory(parent_path)
  local target_path = parent_path or target_dir_at_cursor()
  local dirname = prompt("Enter directory name: ")

  if dirname == "" then
    vim.notify("Directory creation cancelled", vim.log.levels.INFO)
    return
  end

  local dirpath = resolve_path(target_path, dirname)

  if vim.fn.isdirectory(dirpath) == 1 or vim.fn.filereadable(dirpath) == 1 then
    vim.notify("File or directory already exists: " .. dirname, vim.log.levels.ERROR)
    return
  end

  local ok, err = pcall(vim.fn.mkdir, dirpath, "p")
  if ok then
    vim.notify("Created directory: " .. dirpath, vim.log.levels.INFO)
    core.refresh()
  else
    vim.notify("Failed to create directory: " .. tostring(err), vim.log.levels.ERROR)
  end
end

--- Delete the file/directory under the cursor, after confirmation.
function M.delete()
  local node = core.get_node_at_line(vim.api.nvim_win_get_cursor(0)[1])
  if not node then
    vim.notify("No file or directory at cursor", vim.log.levels.ERROR)
    return
  end

  local name = vim.fn.fnamemodify(node.path, ":t")
  local msg = node.type == "directory" and ('Delete directory "' .. name .. '" and all its contents? (y/n): ')
    or ('Delete file "' .. name .. '"? (y/n): ')

  local confirm = prompt(msg)
  if confirm:lower() ~= "y" and confirm:lower() ~= "yes" then
    vim.notify("Deletion cancelled", vim.log.levels.INFO)
    return
  end

  local flags = node.type == "directory" and "rf" or ""
  local result = vim.fn.delete(node.path, flags)

  if result == 0 then
    vim.notify((node.type == "directory" and "Deleted directory: " or "Deleted file: ") .. name, vim.log.levels.INFO)
    core.refresh()
  else
    vim.notify((node.type == "directory" and "Failed to delete directory: " or "Failed to delete file: ") .. name, vim.log.levels.ERROR)
  end
end

--- Rename any loaded/open buffers under `old_path` to their equivalent path
--- under `new_path` (handles both single files and whole directory moves).
---@param old_path string
---@param new_path string
local function rename_open_buffers(old_path, new_path)
  local old_norm = normalize_path(old_path)
  local new_norm = normalize_path(new_path)
  local old_prefix = old_norm .. "/"
  local source_is_dir = vim.fn.isdirectory(new_path) == 1

  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    local name = vim.api.nvim_buf_get_name(bufnr)
    if name ~= "" then
      local buf_norm = normalize_path(name)
      local new_buf_path = nil

      if buf_norm == old_norm then
        new_buf_path = new_norm
      elseif source_is_dir and buf_norm:sub(1, #old_prefix) == old_prefix then
        new_buf_path = new_norm .. buf_norm:sub(#old_norm + 1)
      end

      if new_buf_path and vim.api.nvim_buf_is_loaded(bufnr) then
        local win_ids = vim.fn.win_findbuf(bufnr)
        if #win_ids > 0 then
          vim.api.nvim_win_call(win_ids[1], function()
            vim.cmd("keepalt file " .. vim.fn.fnameescape(new_buf_path))
          end)
        else
          vim.api.nvim_buf_set_name(bufnr, new_buf_path)
        end
      end
    end
  end
end

--- Rename `old_path` to `new_path` on disk and fix up any open buffers.
---@param old_path string
---@param new_path string
---@return boolean
function M.rename_path(old_path, new_path)
  if vim.fn.filereadable(new_path) == 1 or vim.fn.isdirectory(new_path) == 1 then
    vim.notify("File or directory already exists: " .. vim.fn.fnamemodify(new_path, ":t"), vim.log.levels.ERROR)
    return false
  end

  local ok = vim.uv.fs_rename(old_path, new_path)
  if not ok then
    return false
  end

  rename_open_buffers(old_path, new_path)
  return true
end

--- Rename the file/directory under the cursor, prompting for the new name.
function M.rename()
  local node = core.get_node_at_line(vim.api.nvim_win_get_cursor(0)[1])
  if not node then
    vim.notify("No file or directory at cursor", vim.log.levels.ERROR)
    return
  end

  local old_path = node.path
  local old_name = vim.fn.fnamemodify(old_path, ":t")
  local parent_dir = vim.fn.fnamemodify(old_path, ":h")

  local new_name = prompt('Rename "' .. old_name .. '" to: ', old_name)
  if new_name == "" then
    vim.notify("Rename cancelled", vim.log.levels.INFO)
    return
  end
  if new_name == old_name then
    vim.notify("Name unchanged", vim.log.levels.INFO)
    return
  end

  local new_path = vim.fs.joinpath(parent_dir, new_name)

  if M.rename_path(old_path, new_path) then
    vim.notify('Renamed "' .. old_name .. '" to "' .. new_name .. '"', vim.log.levels.INFO)
    core.refresh()
  else
    vim.notify("Failed to rename: " .. old_name, vim.log.levels.ERROR)
  end
end

return M
