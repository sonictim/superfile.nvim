# superfile.nvim

Use [superfile](https://github.com/yorukot/superfile) as a file picker in Neovim, in the
style of [yazi.nvim](https://github.com/mikavilpas/yazi.nvim). It opens superfile in a
floating terminal at the current file, and whatever you open in superfile opens in Neovim.

## Requirements

- Neovim 0.10+
- superfile with `--chooser-file` support (`spf` or `superfile` on `$PATH`)
- Optional, for grep/find in a folder: telescope, fzf-lua, snacks.nvim, or mini.pick

## Install

### vim.pack (Neovim 0.12+)

```lua
vim.g.loaded_netrwPlugin = 1 -- only if you use open_for_directories

vim.pack.add({ "https://github.com/sonictim/superfile.nvim" })

require("superfile").setup({
  open_for_directories = true,
  resume = true,
  toggle_key = "<C-g>",
})
vim.keymap.set("n", "-", "<cmd>Superfile<cr>", { desc = "superfile (current file)" })
vim.keymap.set("n", "<leader>cw", "<cmd>Superfile cwd<cr>", { desc = "superfile (cwd)" })
```

For a local checkout, use `vim.opt.rtp:prepend(vim.fn.expand("~/Projects/superfile.nvim"))` in place of
`vim.pack.add`.

### lazy.nvim

```lua
{
  "sonictim/superfile.nvim",
  cmd = "Superfile",
  keys = {
    { "-", "<cmd>Superfile<cr>", desc = "superfile (current file)" },
    { "<leader>cw", "<cmd>Superfile cwd<cr>", desc = "superfile (cwd)" },
  },
  opts = {},
}
```

If you use `open_for_directories`, set `lazy = false` and put `vim.g.loaded_netrwPlugin = 1`
in `init`.

## Usage

| Command | |
|---|---|
| `:Superfile` | open at the current file (cursor lands on it); resumes a hidden one if `resume = true` |
| `:Superfile toggle` | show or hide superfile, keeping its place |
| `:Superfile cwd` | open at Neovim's cwd |
| `:Superfile {path}` | open at a path (always starts fresh) |

Inside superfile:

| Key | Action |
|---|---|
| `Enter` / `l` / `e` on a file | open it in Neovim (`:edit`) |
| `<C-o>v` | open in a vertical split |
| `<C-o>s` | open in a horizontal split |
| `<C-o>t` | open in a new tab |
| `<C-o>g` | live grep in the focused folder (or the folder containing the focused file) |
| `<C-o>f` | find files in that folder |
| `<C-o>y` | copy the path, relative to Neovim's cwd |
| `<C-o>Y` | copy the absolute path |
| `<C-o>h` | hide (only with `resume = true`) |
| `toggle_key` | hide, or quit if `resume = false` |
| `q` | quit |

The `<C-o>` keys work on folders as well as files. They send superfile's `e` key
(`open_file_with_editor`), which hands back whatever is focused. Enter on a folder only
goes into it. The keys use a `<C-o>` prefix because superfile already uses most single
ctrl keys (`<C-v>` paste, `<C-x>` cut, `<C-s>`, …).

### Grep and find in a folder

Use superfile to get to the right part of a project, then search only there. Press
`<C-o>g` on `src/audio/` and Telescope's live grep opens limited to that folder. Press it
on a file and it searches the folder that file is in. `<C-o>f` does the same for finding
files by name.

### Resume

By default every `:Superfile` starts fresh, and clicking another window quits superfile.
With `resume = true`, clicking away or pressing `<C-o>h` hides superfile instead, and
the next `:Superfile` brings it back where you left it. `:Superfile {path}` always starts
fresh.

`toggle_key` is a single key for both directions. In normal mode it opens or resumes
superfile, and inside superfile it hides it. Pick a non-printable key such as `<C-g>`. A
key like `-` would take over that character inside superfile, so you couldn't type it in
search or rename.

### After superfile closes

- **Changed files:** buffers are re-checked (`:checktime`), so changes superfile made on
  disk show up.
- **Deleted files:** buffers for files superfile deleted are closed (asks first by
  default; see `deleted_buffers`). Buffers with unsaved changes are never closed.

## Configuration (defaults)

```lua
require("superfile").setup({
  cmd = nil,                          -- auto: `spf`, then `superfile`
  args = {},                          -- extra CLI args, e.g. { "-c", "~/alt-config.toml" }
  open_for_directories = false,       -- hijack directory buffers (disable netrw yourself)
  change_neovim_cwd_on_close = false, -- :cd to superfile's last dir when you quit with q
  on_directory_chosen = "edit",       -- "edit" | "cd" | "ignore"
  resume = false,                     -- hide instead of quit; :Superfile resumes
  toggle_key = nil,                   -- e.g. "<C-g>": open/resume (normal) + hide (inside)
  deleted_buffers = "ask",            -- "ask" | "wipe" | "ignore"
  copy_registers = { "+", '"' },      -- where the copy-path keys write
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
    grep_in_directory = "<C-o>g",
    find_in_directory = "<C-o>f",
    copy_relative_path = "<C-o>y",
    copy_absolute_path = "<C-o>Y",
    hide = "<C-o>h",                  -- only with resume = true
  },
  superfile_choose_key = "e",         -- superfile key bound to open_file_with_editor
  integrations = {                    -- fun(dir) overrides; nil = auto-detect picker
    grep_in_directory = nil,
    find_in_directory = nil,
  },
  on_file_chosen = nil,               -- fun(path, action): boolean  (true = handled)
})
```

Lua API: `require("superfile").open(path?)`, `.open_cwd()`, `.toggle()`, `.stop()`.

Run `:checkhealth superfile` to check your setup.

## How it works

superfile runs with `--chooser-file <tmp>`. When you open an item, superfile writes its
path to that file and exits, and the plugin acts on it. The `<C-o>` keys are Neovim
terminal mappings that record which action you want, then send superfile its `e` key.
With `change_neovim_cwd_on_close`, the plugin also passes `--print-last-dir` and reads the
directory from the last line of the terminal output.

## Limitations

- **One item at a time:** superfile's chooser only returns the focused item, not a
  multi-selection.
- **No live sync:** renames in superfile don't update open buffers. Buffers are only
  refreshed when superfile closes. superfile has no event API (yazi has one), so this
  would need changes to superfile itself.

## License

MIT
