-- nvpm-tree.nvim: core state machine
-- Equivalent to autoload/vpmtree/core.vim

local config = require("nvpm-tree.config")
local scanner = require("nvpm-tree.scanner")
local git = require("nvpm-tree.git")
local render = require("nvpm-tree.render")
local buffer = require("nvpm-tree.buffer")

local M = {}

--- Resolve `path` to an absolute, symlink-resolved, trailing-slash-free
--- path. Uses realpath so that paths derived from `getcwd()` (which macOS
--- resolves through symlinks such as /tmp -> /private/tmp) compare equal to
--- paths derived from e.g. `expand('%:p')` (which does not resolve them).
---@param path string
---@return string
local function real_path(path)
  local absolute = vim.fn.fnamemodify(path, ":p")
  local resolved = (vim.uv or vim.loop).fs_realpath(absolute)
  local normalized = vim.fs.normalize(resolved or absolute)
  return (normalized:gsub("/$", ""))
end

-- Module-level state (mirrors the script-local variables in core.vim)
local tree_bufnr = -1
local tree_data = { root = "", nodes = {}, stats = nil }
local current_root = ""
local git_status_map = {}
local is_git_repo = false

--- Attach git status information onto a freshly scanned node, in place.
---@param node table
local function apply_git(node)
  if not config.options.include_git or not is_git_repo then
    node.git = nil
    return
  end
  node.git = git.get_status(git_status_map, node.path, node.type == "directory")
end

--- Scan the immediate children of `path` and attach git info to each.
---@param path string
---@param depth integer
---@param parent_id string|nil
---@return table[] nodes
local function build_children(path, depth, parent_id)
  local nodes = scanner.scan_children(path, depth, parent_id, config.options)
  for _, node in ipairs(nodes) do
    apply_git(node)
  end
  return nodes
end

--- Recompute aggregate statistics over every node currently held in memory
--- (i.e. every node that has been scanned so far, visible or collapsed).
---@param nodes table[]
---@return table stats
local function compute_stats(nodes)
  local stats = {
    total_files = 0,
    total_dirs = 0,
    git_modified = 0,
    git_staged = 0,
    git_untracked = 0,
    git_conflicted = 0,
  }

  for _, node in ipairs(nodes) do
    if node.type == "directory" then
      stats.total_dirs = stats.total_dirs + 1
    else
      stats.total_files = stats.total_files + 1
    end

    if node.git then
      if node.git.status == "modified" or node.git.status == "added" or node.git.status == "deleted" then
        stats.git_modified = stats.git_modified + 1
      end
      if node.git.staged then
        stats.git_staged = stats.git_staged + 1
      end
      if node.git.untracked then
        stats.git_untracked = stats.git_untracked + 1
      end
      if node.git.conflict then
        stats.git_conflicted = stats.git_conflicted + 1
      end
    end
  end

  return stats
end

--- Map a 1-based cursor line number to a 1-based index into tree_data.nodes.
---@param lnum integer
---@return integer
local function line_to_index(lnum)
  return lnum - render.HEADER_LINES
end

--- Find the index of the node whose path equals `path`, or nil.
---@param path string
---@return integer|nil
local function find_node_index(path)
  for i, node in ipairs(tree_data.nodes) do
    if node.path == path then
      return i
    end
  end
  return nil
end

--- Expand the directory node at `idx`: fetch its immediate children and
--- splice them into tree_data.nodes right after it. No-op if not a
--- directory. Does not redraw the buffer.
---@param idx integer
local function expand_node(idx)
  local node = tree_data.nodes[idx]
  if not node or node.type ~= "directory" then
    return
  end

  local children = build_children(node.path, node.depth + 1, node.path)
  node.expanded = true
  for offset, child in ipairs(children) do
    table.insert(tree_data.nodes, idx + offset, child)
  end
end

