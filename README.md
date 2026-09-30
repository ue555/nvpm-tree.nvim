# nvpm-tree.nvim

A blazing-fast, git-aware file tree explorer for Neovim, implemented entirely in Lua.

[日本語 README はこちら](README_ja.md)

## Name Origin

**nvpm-tree.nvim** combines:
- **nvpm** = **N**eo**v**im **P**ackage **M**anager (the parent project)
- **tree** = File tree explorer
- **.nvim** = Neovim plugin naming convention

nvpm-tree.nvim is a Neovim-native reimplementation of
[vpm-tree.vim](https://github.com/ue555/vpm-tree.vim), bringing the same UI,
key bindings, and git-aware file tree experience to Neovim — without
requiring an external Go CLI binary.

## ✨ Features

- ⚡ **Fast** - Native filesystem scanning via `vim.loop` (libuv)
- 🎯 **Git Integration** - Show git status, staged files, conflicts
- 🚀 **Lazy Loading** - Directories are scanned on demand as you expand them
- 🎨 **Beautiful UI** - Icons, colors, and clean interface
- ⌨️ **Pure Lua** - Modern Neovim Lua plugin, no build step
- 🔧 **Configurable** - Extensive customization options
- 💪 **Lightweight** - No external binary or dependency to install
- 📝 **File Operations** - Create, delete, and rename files/directories directly from the tree

## Architecture

```
┌────────────────────────────────┐
│   Neovim 0.9+ (Editor)        │
│   ┌────────────────────────┐  │
│   │ nvpm-tree.nvim         │  │
│   │ (Lua Plugin)           │  │
│   │  - Filesystem scanning │  │
│   │    via vim.loop        │  │
│   │  - Git status via      │  │
│   │    `git` CLI           │  │
│   └────────────────────────┘  │
└────────────────────────────────┘
```

Unlike vpm-tree.vim, there is no separate CLI process or JSON boundary:
scanning, rendering, and state management all run in-process as Lua.

## Requirements

- **Neovim** >= 0.9
- **Git** (optional, for git status integration)

## Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "kouji/nvpm-tree.nvim", -- or a local path: dir = "~/dev/nvpm-tree.nvim"
  opts = {},
}
```

### Using [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use({
  "kouji/nvpm-tree.nvim",
  config = function()
    require("nvpm-tree").setup({})
  end,
})
```

### Manual Installation

```bash
git clone https://github.com/kouji/nvpm-tree.nvim.git \
  ~/.local/share/nvim/site/pack/plugins/start/nvpm-tree.nvim
```

Then add to your `init.lua`:

```lua
require("nvpm-tree").setup({})
```

No build step is required — nvpm-tree.nvim is pure Lua.

## Usage

### Basic Commands

```vim
" Toggle tree
:NvpmTreeToggle

" Open tree
:NvpmTreeOpen

" Close tree
:NvpmTreeClose

" Refresh tree
:NvpmTreeRefresh

" Focus the tree window
:NvpmTreeFocus

" Find current file in tree
:NvpmTreeFind
```

### Key Mappings

Inside the tree window:

| Key | Action |
|-----|--------|
| `<CR>`, `o` | Open file/directory (toggle expand/collapse on dirs) |
| `l` | Expand directory |
| `h` | Collapse directory |
| `<Space>`, `za` | Toggle expand/collapse |
| `a` | Create new file |
| `A` | Create new directory |
| `d` | Delete file/directory |
| `r` | Rename file/directory |
| `R`, `<F5>` | Refresh tree |
| `q` | Close tree |
| `j/k` | Navigate up/down |
| `-`, `u` | Go to parent directory |
| `C` | Change root to directory under cursor |
| `?` | Show help |

### File Operations

nvpm-tree.nvim supports common file operations directly from the tree:

#### Create File (`a`)
Press `a` to create a new file in the current directory (or parent directory if cursor is on a file).
You will be prompted to enter the filename.

