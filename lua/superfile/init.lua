local config = require("superfile.config")
local window = require("superfile.window")

local M = {}

local function notify(msg, level)
  vim.notify(msg, level or vim.log.levels.INFO, { title = "superfile.nvim" })
end

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

local function open_chosen(path, open_cmd, origin_win)
  local opts = config.options
  if opts.on_file_chosen and opts.on_file_chosen(path, open_cmd) then
    return
  end

  if vim.api.nvim_win_is_valid(origin_win) then
    vim.api.nvim_set_current_win(origin_win)
  end

  if vim.fn.isdirectory(path) == 1 then
    if opts.on_directory_chosen == "cd" then
      vim.cmd.cd(vim.fn.fnameescape(path))
      notify("cwd: " .. path)
      return
    elseif opts.on_directory_chosen == "ignore" then
      return
    end
  end

  vim.cmd[open_cmd](vim.fn.fnameescape(path))
end

--- Open superfile in a floating terminal.
---@param path? string file or directory to start at (default: current file)
function M.open(path)
  local exe = config.executable()
  if not exe then
    notify("superfile executable not found (looked for `spf` and `superfile`)", vim.log.levels.ERROR)
    return
  end

  path = path and vim.fn.expand(path) or default_path()
  local origin_win = vim.api.nvim_get_current_win()
  local chooser = vim.fn.tempname()
  local state = { open_cmd = "edit" }

  local cmd = { exe, "--chooser-file", chooser }
  if config.options.change_neovim_cwd_on_close then
    table.insert(cmd, "--print-last-dir")
  end
  vim.list_extend(cmd, config.options.args)
  table.insert(cmd, path)

  local buf, win = window.open()

  local function on_exit(_, code)
    -- If the window/buffer is already gone, the user closed it on purpose and
    -- superfile was killed with SIGHUP; don't treat that as an error.
    local aborted = not vim.api.nvim_buf_is_valid(buf)
    vim.schedule(function()
      local chosen = read_chooser(chooser)
      local last_dir = not chosen and config.options.change_neovim_cwd_on_close and read_last_dir(buf)

      if vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_win_close(win, true)
      end
      if vim.api.nvim_buf_is_valid(buf) then
        vim.api.nvim_buf_delete(buf, { force = true })
      end

      -- superfile may have renamed/deleted files that are open in buffers.
      vim.cmd("silent! checktime")

      if chosen then
        open_chosen(chosen, state.open_cmd, origin_win)
      elseif last_dir and last_dir ~= vim.fn.getcwd() then
        vim.cmd.cd(vim.fn.fnameescape(last_dir))
        notify("cwd: " .. last_dir)
      elseif code ~= 0 and not aborted then
        notify("superfile exited with code " .. code, vim.log.levels.WARN)
      end
    end)
  end

  local job_opts = { on_exit = on_exit, cwd = vim.fn.getcwd() }
  local job
  if vim.fn.has("nvim-0.11") == 1 then
    job_opts.term = true
    job = vim.fn.jobstart(cmd, job_opts)
  else
    job = vim.fn.termopen(cmd, job_opts)
  end
  if job <= 0 then
    notify("failed to start superfile", vim.log.levels.ERROR)
    pcall(vim.api.nvim_win_close, win, true)
    return
  end

  local keymap_cmds = {
    open_in_vsplit = "vsplit",
    open_in_split = "split",
    open_in_tab = "tabedit",
  }
  for name, open_cmd in pairs(keymap_cmds) do
    local lhs = config.options.keymaps[name]
    if lhs then
      vim.keymap.set("t", lhs, function()
        state.open_cmd = open_cmd
        vim.api.nvim_chan_send(job, config.options.superfile_open_key)
      end, { buffer = buf, desc = "superfile: " .. name:gsub("_", " ") })
    end
  end

  vim.cmd.startinsert()
end

--- Open superfile at Neovim's cwd.
function M.open_cwd()
  M.open(vim.fn.getcwd())
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
  if config.options.open_for_directories then
    setup_directory_hijack()
  end
end

return M
