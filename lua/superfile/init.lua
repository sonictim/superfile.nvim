local config = require("superfile.config")
local window = require("superfile.window")
local actions = require("superfile.actions")

local notify = actions.notify

local M = {}

---@class superfile.Instance
---@field job integer
---@field buf integer
---@field win? integer       nil while hidden
---@field chooser string
---@field action string      what to do with the chosen path
---@field origin_win integer window to return to
---@field files_before table<integer, string>

---@type superfile.Instance?
local current

--- The path superfile should start at: the current file (so it gets focused),
--- or the cwd for unnamed/special buffers.
local function default_path()
  local name = vim.api.nvim_buf_get_name(0)
  if name ~= "" and vim.bo.buftype == "" and vim.uv.fs_stat(name) then
    return name
  end
  return vim.fn.getcwd()
end

--- `--print-last-dir` writes the directory to stdout after the TUI exits, so
--- it ends up as one of the last lines in the terminal buffer.
local function read_last_dir(buf)
  if not vim.api.nvim_buf_is_valid(buf) then
    return nil
  end
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  for i = #lines, 1, -1 do
    local line = vim.trim(lines[i])
    if line ~= "" and not line:match("^%[Process exited") and vim.fn.isdirectory(line) == 1 then
      return line
    end
  end
end

local function read_chooser(path)
  local f = io.open(path, "r")
  if not f then
    return nil
  end
  local content = vim.trim(f:read("*a") or "")
  f:close()
  os.remove(path)
  return content ~= "" and content or nil
end

local function alive(inst)
  return inst and vim.api.nvim_buf_is_valid(inst.buf) and vim.fn.jobwait({ inst.job }, 0)[1] == -1
end

--- Close the float but keep superfile running so it can be resumed.
---@param restore_focus boolean go back to the window superfile was opened from
local function hide(inst, restore_focus)
  if not (inst.win and vim.api.nvim_win_is_valid(inst.win)) then
    return
  end
  vim.api.nvim_win_close(inst.win, true)
  inst.win = nil
  if restore_focus and vim.api.nvim_win_is_valid(inst.origin_win) then
    vim.api.nvim_set_current_win(inst.origin_win)
  end
end

local function kill(inst)
  if inst.win and vim.api.nvim_win_is_valid(inst.win) then
    vim.api.nvim_win_close(inst.win, true)
  end
  pcall(vim.fn.jobstop, inst.job)
  if vim.api.nvim_buf_is_valid(inst.buf) then
    vim.api.nvim_buf_delete(inst.buf, { force = true })
  end
  os.remove(inst.chooser)
end

local function show(inst)
  inst.origin_win = vim.api.nvim_get_current_win()
  inst.files_before = actions.existing_file_buffers()
  inst.action = "edit"
  -- Clicking/jumping to another window: hide (resume mode) or quit superfile.
  inst.win = window.show(inst.buf, function()
    if not (inst.win and vim.api.nvim_win_is_valid(inst.win)) then
      return
    end
    if config.options.resume then
      hide(inst, false)
    else
      kill(inst)
      if current == inst then
        current = nil
      end
    end
  end)
  vim.cmd.startinsert()
end

local function close_or_hide(inst)
  if config.options.resume then
    hide(inst, true)
  else
    kill(inst)
    if current == inst then
      current = nil
    end
  end
end

-- Display order for the prefix hint.
local hint_order = {
  { "open_in_vsplit", "vsplit" },
  { "open_in_split", "split" },
  { "open_in_tab", "tab" },
  { "grep_in_directory", "grep" },
  { "find_in_directory", "find" },
  { "copy_relative_path", "copy path" },
  { "copy_absolute_path", "copy abs path" },
  { "hide", "hide" },
}

local function set_keymaps(inst)
  local km = config.options.keymaps
  local opts = function(desc)
    return { buffer = inst.buf, desc = "superfile: " .. desc }
  end

  -- name -> function, for every enabled action key
  local handlers = {}
  for name, action in pairs(actions.keymap_actions) do
    handlers[name] = function()
      inst.action = action
      vim.api.nvim_chan_send(inst.job, config.options.superfile_choose_key)
    end
  end
  if config.options.resume then
    handlers.hide = function()
      hide(inst, true)
    end
  end

  if km.prefix then
    -- Press the prefix, then one key. The second key is read directly with
    -- getcharstr(), so it doesn't depend on 'timeoutlen'.
    local by_key = {}
    local hint = { { "superfile: ", "Title" } }
    for _, item in ipairs(hint_order) do
      local name, label = item[1], item[2]
      local key = km[name]
      if key and handlers[name] then
        by_key[key] = handlers[name]
        table.insert(hint, { key, "Special" })
        table.insert(hint, { " " .. label .. "  ", "Normal" })
      end
    end
    table.insert(hint, { "esc", "Special" })
    table.insert(hint, { " cancel", "Normal" })

    vim.keymap.set("t", km.prefix, function()
      vim.api.nvim_echo(hint, false, {})
      vim.cmd.redraw()
      local ok, key = pcall(vim.fn.getcharstr)
      vim.api.nvim_echo({ { "" } }, false, {})
      if not ok or key == vim.keycode("<Esc>") then
        return
      end
      local handler = by_key[key]
      if handler then
        -- Run after this mapping returns: closing the terminal window from
        -- inside it (e.g. hide) can crash Neovim.
        vim.schedule(handler)
      else
        -- Not one of ours: send the key as-is. This is also how you type a
        -- character that's taken by `direct_keymaps` (e.g. <C-o>- types "-").
        vim.api.nvim_chan_send(inst.job, key)
      end
    end, opts("actions"))
  else
    -- No prefix: each action key is its own terminal mapping.
    for name, handler in pairs(handlers) do
      if km[name] then
        vim.keymap.set("t", km[name], handler, opts(name:gsub("_", " ")))
      end
    end
  end

  for name, lhs in pairs(config.options.direct_keymaps) do
    if lhs and handlers[name] then
      vim.keymap.set("t", lhs, handlers[name], opts(name:gsub("_", " ")))
    end
  end

  local toggle_key = config.options.toggle_key
  if toggle_key then
    vim.keymap.set("t", toggle_key, function()
      close_or_hide(inst)
    end, opts("toggle"))
  end
