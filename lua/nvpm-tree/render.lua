-- nvpm-tree.nvim: buffer rendering
-- Equivalent to autoload/vpmtree/render.vim

local config = require("nvpm-tree.config")

local M = {}

local ns = vim.api.nvim_create_namespace("nvpm_tree")

--- Return the icon for a file based on its extension.
---@param name string
---@return string
local function file_icon(name)
  local ext = name:match("%.([^.]+)$")
  local icons = config.options.icons.extensions
  return (ext and icons[ext]) or config.options.icons.default_file
end

--- Return the icon representing a node (directory arrow, symlink, or file).
---@param node table
---@return string
local function node_icon(node)
  local icons = config.options.icons
  if node.type == "directory" then
    return node.expanded and icons.directory_open or icons.directory_closed
  elseif node.type == "symlink" then
    return icons.symlink
  end
  return file_icon(node.name)
end

--- Return the 3-character git status marker for a node, or 3 spaces.
---@param node table
---@return string
local function git_marker(node)
  if not node.git then
    return "   "
  end

  local status = node.git.status
  if node.git.conflict then
    return "[C]"
  elseif status == "added" then
    return "[A]"
  elseif status == "modified" then
    return "[M]"
  elseif status == "deleted" then
    return "[D]"
  elseif status == "renamed" then
    return "[R]"
  elseif status == "untracked" then
    return "[?]"
  end
  return "   "
end

--- Render a single node into a display line.
---@param node table
---@return string
local function render_node(node)
  local indent = string.rep("  ", node.depth)
  local icon = node_icon(node)
  local marker = git_marker(node)
  local name = node.name
  if node.type == "directory" then
    name = name .. "/"
  end
  return string.format("%s %s%s %s", marker, indent, icon, name)
end

--- Render the statistics footer line.
---@param stats table
---@return string
local function render_stats(stats)
  local parts = { string.format("Files: %d", stats.total_files), string.format("Dirs: %d", stats.total_dirs) }
  if stats.git_modified > 0 then
    table.insert(parts, string.format("Modified: %d", stats.git_modified))
  end
  if stats.git_staged > 0 then
    table.insert(parts, string.format("Staged: %d", stats.git_staged))
  end
  return " " .. table.concat(parts, " | ")
end

--- Apply syntax highlighting for the tree buffer.
---@param bufnr integer
local function apply_highlights(bufnr)
  vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)

  vim.cmd("highlight default link NvpmTreeHeader Title")
  vim.cmd("highlight default link NvpmTreeSeparator Comment")
  vim.cmd("highlight default link NvpmTreeDirIcon Directory")
  vim.cmd("highlight default link NvpmTreeFileIcon Normal")
  vim.cmd("highlight default link NvpmTreeDirectory Directory")
  vim.cmd("highlight default link NvpmTreeGitModified WarningMsg")
  vim.cmd("highlight default link NvpmTreeGitAdded DiffAdd")
  vim.cmd("highlight default link NvpmTreeGitDeleted DiffDelete")
  vim.cmd("highlight default link NvpmTreeGitUntracked Comment")
  vim.cmd("highlight default link NvpmTreeGitConflict ErrorMsg")
  vim.cmd("highlight default link NvpmTreeStats Comment")

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  for lnum, line in ipairs(lines) do
    local row = lnum - 1
    if lnum == 1 then
      vim.api.nvim_buf_add_highlight(bufnr, ns, "NvpmTreeHeader", row, 0, -1)
    elseif line:match("^─+$") then
      vim.api.nvim_buf_add_highlight(bufnr, ns, "NvpmTreeSeparator", row, 0, -1)
    elseif line:match("^ Files:") then
      vim.api.nvim_buf_add_highlight(bufnr, ns, "NvpmTreeStats", row, 0, -1)
    else
      local marker_groups = {
        { pattern = "%[M%]", hl = "NvpmTreeGitModified" },
        { pattern = "%[A%]", hl = "NvpmTreeGitAdded" },
        { pattern = "%[D%]", hl = "NvpmTreeGitDeleted" },
        { pattern = "%[%?%]", hl = "NvpmTreeGitUntracked" },
        { pattern = "%[C%]", hl = "NvpmTreeGitConflict" },
      }
      for _, group in ipairs(marker_groups) do
        local marker_s, marker_e = line:find(group.pattern)
        if marker_s then
          vim.api.nvim_buf_add_highlight(bufnr, ns, group.hl, row, marker_s - 1, marker_e)
          break
        end
      end

      if line:match("/$") then
        vim.api.nvim_buf_add_highlight(bufnr, ns, "NvpmTreeDirectory", row, 0, -1)
      end
    end
  end
end

--- Draw the full tree buffer from a tree_data table:
--- { root = string, nodes = table[], stats = table }
---@param bufnr integer
---@param tree_data table
function M.draw(bufnr, tree_data)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  local lines = {}
  local root_name = vim.fs.basename(tree_data.root)
  if root_name == "" then
    root_name = tree_data.root
  end
  table.insert(lines, " " .. root_name .. "/")
  table.insert(lines, string.rep("─", math.max(config.options.width - 1, 1)))

  for _, node in ipairs(tree_data.nodes or {}) do
    table.insert(lines, render_node(node))
  end

  if tree_data.stats then
    table.insert(lines, "")
    table.insert(lines, render_stats(tree_data.stats))
  end

  -- Preserve cursor position across full-buffer redraws.
  local winid = vim.fn.bufwinid(bufnr)
  local saved_line, saved_col = 1, 1
  if winid > 0 then
    local cursor = vim.api.nvim_win_get_cursor(winid)
    saved_line, saved_col = cursor[1], cursor[2]
  end

  vim.bo[bufnr].modifiable = true
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.bo[bufnr].modifiable = false

  apply_highlights(bufnr)

  if winid > 0 then
    local target_line = math.min(saved_line, #lines)
    if target_line >= 1 then
      pcall(vim.api.nvim_win_set_cursor, winid, { target_line, saved_col })
    end
  end
end

--- Header lines occupy the first two rows; footer occupies the last two
--- (blank line + stats) when stats are present. This mirrors core.vim's
--- fixed offset of 3 used to map a cursor line to a node index.
M.HEADER_LINES = 2

return M
