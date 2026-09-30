-- nvpm-tree.nvim: filesystem scanner
-- Equivalent to pkg/tree/scanner.go in vpm-tree.vim, implemented natively
-- with vim.loop (libuv) instead of shelling out to a Go binary.

local uv = vim.uv or vim.loop

local M = {}

--- Check whether `name` matches any of the configured ignore patterns.
---@param name string
---@param patterns string[]
---@return boolean
local function should_ignore(name, patterns)
  for _, pattern in ipairs(patterns) do
    if name == pattern then
      return true
    end
    -- Translate a simple glob pattern (e.g. "*.pyc") to a Lua pattern.
    local lua_pattern = "^" .. pattern:gsub("[%(%)%.%%%+%-%[%]%^%$]", "%%%1"):gsub("%*", ".*") .. "$"
    if name:match(lua_pattern) then
      return true
    end
  end
  return false
end

--- Build the metadata table for a single directory entry.
---@param path string
---@param entry_type string libuv entry type: "file", "directory", "link", ...
---@return table metadata, string node_type
local function stat_node(path, entry_type)
  local stat = uv.fs_stat(path)
  local node_type = "file"
  if entry_type == "directory" then
    node_type = "directory"
  elseif entry_type == "link" then
    node_type = "symlink"
  end

  local metadata = {
    size = stat and stat.size or 0,
    modified = stat and stat.mtime and stat.mtime.sec or 0,
    permissions = stat and ("%o"):format(stat.mode and (stat.mode % 512) or 0) or "",
    is_hidden = vim.fs.basename(path):sub(1, 1) == ".",
  }

  return metadata, node_type
end

--- Count the visible (non-ignored) children of a directory, for display
--- purposes only (e.g. deciding whether an expand arrow should be shown).
---@param path string
---@param config table
---@return integer
function M.count_children(path, config)
  local fd = uv.fs_scandir(path)
  if not fd then
    return 0
  end

  local count = 0
  while true do
    local name = uv.fs_scandir_next(fd)
    if not name then
      break
    end
    if config.show_hidden or name:sub(1, 1) ~= "." then
      if not should_ignore(name, config.ignore_patterns) then
        count = count + 1
      end
    end
  end
  return count
end

--- Scan the immediate children of `path` (one level, non-recursive).
---@param path string absolute directory path
---@param depth integer depth of the *children* being produced
---@param parent_id string|nil id (= absolute path) of the parent node, nil for root
---@param config table active plugin configuration
---@return table[] nodes
function M.scan_children(path, depth, parent_id, config)
  local fd = uv.fs_scandir(path)
  if not fd then
    return {}
  end

  local nodes = {}
  while true do
    local name, entry_type = uv.fs_scandir_next(fd)
    if not name then
      break
    end

    if config.show_hidden or name:sub(1, 1) ~= "." then
      if not should_ignore(name, config.ignore_patterns) then
        local full_path = vim.fs.joinpath(path, name)
        local metadata, node_type = stat_node(full_path, entry_type)

        local node = {
          id = full_path,
          name = name,
          path = full_path,
          type = node_type,
          depth = depth,
          parent_id = parent_id,
          children_count = 0,
          git = nil,
          metadata = metadata,
          expanded = false,
        }

        if node_type == "directory" then
          node.children_count = M.count_children(full_path, config)
        end

        table.insert(nodes, node)
      end
    end
  end

  M.sort_nodes(nodes, config.sort_by)
  return nodes
end

--- Sort nodes in place according to `sort_by` ("name", "size", "modified").
--- Directories are always grouped before files, matching vpm-tree.vim.
---@param nodes table[]
---@param sort_by string
function M.sort_nodes(nodes, sort_by)
  table.sort(nodes, function(a, b)
    if a.type == "directory" and b.type ~= "directory" then
      return true
    end
    if a.type ~= "directory" and b.type == "directory" then
      return false
    end

    if sort_by == "size" then
      return a.metadata.size > b.metadata.size
    elseif sort_by == "modified" then
      return a.metadata.modified > b.metadata.modified
    end

    return a.name:lower() < b.name:lower()
  end)
end

return M
