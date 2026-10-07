local M = {}

---@class superfile.Config
M.defaults = {
  -- Executable to run. nil = auto-detect (`spf`, then `superfile`).
  cmd = nil,
  -- Extra CLI args passed to superfile (e.g. { "-c", "/path/to/config.toml" }).
  args = {},

  -- Replace netrw: open superfile when Neovim opens a directory buffer.
  -- (You'll want `vim.g.loaded_netrwPlugin = 1` for this.)
  open_for_directories = false,

  -- After superfile quits normally, `:cd` Neovim into the last directory it was in.
  change_neovim_cwd_on_close = false,

  -- What to do when superfile hands back a directory (e.g. `e` on a folder).
  -- "edit" = `:edit dir` (netrw/oil/etc.), "cd" = `:cd dir`, "ignore" = do nothing.
  on_directory_chosen = "edit",

  -- Keep superfile running when its window is hidden (clicking away or the
  -- `hide` key), and have `:Superfile` with no path bring it back where you
  -- left it. Off = every `:Superfile` starts fresh at the current file.
  resume = false,

  -- One key that opens/resumes superfile from normal mode and hides it (or
  -- quits it, with `resume = false`) from inside the superfile window.
  -- Use a non-printable key (e.g. "<C-g>"): a key like "-" would stop you
  -- typing that character in superfile's search and rename prompts.
  toggle_key = nil,

  -- When superfile closes, buffers whose files it deleted:
  -- "ask" = confirm before wiping, "wipe" = wipe silently, "ignore" = leave them.
  -- Buffers with unsaved changes are never wiped.
  deleted_buffers = "ask",

  -- Register(s) the copy-path keys write to.
  copy_registers = { "+", '"' },

  floating_window = {
    width = 0.9, -- <= 1 is a fraction of the editor, > 1 is columns
    height = 0.9,
    border = "rounded",
    title = " superfile ",
    title_pos = "center",
    winblend = 0,
  },

  -- Terminal-mode keymaps active inside the superfile window. Set any to false
  -- to disable it. Defaults use a <C-o> prefix to avoid superfile's own ctrl
  -- hotkeys (<C-v> paste, <C-x> cut, ...).
  keymaps = {
    open_in_vsplit = "<C-o>v",
    open_in_split = "<C-o>s",
    open_in_tab = "<C-o>t",
    grep_in_directory = "<C-o>g",
    find_in_directory = "<C-o>f",
    copy_relative_path = "<C-o>y",
    copy_absolute_path = "<C-o>Y",
    hide = "<C-o>h", -- only with `resume = true`
  },

  -- The superfile key that hands the focused item back to Neovim. It must be
  -- bound to `open_file_with_editor` in superfile (default `e`), which works on
  -- both files and directories.
  superfile_choose_key = "e",

  -- Override the picker used by grep/find. Each is fun(dir). nil = auto-detect
  -- telescope, fzf-lua, snacks, or mini.pick.
  integrations = {
    grep_in_directory = nil,
    find_in_directory = nil,
  },

  -- Called with (path, action) after an item is chosen; return true to
  -- suppress the default handling. `action` is e.g. "edit", "vsplit", "grep".
  on_file_chosen = nil,
}

---@type superfile.Config
M.options = vim.deepcopy(M.defaults)

function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), opts or {})
end

function M.executable()
  local cmd = M.options.cmd
  if cmd then
    return vim.fn.executable(cmd) == 1 and cmd or nil
  end
  for _, c in ipairs({ "spf", "superfile" }) do
    if vim.fn.executable(c) == 1 then
      return c
    end
  end
end

return M
