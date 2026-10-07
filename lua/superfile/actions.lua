-- What to do with the path superfile hands back.
local config = require("superfile.config")

local M = {}

local function notify(msg, level)
  vim.notify(msg, level or vim.log.levels.INFO, { title = "superfile.nvim" })
end
M.notify = notify

local function dir_of(path)
  return vim.fn.isdirectory(path) == 1 and path or vim.fn.fnamemodify(path, ":h")
end

local function open(path, cmd)
  if vim.fn.isdirectory(path) == 1 then
    local mode = config.options.on_directory_chosen
    if mode == "cd" then
      vim.cmd.cd(vim.fn.fnameescape(path))
      notify("cwd: " .. path)
      return
    elseif mode == "ignore" then
      return
    end
  end
  vim.cmd[cmd](vim.fn.fnameescape(path))
end

-- Picker adapters, tried in order. Each returns true if it handled the call.
local pickers = {
  function(kind, dir)
    local ok, builtin = pcall(require, "telescope.builtin")
    if not ok then
      return false
    end
    if kind == "grep" then
      builtin.live_grep({ cwd = dir, prompt_title = "Grep in " .. vim.fn.fnamemodify(dir, ":~:.") })
    else
      builtin.find_files({ cwd = dir, prompt_title = "Find in " .. vim.fn.fnamemodify(dir, ":~:.") })
    end
    return true
  end,
  function(kind, dir)
    local ok, fzf = pcall(require, "fzf-lua")
    if not ok then
      return false
    end
    if kind == "grep" then
      fzf.live_grep({ cwd = dir })
    else
      fzf.files({ cwd = dir })
    end
    return true
  end,
  function(kind, dir)
    local snacks = rawget(_G, "Snacks")
    if not (snacks and snacks.picker) then
      return false
    end
    if kind == "grep" then
      snacks.picker.grep({ dirs = { dir } })
    else
      snacks.picker.files({ cwd = dir })
    end
    return true
  end,
  function(kind, dir)
    local pick = rawget(_G, "MiniPick")
    if not pick then
      return false
    end
    if kind == "grep" then
      pick.builtin.grep_live({}, { source = { cwd = dir } })
    else
      pick.builtin.files({}, { source = { cwd = dir } })
    end
    return true
  end,
}

local function search(kind, path)
  local dir = dir_of(path)
  local custom = config.options.integrations[kind == "grep" and "grep_in_directory" or "find_in_directory"]
  if custom then
    return custom(dir)
  end
  for _, picker in ipairs(pickers) do
    if picker(kind, dir) then
      return
    end
  end
  notify("no picker found (telescope, fzf-lua, snacks, mini.pick); set `integrations`", vim.log.levels.ERROR)
end

local function copy(path, absolute)
  local text = absolute and vim.fn.fnamemodify(path, ":p") or vim.fn.fnamemodify(path, ":.")
  -- :p adds a trailing slash to directories; drop it for consistency.
  if #text > 1 then
    text = text:gsub("/$", "")
  end
  for _, reg in ipairs(config.options.copy_registers) do
    pcall(vim.fn.setreg, reg, text)
  end
  notify("copied: " .. text)
end

M.handlers = {
  edit = function(p) open(p, "edit") end,
  vsplit = function(p) open(p, "vsplit") end,
  split = function(p) open(p, "split") end,
  tabedit = function(p) open(p, "tabedit") end,
  grep = function(p) search("grep", p) end,
  find = function(p) search("find", p) end,
  copy_relative = function(p) copy(p, false) end,
  copy_absolute = function(p) copy(p, true) end,
}

--- Terminal keymap name -> action name.
M.keymap_actions = {
  open_in_vsplit = "vsplit",
  open_in_split = "split",
  open_in_tab = "tabedit",
  grep_in_directory = "grep",
  find_in_directory = "find",
  copy_relative_path = "copy_relative",
  copy_absolute_path = "copy_absolute",
}

function M.run(action, path)
  local hook = config.options.on_file_chosen
  if hook and hook(path, action) then
    return
  end
  M.handlers[action](path)
end

--- Snapshot of listed file buffers whose files exist right now.
function M.existing_file_buffers()
  local set = {}
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    if vim.bo[b].buflisted and vim.bo[b].buftype == "" then
      local name = vim.api.nvim_buf_get_name(b)
      if name ~= "" and vim.uv.fs_stat(name) then
        set[b] = name
      end
    end
  end
  return set
end

local function wipe_keeping_windows(buf)
  for _, win in ipairs(vim.fn.win_findbuf(buf)) do
    vim.api.nvim_win_call(win, function()
      local alt = vim.fn.bufnr("#")
      if alt > 0 and alt ~= buf and vim.bo[alt].buflisted then
        vim.api.nvim_win_set_buf(win, alt)
      else
        vim.cmd.enew()
      end
    end)
  end
  pcall(vim.api.nvim_buf_delete, buf, { force = true })
end

--- Deal with buffers whose files were in `before` but are gone now.
function M.handle_deleted(before)
  local mode = config.options.deleted_buffers
  if mode == "ignore" or not before then
    return
  end
  local gone, names = {}, {}
  for b, name in pairs(before) do
    if vim.api.nvim_buf_is_valid(b) and not vim.uv.fs_stat(name) and not vim.bo[b].modified then
      table.insert(gone, b)
      table.insert(names, vim.fn.fnamemodify(name, ":~:."))
    end
  end
  if #gone == 0 then
    return
  end
  if mode == "ask" then
    local msg = "superfile deleted files open in Neovim:\n  " .. table.concat(names, "\n  ") .. "\nClose those buffers?"
    if vim.fn.confirm(msg, "&Yes\n&No", 1) ~= 1 then
      return
    end
  end
  for _, b in ipairs(gone) do
    wipe_keeping_windows(b)
  end
end

return M
