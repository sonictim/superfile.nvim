local config = require("superfile.config")

local M = {}

local function dim(value, total)
  if value <= 1 then
    return math.max(1, math.floor(total * value))
  end
  return math.min(value, total)
end

local function geometry()
  local cols = vim.o.columns
  local lines = vim.o.lines - vim.o.cmdheight
  local opts = config.options.floating_window
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

--- A scratch buffer for the terminal. It survives being hidden so superfile
--- can be resumed.
---@return integer buf
function M.create_buf()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = "hide"
  vim.bo[buf].filetype = "superfile"
  return buf
end

--- Show `buf` in a centered float.
---@param buf integer
---@param on_leave fun() called when focus leaves the float
---@return integer win
function M.show(buf, on_leave)
  local opts = config.options.floating_window
  local win = vim.api.nvim_open_win(buf, true, vim.tbl_extend("force", geometry(), {
    style = "minimal",
    border = opts.border,
    title = opts.title,
    title_pos = opts.title and opts.title_pos or nil,
  }))
  vim.wo[win].winblend = opts.winblend
  vim.wo[win].winhighlight = "NormalFloat:Normal"

  local group = vim.api.nvim_create_augroup("superfile_window_" .. win, { clear = true })
  vim.api.nvim_create_autocmd("VimResized", {
    group = group,
    callback = function()
      if vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_win_set_config(win, geometry())
      end
    end,
  })
  vim.api.nvim_create_autocmd("WinLeave", {
    group = group,
    buffer = buf,
    callback = function()
      if vim.api.nvim_get_current_win() == win then
        vim.schedule(on_leave)
      end
    end,
  })
  vim.api.nvim_create_autocmd("WinClosed", {
    group = group,
    pattern = tostring(win),
    once = true,
    callback = function()
      pcall(vim.api.nvim_del_augroup_by_id, group)
    end,
  })

  return win
end

return M