#### Create Directory (`A`)
Press `A` to create a new directory in the current directory (or parent directory if cursor is on a file).
You will be prompted to enter the directory name.

#### Delete (`d`)
Press `d` to delete the file or directory at cursor. You will be asked to confirm the deletion.
For directories, all contents will be deleted recursively.

#### Rename (`r`)
Press `r` to rename the file or directory at cursor. You will be prompted to enter the new name.
Open buffers under the renamed path are automatically retargeted.

### Recommended Key Mappings

Add to your `init.lua`:

```lua
-- Toggle tree with ]e
vim.keymap.set("n", "]e", "<cmd>NvpmTreeToggle<CR>")

-- Or use Ctrl-n
vim.keymap.set("n", "<C-n>", "<Plug>(nvpm-tree-toggle)")

-- Find current file with Leader-f
vim.keymap.set("n", "<Leader>f", "<Plug>(nvpm-tree-find)")
```

## Configuration

### Default Settings

```lua
require("nvpm-tree").setup({
  width = 35,                -- tree window width
  position = "left",         -- "left" or "right"
  show_hidden = false,       -- show hidden files
  max_depth = -1,            -- reserved; scanning is always lazy/on-demand
  sort_by = "name",          -- "name", "size", or "modified"
  ignore_patterns = {
    ".git", "node_modules", ".venv", "venv", "__pycache__",
    "*.pyc", ".DS_Store", "Thumbs.db", "dist", "build", "target",
    ".idea", ".vscode",
  },
  include_git = true,        -- show git status markers
  auto_close = false,        -- close tree after opening a file
})
```

### Example Configuration

```lua
require("nvpm-tree").setup({
  width = 40,
  show_hidden = true,
  ignore_patterns = { "*.tmp", "*.bak", "vendor" },
})

vim.keymap.set("n", "<C-n>", "<Plug>(nvpm-tree-toggle)")
vim.keymap.set("n", "<Leader>f", "<Plug>(nvpm-tree-find)")
```

## Git Integration

nvpm-tree.nvim provides rich git integration by parsing `git status --porcelain`:

- **[M]** - Modified files
- **[A]** - Added files
- **[D]** - Deleted files
- **[R]** - Renamed files
- **[?]** - Untracked files
- **[C]** - Conflicted files

Directories inherit a `[M]` marker when any descendant has changes.
Statistics (`Files: N | Dirs: N | Modified: N | Staged: N`) are shown in
the footer, aggregated over every node scanned so far.

## Comparison

### vs vpm-tree.vim
- 💪 No external Go CLI binary to build or install
- ⚡ Runs entirely in-process via `vim.loop`, no JSON round-trip
- ✅ Neovim-native: `<Plug>` mappings, `vim.keymap.set`, Lua `setup()`

### vs nvim-tree.lua / neo-tree.nvim
- 🔧 Minimal, single-purpose implementation mirroring vpm-tree.vim's UI/UX
- 📝 Same key bindings and file-operation workflow as vpm-tree.vim

## Troubleshooting

### Git information not showing

```bash
# Check git availability
which git

# Check repository status
cd /path/to/project
git status
```

### Tree not opening

```vim
" Check Neovim version (requires >= 0.9)
:version
```

## License

MIT License

## Acknowledgments

nvpm-tree.nvim is a Neovim port of
[vpm-tree.vim](https://github.com/ue555/vpm-tree.vim), which was in turn
inspired by:
- [nvim-tree.lua](https://github.com/nvim-tree/nvim-tree.lua)
- [neo-tree.nvim](https://github.com/nvim-neo-tree/neo-tree.nvim)
- [NERDTree](https://github.com/preservim/nerdtree)

## Related Projects

- [vpm-tree.vim](https://github.com/ue555/vpm-tree.vim) - The original Vim9script + Go CLI plugin
- [vpm](https://github.com/ue555/vpm) - Vim Package Manager
- [nvpm](https://github.com/ue555/nvpm) - Neovim Package Manager
