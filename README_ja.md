# nvpm-tree.nvim

Luaのみで実装された、Neovim用の高速でGit連携対応のファイルツリーエクスプローラー。

[English README is here](README.md)

## 名前の由来

**nvpm-tree.nvim**は以下を組み合わせたものです：

- **nvpm** = **N**eo**v**im **P**ackage **M**anager（親プロジェクト）
- **tree** = ファイルツリーエクスプローラー
- **.nvim** = Neovimプラグインの命名規則

nvpm-tree.nvimは、[vpm-tree.vim](https://github.com/ue555/vpm-tree.vim)
をNeovim向けに移植したプラグインです。外部のGo製CLIバイナリを必要とせず、
同じUI・キーバインド・Git連携のファイルツリー体験をNeovimで提供します。

## ✨ 特徴

- ⚡ **高速** - `vim.loop`（libuv）によるネイティブなファイルスキャン
- 🎯 **Git統合** - Gitステータス、ステージングファイル、コンフリクト表示
- 🚀 **遅延読み込み** - ディレクトリを展開したタイミングでオンデマンドにスキャン
- 🎨 **美しいUI** - アイコン、カラー、クリーンなインターフェース
- ⌨️ **Pure Lua** - モダンなNeovim Luaプラグイン、ビルド不要
- 🔧 **カスタマイズ可能** - 豊富なカスタマイズオプション
- 💪 **軽量** - 外部バイナリ・依存関係のインストール不要
- 📝 **ファイル操作** - ツリーから直接ファイル/ディレクトリの作成・削除・リネームが可能

## アーキテクチャ

```
┌────────────────────────────────┐
│   Neovim 0.9+ (エディタ)       │
│   ┌────────────────────────┐  │
│   │ nvpm-tree.nvim         │  │
│   │ (Lua Plugin)           │  │
│   │  - vim.loopによる       │  │
│   │    ファイルスキャン     │  │
│   │  - `git`コマンドによる  │  │
│   │    Gitステータス取得    │  │
│   └────────────────────────┘  │
└────────────────────────────────┘
```

vpm-tree.vimとは異なり、別プロセスのCLIやJSON境界は存在しません。
スキャン・描画・状態管理はすべてLuaでプロセス内完結します。

## 必要要件

- **Neovim** >= 0.9
- **Git**（オプション、Git連携機能用）

## インストール

### [lazy.nvim](https://github.com/folke/lazy.nvim)を使用

```lua
{
  "ue555/nvpm-tree.nvim", -- ローカルパスの場合: dir = "~/dev/nvpm-tree.nvim"
  opts = {},
}
```

### nvpmを使用

`plugins.json`に以下を追加：

```json
{
  "plugins": ["ue555/nvpm-tree.nvim"]
}
```

`init.lua`に以下を追加：

```lua
require("nvpm-tree").setup({})
```

### 手動インストール

```bash
git clone https://github.com/ue555/nvpm-tree.nvim.git \
  ~/.local/share/nvim/site/pack/plugins/start/nvpm-tree.nvim
```

`init.lua`に以下を追加：

```lua
require("nvpm-tree").setup({})
```

nvpm-tree.nvimはPure Luaのため、ビルド手順は不要です。

## 使い方

### 基本コマンド

```vim
" ツリーをトグル
:NvpmTreeToggle

" ツリーを開く
:NvpmTreeOpen

" ツリーを閉じる
:NvpmTreeClose

" ツリーをリフレッシュ
:NvpmTreeRefresh

" ツリーウィンドウにフォーカス
:NvpmTreeFocus

" 現在のファイルをツリーで検索
:NvpmTreeFind
```

### キーマッピング

ツリーウィンドウ内：

| キー            | 動作                                                         |
| --------------- | ------------------------------------------------------------ |
| `<CR>`, `o`     | ファイル/ディレクトリを開く（ディレクトリは展開/折りたたみ） |
| `l`             | ディレクトリを展開                                           |
| `h`             | ディレクトリを折りたたむ                                     |
| `<Space>`, `za` | 展開/折りたたみをトグル                                      |
| `a`             | 新しいファイルを作成                                         |
| `A`             | 新しいディレクトリを作成                                     |
| `d`             | ファイル/ディレクトリを削除                                  |
| `r`             | ファイル/ディレクトリをリネーム                              |
| `R`, `<F5>`     | ツリーをリフレッシュ                                         |
| `q`             | ツリーを閉じる                                               |
| `j/k`           | 上下に移動                                                   |
| `-`, `u`        | 親ディレクトリに移動                                         |
| `C`             | カーソル下のディレクトリをルートに変更                       |
| `?`             | ヘルプを表示                                                 |

### ファイル操作

nvpm-tree.nvimは、ツリーから直接以下のファイル操作をサポートします：

#### ファイル作成 (`a`)

`a`を押すと、カレントディレクトリ（カーソルがファイル上にある場合は親ディレクトリ）に
新しいファイルを作成します。ファイル名の入力を求められます。

#### ディレクトリ作成 (`A`)

`A`を押すと、カレントディレクトリ（カーソルがファイル上にある場合は親ディレクトリ）に
新しいディレクトリを作成します。ディレクトリ名の入力を求められます。

#### 削除 (`d`)

`d`を押すと、カーソル位置のファイル/ディレクトリを削除します。削除前に確認を求められます。
ディレクトリの場合、内容はすべて再帰的に削除されます。

#### リネーム (`r`)

`r`を押すと、カーソル位置のファイル/ディレクトリをリネームします。新しい名前の入力を求められます。
リネーム対象を開いているバッファは自動的に新しいパスに追従します。

### 推奨キーマッピング

`init.lua`に追加：

```lua
-- ]eでツリーをトグル
vim.keymap.set("n", "]e", "<cmd>NvpmTreeToggle<CR>")

-- または、Ctrl-nでトグル
vim.keymap.set("n", "<C-n>", "<Plug>(nvpm-tree-toggle)")

-- Leader-fで現在のファイルを検索
vim.keymap.set("n", "<Leader>f", "<Plug>(nvpm-tree-find)")
```

## 設定

### デフォルト設定

```lua
require("nvpm-tree").setup({
  width = 35,                -- ツリーウィンドウの幅
  position = "left",         -- "left" または "right"
  show_hidden = false,       -- 隠しファイルを表示
  max_depth = -1,            -- 予約済み(スキャンは常に遅延・オンデマンド)
  sort_by = "name",          -- "name", "size", "modified"
  ignore_patterns = {
    ".git", "node_modules", ".venv", "venv", "__pycache__",
    "*.pyc", ".DS_Store", "Thumbs.db", "dist", "build", "target",
    ".idea", ".vscode",
  },
  include_git = true,        -- Gitステータスマーカーを表示
  auto_close = false,        -- ファイルを開いたときに自動的にツリーを閉じる
})
```

### 設定例

```lua
require("nvpm-tree").setup({
  width = 40,
  show_hidden = true,
  ignore_patterns = { "*.tmp", "*.bak", "vendor" },
})

vim.keymap.set("n", "<C-n>", "<Plug>(nvpm-tree-toggle)")
vim.keymap.set("n", "<Leader>f", "<Plug>(nvpm-tree-find)")
```

## Git統合

nvpm-tree.nvimは`git status --porcelain`を解析し、豊富なGit統合を提供します：

- **[M]** - 変更されたファイル
- **[A]** - 追加されたファイル
- **[D]** - 削除されたファイル
- **[R]** - リネームされたファイル
- **[?]** - 追跡されていないファイル
- **[C]** - コンフリクトがあるファイル

配下に変更のあるファイルを含むディレクトリには`[M]`マーカーが継承されます。
フッターには、これまでにスキャンされた全ノードを集計した統計情報
（`Files: N | Dirs: N | Modified: N | Staged: N`）が表示されます。

## 比較

### vs vpm-tree.vim

- 💪 外部のGo製CLIバイナリのビルド・インストールが不要
- ⚡ `vim.loop`によりプロセス内で完結、JSONのやり取りなし
- ✅ Neovimネイティブ：`<Plug>`マッピング、`vim.keymap.set`、Luaの`setup()`

### vs nvim-tree.lua / neo-tree.nvim

- 🔧 vpm-tree.vimのUI/UXをそのまま踏襲した、シンプルで単機能な実装
- 📝 vpm-tree.vimと同じキーバインド・ファイル操作ワークフロー

## トラブルシューティング

### Git情報が表示されない

```bash
# gitの利用可能性を確認
which git

# リポジトリのステータスを確認
cd /path/to/project
git status
```

### ツリーが開かない

```vim
" Neovimのバージョンを確認（0.9以上が必要）
:version
```

## ライセンス

MIT License

## 謝辞

nvpm-tree.nvimは[vpm-tree.vim](https://github.com/ue555/vpm-tree.vim)の
Neovim移植版です。vpm-tree.vim自体は以下からインスピレーションを得ています：

- [nvim-tree.lua](https://github.com/nvim-tree/nvim-tree.lua)
- [neo-tree.nvim](https://github.com/nvim-neo-tree/neo-tree.nvim)
- [NERDTree](https://github.com/preservim/nerdtree)

## 関連プロジェクト

- [vpm-tree.vim](https://github.com/ue555/vpm-tree.vim) - オリジナルのVim9script + Go CLI版プラグイン
- [vpm](https://github.com/ue555/vpm) - Vim Package Manager
- [nvpm](https://github.com/ue555/nvpm) - Neovim Package Manager
