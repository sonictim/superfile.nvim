# superfile.nvim

Use [superfile](https://github.com/yorukot/superfile) as a file picker in Neovim, in the
style of [yazi.nvim](https://github.com/mikavilpas/yazi.nvim). It opens superfile in a
floating terminal at the current file, and whatever you open in superfile opens in Neovim.

## Requirements

- Neovim 0.10+
- superfile with `--chooser-file` support (`spf` or `superfile` on `$PATH`)

## Install

### vim.pack (Neovim 0.12+)

```lua
vim.pack.add({ "https://github.com/you/superfile.nvim" })

require("superfile").setup({})
vim.keymap.set("n", "<leader>-", "<cmd>Superfile<cr>", { desc = "superfile (current file)" })
vim.keymap.set("n", "<leader>cw", "<cmd>Superfile cwd<cr>", { desc = "superfile (cwd)" })
```

For a local checkout, use `vim.opt.rtp:prepend(vim.fn.expand("~/Projects/superfile.nvim"))` in place of
`vim.pack.add`.

To replace netrw, set `vim.g.loaded_netrwPlugin = 1` before plugins load and pass
`open_for_directories = true` to `setup()`.

### lazy.nvim

```lua
{
  "you/superfile.nvim", -- or dir = "~/Projects/superfile.nvim"
  cmd = "Superfile",
  keys = {
    { "<leader>-", "<cmd>Superfile<cr>", desc = "superfile (current file)" },
    { "<leader>cw", "<cmd>Superfile cwd<cr>", desc = "superfile (cwd)" },
  },
  opts = {},
}
```

To replace netrw (open superfile when you `:edit` a directory or run `nvim .`), drop
`cmd`/`keys` lazy-loading, set `lazy = false`, and:

```lua
init = function() vim.g.loaded_netrwPlugin = 1 end,
opts = { open_for_directories = true },
```

## Usage

| Command | |
|---|---|
| `:Superfile` | open at the current file (cursor lands on it) |
| `:Superfile cwd` | open at Neovim's cwd |
| `:Superfile {path}` | open at a path |

Inside superfile:

| Key | Action |
|---|---|
| `Enter` / `l` / `e` on a file | open it in Neovim (`:edit`) |
| `<C-o>v` | open in a vertical split |
| `<C-o>s` | open in a horizontal split |
| `<C-o>t` | open in a new tab |
| `q` | quit (optionally `:cd` to the last directory) |

The split/tab keys use a `<C-o>` prefix because superfile already uses most single
ctrl keys (`<C-v>` paste, `<C-x>` cut, `<C-s>`, …).

After superfile closes, buffers are re-checked (`:checktime`) so renames and deletes
show up.

## Configuration (defaults)

```lua
require("superfile").setup({
  cmd = nil,                          -- auto: `spf`, then `superfile`
  args = {},                          -- extra CLI args, e.g. { "-c", "~/alt-config.toml" }
  open_for_directories = false,       -- hijack directory buffers (disable netrw yourself)
  change_neovim_cwd_on_close = false, -- :cd to superfile's last dir when you quit with q
  on_directory_chosen = "edit",       -- "edit" | "cd" | "ignore"
  floating_window = {
    width = 0.9, height = 0.9,        -- <= 1 fraction, > 1 absolute
    border = "rounded",
    title = " superfile ",
    title_pos = "center",
    winblend = 0,
  },
  keymaps = {                         -- set any to false to disable
    open_in_vsplit = "<C-o>v",
    open_in_split = "<C-o>s",
    open_in_tab = "<C-o>t",
  },
  superfile_open_key = "\r",          -- key sent to superfile to open after a keymap above
  on_file_chosen = nil,               -- fun(path, open_cmd): boolean  (true = handled)
})
```

Lua API: `require("superfile").open(path?)`, `require("superfile").open_cwd()`.

Run `:checkhealth superfile` to check your setup.

## How it works

superfile runs with `--chooser-file <tmp>`. When you open a file, superfile writes the
path to that file and exits, and the plugin opens it. With `change_neovim_cwd_on_close`, it
also passes `--print-last-dir` and reads the directory from the last line of the terminal
output.

## Limitations

- Opens one file at a time. superfile's chooser only returns the focused item, not a
  multi-selection.
- No live sync while superfile is open. Buffers are refreshed when it closes.
