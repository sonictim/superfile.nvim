local M = {}

function M.check()
  local health = vim.health
  health.start("superfile.nvim")

  if vim.fn.has("nvim-0.10") == 1 then
    health.ok("Neovim " .. tostring(vim.version()))
  else
    health.error("Neovim 0.10+ is required")
  end

  local exe = require("superfile.config").executable()
  if not exe then
    health.error("superfile not found on $PATH (looked for `spf` and `superfile`)")
    return
  end
  health.ok("found executable: " .. vim.fn.exepath(exe))

  local version = vim.trim(vim.fn.system({ exe, "--version" }))
  health.info(version)

  local help = vim.fn.system({ exe, "--help" })
  if help:find("chooser%-file") then
    health.ok("supports --chooser-file")
  else
    health.error("this superfile is too old: --chooser-file is required (upgrade superfile)")
  end
  if help:find("print%-last%-dir") then
    health.ok("supports --print-last-dir")
  else
    health.warn("--print-last-dir unsupported; change_neovim_cwd_on_close won't work")
  end

  local pickers = {}
  for _, mod in ipairs({ "telescope", "fzf-lua", "snacks", "mini.pick" }) do
    if pcall(require, mod) then
      table.insert(pickers, mod)
    end
  end
  if #pickers > 0 then
    health.ok("picker for grep/find in folder: " .. table.concat(pickers, ", "))
  else
    health.warn("no picker found (telescope, fzf-lua, snacks, mini.pick); <C-o>g / <C-o>f need one or `integrations`")
  end

  local opts = require("superfile.config").options
  if opts.toggle_key and #opts.toggle_key == 1 then
    health.warn(("toggle_key %q is a printable character; you won't be able to type it inside superfile"):format(opts.toggle_key))
  end
  if opts.open_for_directories and vim.g.loaded_netrwPlugin ~= 1 then
    health.warn("open_for_directories is on but netrw is still loaded; set vim.g.loaded_netrwPlugin = 1")
  end
end

return M
