local config = require("superfile.config")

local M = {}

local function dim(value, total)
  if value <= 1 then
    return math.max(1, math.floor(total * value))
  end
  return math.min(value, total)
end

local function geometry()
  local opts = config.options.floating_window
  local cols = vim.o.columns
  local lines = vim.o.lines - vim.o.cmdheight
  local width = dim(opts.width, cols - 2)
  local height = dim(opts.height, lines - 2)
  return {
    relative = "editor",
    width = width,
    height = height,
    col = math.floor((cols - width) / 2),
    row = math.floor((lines - height) / 2),
  }
end

--- Open a floating window on a fresh scratch buffer.
---@return integer buf, integer win
function M.open()
  local opts = config.options.floating_window
  local buf = vim.api.nvim_create_buf(false, true)
  local win_opts = vim.tbl_extend("force", geometry(), {
    style = "minimal",
    border = opts.border,
    title = opts.title,
    title_pos = opts.title and opts.title_pos or nil,
  })
  local win = vim.api.nvim_open_win(buf, true, win_opts)
  vim.wo[win].winblend = opts.winblend
  vim.wo[win].winhighlight = "NormalFloat:Normal"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].filetype = "superfile"

  local group = vim.api.nvim_create_augroup("superfile_window_" .. buf, { clear = true })
  vim.api.nvim_create_autocmd("VimResized", {
    group = group,
    callback = function()
      if vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_win_set_config(win, geometry())
      end
    end,
  })
  vim.api.nvim_create_autocmd("BufWipeout", {
    group = group,
    buffer = buf,
    once = true,
    callback = function()
      pcall(vim.api.nvim_del_augroup_by_id, group)
    end,
  })
  -- Keep focus in the float: if the user wanders off, close it.
  vim.api.nvim_create_autocmd("WinLeave", {
    group = group,
    buffer = buf,
    callback = function()
      vim.schedule(function()
        if vim.api.nvim_win_is_valid(win) then
          vim.api.nvim_win_close(win, true)
        end
      end)
    end,
  })

  return buf, win
end

return M