--- Collapse the directory node at `idx`: drop the contiguous block of
--- descendants that follows it. Does not redraw the buffer.
---@param idx integer
local function collapse_node(idx)
  local node = tree_data.nodes[idx]
  if not node or node.type ~= "directory" then
    return
  end

  local remove_end = idx + 1
  while remove_end <= #tree_data.nodes and tree_data.nodes[remove_end].depth > node.depth do
    remove_end = remove_end + 1
  end

  for _ = idx + 1, remove_end - 1 do
    table.remove(tree_data.nodes, idx + 1)
  end

  node.expanded = false
end

--- Load (or reload) the whole tree rooted at `root`, discarding any
--- previously expanded state.
---@param root string
local function load_root(root)
  root = real_path(root)
  current_root = root

  if config.options.include_git then
    git_status_map, is_git_repo = git.load_status(root)
  else
    git_status_map, is_git_repo = {}, false
  end

  local nodes = build_children(root, 0, nil)
  tree_data = {
    root = root,
    nodes = nodes,
    stats = compute_stats(nodes),
  }
end

--- Reload the tree while preserving which directories were expanded.
local function load_root_preserving_expansion()
  local expanded_paths = {}
  for _, node in ipairs(tree_data.nodes) do
    if node.type == "directory" and node.expanded then
      expanded_paths[node.path] = true
    end
  end

  load_root(current_root)

  local i = 1
  while i <= #tree_data.nodes do
    local node = tree_data.nodes[i]
    if node.type == "directory" and expanded_paths[node.path] then
      expand_node(i)
      tree_data.stats = compute_stats(tree_data.nodes)
    end
    i = i + 1
  end
end

--- Open the tree window, creating the buffer on first use.
function M.open()
  local root = vim.fn.getcwd()

  if tree_bufnr > 0 and vim.api.nvim_buf_is_valid(tree_bufnr) then
    buffer.show_tree(tree_bufnr)
  else
    tree_bufnr = buffer.create_tree()
    require("nvpm-tree.keymap").setup(tree_bufnr)
  end

  load_root(root)
  render.draw(tree_bufnr, tree_data)
end

--- Close the tree window (buffer is kept alive for a fast re-open).
function M.close()
  if tree_bufnr <= 0 then
    return
  end
  local winid = vim.fn.bufwinid(tree_bufnr)
  if winid > 0 then
    vim.api.nvim_win_close(winid, true)
  end
end

--- Toggle the tree window open/closed.
function M.toggle()
  if tree_bufnr > 0 and vim.fn.bufwinid(tree_bufnr) > 0 then
    M.close()
  else
    M.open()
  end
end

--- Refresh the tree contents in place, preserving expanded directories and
--- the cursor position.
function M.refresh()
  if tree_bufnr <= 0 or not vim.api.nvim_buf_is_valid(tree_bufnr) then
    return
  end
  load_root_preserving_expansion()
  render.draw(tree_bufnr, tree_data)
end

--- Move focus into the tree window, opening it first if necessary.
function M.focus()
  if tree_bufnr > 0 then
    local winid = vim.fn.bufwinid(tree_bufnr)
    if winid > 0 then
      vim.api.nvim_set_current_win(winid)
      return
    end
  end
  M.open()
end

