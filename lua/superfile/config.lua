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

  -- What to do when superfile hands back a directory (e.g. via the "open
  -- directory with editor" key). "edit" = `:edit dir` (netrw/oil/etc.),
  -- "cd" = `:cd dir`, "ignore" = do nothing.
  on_directory_chosen = "edit",

  floating_window = {
    width = 0.9, -- <= 1 is a fraction of the editor, > 1 is columns
    height = 0.9,
    border = "rounded",
    title = " superfile ",
    title_pos = "center",
    winblend = 0,
  },

  -- Terminal-mode keymaps active inside the superfile window. Each one opens
  -- the file under the cursor with the given command. Set a key to false to
  -- disable it. Defaults avoid superfile's own ctrl hotkeys.
  keymaps = {
    open_in_vsplit = "<C-o>v",
    open_in_split = "<C-o>s",
    open_in_tab = "<C-o>t",
  },

  -- The key superfile uses to open the focused item (sent after a keymap
  -- above picks the open mode).
  superfile_open_key = "\r",

  -- Called with (path, open_cmd) after a file is chosen; return true to
  -- suppress the default open.
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
