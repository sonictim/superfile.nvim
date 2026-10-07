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

## Commands

| Command | What it does |
|---|---|
| `:Superfile` | Open at the current file, with the cursor on it. With `resume = true`, brings back a hidden superfile instead. |
| `:Superfile toggle` | Show superfile if hidden, hide it if showing; open a new one if none is running. |
| `:Superfile cwd` | Open at Neovim's current working directory. |
| `:Superfile {path}` | Open at a file or folder. Always starts a fresh superfile. |
| `:checkhealth superfile` | Check the superfile version, flags, available pickers, and config. |

Opening a folder (`nvim .`, `:e src/`) also opens superfile when `open_for_directories = true`.

## Keys inside superfile

These are added on top of superfile's own hotkeys.

### Action keys: press `<C-o>`, then a key

After `<C-o>`, a hint line lists the choices, and the plugin waits for your next key with no
timeout, so a short `timeoutlen` doesn't matter.

| Keys | Action |
|---|---|
| `<C-o>` `v` | Open in a vertical split |
| `<C-o>` `s` | Open in a horizontal split |
| `<C-o>` `t` | Open in a new tab |
| `<C-o>` `g` | Live grep in the focused folder (or the folder containing the focused file) |
| `<C-o>` `f` | Find files in that folder |
| `<C-o>` `y` | Copy the path, relative to Neovim's cwd |
| `<C-o>` `Y` | Copy the absolute path |
| `<C-o>` `h` | Hide superfile, keeping its place (only with `resume = true`) |
| `<C-o>` `Esc` | Cancel |
| `<C-o>` any other key | Send that key to superfile as-is (how you type a character taken by `direct_keymaps`, e.g. `<C-o>-` types `-`) |

The second keys, and the prefix itself, can be changed under `keymaps`.

### Other keys

| Key | Action |
|---|---|
| `Enter` / `l` / `e` on a file | Open it in Neovim (`:edit`) — superfile's own keys |
| `q` | Quit superfile — superfile's own key |
| `toggle_key` (e.g. `<C-g>`) | Hide superfile (or quit it if `resume = false`) |
| `direct_keymaps` (e.g. `\`, `-`) | Any action above on a single key, no prefix |

All action keys work on folders as well as files. They send superfile's `e` key
(`open_file_with_editor`), which hands back whatever is focused. Enter on a folder only
goes into it.

## Features

### Grep and find in a folder

Use superfile to get to the right part of a project, then search only there. `<C-o>g` on
`src/audio/` opens a live grep limited to that folder. On a file, it searches the folder
that file is in. `<C-o>f` does the same for finding files by name. The plugin uses
telescope, fzf-lua, snacks, or mini.pick, whichever it finds first, or your own function
via `integrations`.

### Resume

By default every `:Superfile` starts fresh, and clicking another window quits superfile.
With `resume = true`, clicking away or pressing `<C-o>h` hides superfile instead, and
the next `:Superfile` brings it back exactly as you left it, including superfile's own
copy/cut clipboard. `:Superfile {path}` always starts fresh.

### Toggle key

`toggle_key` is one key for both directions. In normal mode it opens or resumes
superfile, and inside superfile it hides it. Pick a non-printable key such as `<C-g>`: a
printable key would take over that character inside superfile.

### Direct keys

`direct_keymaps` puts any action on a single key with no prefix. For example, to use the
same keys as your split mappings:

```lua
direct_keymaps = {
  open_in_vsplit = "\\",
  open_in_split = "-",
},
```

A printable key there can't be typed directly in superfile's search or rename prompts.
Type `<C-o>` first to send it literally (`<C-o>-` types `-`).

### After superfile closes

- **Changed files:** buffers are re-checked (`:checktime`), so changes superfile made on
  disk show up.
- **Deleted files:** buffers for files superfile deleted are closed (asks first by
  default; see `deleted_buffers`). Buffers with unsaved changes are never closed.
- **Working directory:** with `change_neovim_cwd_on_close = true`, quitting with `q`
  changes Neovim's cwd to superfile's last folder.

## Configuration

All options with their defaults:

```lua
require("superfile").setup({
  -- superfile executable; nil = auto-detect `spf`, then `superfile`
  cmd = nil,
  -- extra CLI args for superfile, e.g. { "-c", "~/alt-config.toml" }
  args = {},

  -- open superfile when Neovim opens a folder (set vim.g.loaded_netrwPlugin = 1 too)
  open_for_directories = false,
  -- after quitting with q, :cd Neovim to superfile's last folder
  change_neovim_cwd_on_close = false,
  -- when an action returns a folder: "edit" (:edit it), "cd", or "ignore"
  on_directory_chosen = "edit",

  -- hide instead of quit; :Superfile brings it back where you left it
  resume = false,
  -- one key: open/resume in normal mode, hide inside superfile (e.g. "<C-g>")
  toggle_key = nil,

  -- buffers for files superfile deleted: "ask", "wipe", or "ignore"
  deleted_buffers = "ask",
  -- registers the copy-path keys write to
  copy_registers = { "+", '"' },

  floating_window = {
    width = 0.9,        -- <= 1 is a fraction of the editor, > 1 is columns
    height = 0.9,
    border = "rounded",
    title = " superfile ",
    title_pos = "center",
    winblend = 0,
  },

  -- press `prefix`, then one of these keys; set any to false to disable it.
  -- prefix = false maps each key directly instead (use full notation, e.g. "<M-v>")
  keymaps = {
    prefix = "<C-o>",
    open_in_vsplit = "v",
    open_in_split = "s",
    open_in_tab = "t",
    grep_in_directory = "g",
    find_in_directory = "f",
    copy_relative_path = "y",
    copy_absolute_path = "Y",
    hide = "h",         -- only with resume = true
  },

  -- extra single keys, no prefix; same action names as `keymaps`
  direct_keymaps = {},

  -- superfile key bound to open_file_with_editor (hands back the focused item)
  superfile_choose_key = "e",

  -- your own grep/find, as fun(dir); nil = auto-detect a picker
  integrations = {
    grep_in_directory = nil,
    find_in_directory = nil,
  },

  -- fun(path, action): return true to handle a chosen item yourself.
  -- action is "edit", "vsplit", "split", "tabedit", "grep", "find",
  -- "copy_relative", or "copy_absolute"
  on_file_chosen = nil,
})
```

## Lua API

| Function | What it does |
|---|---|
| `require("superfile").setup(opts)` | Apply options (see above) |
| `require("superfile").open(path?)` | Same as `:Superfile [path]` |
| `require("superfile").open_cwd()` | Same as `:Superfile cwd` |
| `require("superfile").toggle()` | Same as `:Superfile toggle` |
| `require("superfile").stop()` | Stop superfile, hidden or not |

## How it works

superfile runs with `--chooser-file <tmp>`. When you open an item, superfile writes its
path to that file and exits, and the plugin acts on it. The action keys are Neovim
terminal mappings that record which action you want, then send superfile its `e` key.
With `change_neovim_cwd_on_close`, the plugin also passes `--print-last-dir` and reads the
folder from the last line of the terminal output.

## Limitations

- **One item at a time:** superfile's chooser only returns the focused item, not a
  multi-selection.
- **No live sync:** renames in superfile don't update open buffers. Buffers are only
  refreshed when superfile closes. superfile has no event API (yazi has one), so this
  would need changes to superfile itself.

## License

MIT
