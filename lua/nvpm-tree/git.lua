-- nvpm-tree.nvim: git status integration
-- Equivalent to pkg/git/status.go in vpm-tree.vim: runs `git status --porcelain`
-- once per tree load and maps absolute paths to a status descriptor.

local M = {}

--- Check whether `root` is inside a git working tree.
---@param root string
---@return boolean
local function is_git_repo(root)
  local out = vim.fn.systemlist({ "git", "-C", root, "rev-parse", "--is-inside-work-tree" })
  return vim.v.shell_error == 0 and out[1] == "true"
end

--- Parse a two-character porcelain status code into a status table.
---@param code string
---@return table
local function parse_status_code(code)
  local staged_code = code:sub(1, 1)
  local unstaged_code = code:sub(2, 2)

  local status = {
    status = "",
    staged = false,
    untracked = false,
    conflict = false,
  }

  if code == "??" then
    status.status = "untracked"
    status.untracked = true
    return status
  end

  if staged_code == "M" then
    status.status = "modified"
    status.staged = true
  elseif staged_code == "A" then
    status.status = "added"
    status.staged = true
  elseif staged_code == "D" then
    status.status = "deleted"
    status.staged = true
  elseif staged_code == "R" then
    status.status = "renamed"
    status.staged = true
  elseif staged_code == "C" then
    status.status = "copied"
    status.staged = true
  elseif staged_code == "U" then
    status.status = "updated"
    status.conflict = true
  end

  if unstaged_code ~= " " and unstaged_code ~= "?" then
    if unstaged_code == "M" then
      if status.status == "" then
        status.status = "modified"
      end
    elseif unstaged_code == "D" then
      if status.status == "" then
        status.status = "deleted"
      end
    elseif unstaged_code == "U" then
      status.conflict = true
    end
  end

  if status.status == "" then
    status.status = "clean"
  end

  return status
end

--- Load git status for every changed path under `root`.
---@param root string
---@return table<string, table>|nil status_map, boolean is_repo
function M.load_status(root)
  if not is_git_repo(root) then
    return {}, false
  end

  local lines = vim.fn.systemlist({ "git", "-C", root, "status", "--porcelain", "-uall" })
  if vim.v.shell_error ~= 0 then
    return {}, true
  end

  local status_map = {}
  for _, line in ipairs(lines) do
    if #line >= 4 then
      local code = line:sub(1, 2)
      local file_path = line:sub(4)
      -- Handle rename lines: "old -> new"
      local arrow = file_path:find(" %-> ")
      if arrow then
        file_path = file_path:sub(arrow + 4)
      end
      local abs_path = vim.fs.joinpath(root, file_path)
      status_map[vim.fs.normalize(abs_path)] = parse_status_code(code)
    end
  end

  return status_map, true
end

--- Look up the status for a specific absolute path, falling back to
--- "has modified descendants" semantics for directories.
---@param status_map table<string, table>
---@param path string
---@param is_dir boolean
---@return table|nil
function M.get_status(status_map, path, is_dir)
  local normalized = vim.fs.normalize(path)
  local direct = status_map[normalized]
  if direct then
    return direct
  end

  if is_dir then
    local prefix = normalized .. "/"
    for p, status in pairs(status_map) do
      if p:sub(1, #prefix) == prefix then
        return { status = "modified", staged = status.staged, untracked = false, conflict = false }
      end
    end
  end

  return nil
end

return M
