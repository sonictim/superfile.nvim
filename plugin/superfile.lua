if vim.g.loaded_superfile then
  return
end
vim.g.loaded_superfile = true

vim.api.nvim_create_user_command("Superfile", function(cmd)
  local arg = cmd.args
  if arg == "cwd" then
    require("superfile").open_cwd()
  else
    require("superfile").open(arg ~= "" and arg or nil)
  end
end, {
  nargs = "?",
  complete = function(lead)
    local items = vim.fn.getcompletion(lead, "file")
    if ("cwd"):find(lead, 1, true) == 1 then
      table.insert(items, 1, "cwd")
    end
    return items
  end,
  desc = "Open superfile (at current file, `cwd`, or a given path)",
})
