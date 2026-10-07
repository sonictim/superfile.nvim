if vim.g.loaded_superfile then
  return
end
vim.g.loaded_superfile = true

vim.api.nvim_create_user_command("Superfile", function(cmd)
  local arg = cmd.args
  local sf = require("superfile")
  if arg == "cwd" then
    sf.open_cwd()
  elseif arg == "toggle" then
    sf.toggle()
  else
    sf.open(arg ~= "" and arg or nil)
  end
end, {
  nargs = "?",
  complete = function(lead)
    local items = vim.fn.getcompletion(lead, "file")
    for _, sub in ipairs({ "toggle", "cwd" }) do
      if sub:find(lead, 1, true) == 1 then
        table.insert(items, 1, sub)
      end
    end
    return items
  end,
  desc = "Open superfile (at current file, `cwd`, `toggle`, or a given path)",
})

vim.api.nvim_create_autocmd("ExitPre", {
  group = vim.api.nvim_create_augroup("superfile_exit", { clear = true }),
  callback = function()
    if package.loaded.superfile then
      require("superfile").stop()
    end
  end,
})