--- Locate `filepath` in the tree, expanding ancestor directories as needed,
--- and move the cursor onto it.
---@param filepath string
function M.find_file(filepath)
  if not filepath or filepath == "" or vim.fn.filereadable(filepath) == 0 then
    return
  end

  if tree_bufnr <= 0 or vim.fn.bufwinid(tree_bufnr) <= 0 then
    M.open()
  end

  local abs_path = real_path(filepath)
  local root = current_root
  if abs_path:sub(1, #root) ~= root then
    return
  end

  local rel = abs_path:sub(#root + 2)
  if rel == "" then
    return
  end

  local segments = vim.split(rel, "/", { plain = true })
  local dir_path = root
  for i = 1, #segments - 1 do
    dir_path = vim.fs.joinpath(dir_path, segments[i])
    local idx = find_node_index(dir_path)
    if idx and not tree_data.nodes[idx].expanded then
      expand_node(idx)
    end
  end

  tree_data.stats = compute_stats(tree_data.nodes)
  render.draw(tree_bufnr, tree_data)

  local target_idx = find_node_index(abs_path)
  if target_idx then
    local winid = vim.fn.bufwinid(tree_bufnr)
    if winid > 0 then
      pcall(vim.api.nvim_win_set_cursor, winid, { target_idx + render.HEADER_LINES, 0 })
    end
  end
end

--- Return the node displayed on 1-based buffer line `lnum`, or nil.
---@param lnum integer
---@return table|nil
function M.get_node_at_line(lnum)
  local idx = line_to_index(lnum)
  if idx < 1 or idx > #tree_data.nodes then
    return nil
  end
  return tree_data.nodes[idx]
end

--- Open the file, or toggle the directory, under the cursor.
function M.open_at_cursor()
  local lnum = vim.api.nvim_win_get_cursor(0)[1]
  local idx = line_to_index(lnum)
  if idx < 1 or idx > #tree_data.nodes then
    return
  end

  local node = tree_data.nodes[idx]
  if node.type == "directory" then
    if node.expanded then
      collapse_node(idx)
    else
      expand_node(idx)
    end
    tree_data.stats = compute_stats(tree_data.nodes)
    render.draw(tree_bufnr, tree_data)
  else
    vim.cmd("wincmd p")
    vim.cmd("edit " .. vim.fn.fnameescape(node.path))
    if config.options.auto_close then
      M.close()
    end
  end
end

--- Expand the directory under the cursor (no-op for files / already open).
function M.expand_at_cursor()
  local lnum = vim.api.nvim_win_get_cursor(0)[1]
  local idx = line_to_index(lnum)
  if idx < 1 or idx > #tree_data.nodes then
    return
  end
  local node = tree_data.nodes[idx]
  if node.type == "directory" and not node.expanded then
    expand_node(idx)
    tree_data.stats = compute_stats(tree_data.nodes)
    render.draw(tree_bufnr, tree_data)
  end
end

--- Collapse the directory under the cursor (no-op for files / already
--- collapsed).
function M.collapse_at_cursor()
  local lnum = vim.api.nvim_win_get_cursor(0)[1]
  local idx = line_to_index(lnum)
  if idx < 1 or idx > #tree_data.nodes then
    return
  end
  local node = tree_data.nodes[idx]
  if node.type == "directory" and node.expanded then
    collapse_node(idx)
    tree_data.stats = compute_stats(tree_data.nodes)
    render.draw(tree_bufnr, tree_data)
  end
end

--- Move the cursor onto the parent directory of the node under the cursor.
function M.go_to_parent()
  local lnum = vim.api.nvim_win_get_cursor(0)[1]
  local idx = line_to_index(lnum)
  if idx < 1 or idx > #tree_data.nodes then
    return
  end

  local node = tree_data.nodes[idx]
  local parent_id = node.parent_id
  if not parent_id then
    return
  end

  local parent_idx = find_node_index(parent_id)
  if parent_idx then
    vim.api.nvim_win_set_cursor(0, { parent_idx + render.HEADER_LINES, 0 })
  end
end

--- Change the tree root to the directory under the cursor.
function M.change_root()
  local lnum = vim.api.nvim_win_get_cursor(0)[1]
  local node = M.get_node_at_line(lnum)
  if not node then
    return
  end

  if node.type ~= "directory" then
    vim.notify("nvpm-tree: not a directory", vim.log.levels.INFO)
    return
  end

  vim.cmd("cd " .. vim.fn.fnameescape(node.path))
  load_root(node.path)
  render.draw(tree_bufnr, tree_data)
end

--- Autocommand hook, invoked on BufEnter. Reserved for future use.
function M.on_buf_enter() end

--- Return the tree buffer number (-1 if never created).
---@return integer
function M.get_tree_bufnr()
  return tree_bufnr
end

--- Whether the current window's buffer is the tree buffer.
---@return boolean
function M.is_tree_window()
  return vim.api.nvim_get_current_buf() == tree_bufnr
end

return M