end

local function start(path)
  local exe = config.executable()
  if not exe then
    notify("superfile executable not found (looked for `spf` and `superfile`)", vim.log.levels.ERROR)
    return
  end

  ---@type superfile.Instance
  local inst = {
    buf = window.create_buf(),
    chooser = vim.fn.tempname(),
    action = "edit",
    origin_win = vim.api.nvim_get_current_win(),
    job = 0,
    files_before = {},
  }

  local cmd = { exe, "--chooser-file", inst.chooser }
  if config.options.change_neovim_cwd_on_close then
    table.insert(cmd, "--print-last-dir")
  end
  vim.list_extend(cmd, config.options.args)
  table.insert(cmd, path)

  local function on_exit(_, code)
    -- If the buffer is already gone, superfile was stopped on purpose.
    local aborted = not vim.api.nvim_buf_is_valid(inst.buf)
    vim.schedule(function()
      if current == inst then
        current = nil
      end
      local chosen = read_chooser(inst.chooser)
      local last_dir = not chosen and config.options.change_neovim_cwd_on_close and read_last_dir(inst.buf)

      local win = inst.win
      inst.win = nil -- so the WinLeave hide handler is a no-op
      if win and vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_win_close(win, true)
      end
      if vim.api.nvim_buf_is_valid(inst.buf) then
        vim.api.nvim_buf_delete(inst.buf, { force = true })
      end
      if aborted then
        return
      end
      if vim.api.nvim_win_is_valid(inst.origin_win) then
        vim.api.nvim_set_current_win(inst.origin_win)
      end

      -- superfile may have changed files that are open in buffers.
      vim.cmd("silent! checktime")
      actions.handle_deleted(inst.files_before)

      if chosen then
        actions.run(inst.action, chosen)
      elseif last_dir and last_dir ~= vim.fn.getcwd() then
        vim.cmd.cd(vim.fn.fnameescape(last_dir))
        notify("cwd: " .. last_dir)
      elseif code ~= 0 then
        notify("superfile exited with code " .. code, vim.log.levels.WARN)
      end
    end)
  end

  -- Start the job inside the new buffer before showing it, so the terminal
  -- is sized by the float.
  show(inst)
  local job_opts = { on_exit = on_exit, cwd = vim.fn.getcwd() }
  if vim.fn.has("nvim-0.11") == 1 then
    job_opts.term = true
    inst.job = vim.fn.jobstart(cmd, job_opts)
  else
    inst.job = vim.fn.termopen(cmd, job_opts)
  end
  if inst.job <= 0 then
    notify("failed to start superfile", vim.log.levels.ERROR)
    kill(inst)
    return
  end

  set_keymaps(inst)
  current = inst
end

--- Open superfile in a floating terminal. With `resume` on and no `path`,
--- brings back the hidden instance if there is one.
---@param path? string file or directory to start at (default: current file)
function M.open(path)
  if not path and config.options.resume and alive(current) then
    if not (current.win and vim.api.nvim_win_is_valid(current.win)) then
      show(current)
    end
    return
  end
  if current then
    kill(current)
    current = nil
  end
  start(path and vim.fn.expand(path) or default_path())
end

--- Open superfile at Neovim's cwd.
function M.open_cwd()
  M.open(vim.fn.getcwd())
end

--- Resume the hidden superfile where you left it, or open a new one.
--- If it's currently showing, hide it.
function M.toggle()
  if alive(current) then
    if current.win and vim.api.nvim_win_is_valid(current.win) then
      hide(current, true)
    else
      show(current)
    end
  else
    M.open()
  end
end

local function setup_directory_hijack()
  local group = vim.api.nvim_create_augroup("superfile_hijack_netrw", { clear = true })
  vim.api.nvim_create_autocmd("BufEnter", {
    group = group,
    nested = true,
    callback = function(ev)
      local name = vim.api.nvim_buf_get_name(ev.buf)
      if name == "" or vim.bo[ev.buf].buftype ~= "" or vim.fn.isdirectory(name) == 0 then
        return
      end
      -- Swap the directory buffer for something harmless, then launch.
      local alt = vim.fn.bufnr("#")
      if alt > 0 and alt ~= ev.buf and vim.api.nvim_buf_is_valid(alt) then
        vim.api.nvim_win_set_buf(0, alt)
      else
        vim.cmd.enew()
      end
      pcall(vim.api.nvim_buf_delete, ev.buf, { force = true })
      vim.schedule(function()
        M.open(name)
      end)
    end,
  })
end

function M.setup(opts)
  config.setup(opts)
  if config.options.toggle_key then
    vim.keymap.set("n", config.options.toggle_key, M.toggle, { desc = "superfile: toggle" })
  end
  if config.options.open_for_directories then
    setup_directory_hijack()
  end
end

--- Stop any running superfile, hidden or not.
function M.stop()
  if current then
    kill(current)
    current = nil
  end
end

return M
