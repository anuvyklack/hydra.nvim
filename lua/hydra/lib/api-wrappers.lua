local class = require('hydra.lib.class')
local api = vim.api
local M = {}

--------------------------------------------------------------------------------

---@class hydra.api.Window
---@field id integer
---@field _original_options? table<string, any>
---@field wo table window options meta-accessor
local Window = class()

---@param winid? integer If absent or 0 - the current window ID will be used.
function Window:initialize(winid)
   self.id = (not winid or winid == 0) and api.nvim_get_current_win() or winid

   self.wo = setmetatable({}, {
      __index = function(_, opt)
         return api.nvim_win_get_option(self.id, opt)
      end,
      __newindex = function(_, opt, value)
         api.nvim_win_set_option(self.id, opt, value)
      end
   })
end

---@return boolean
function Window:is_valid()
   return api.nvim_win_is_valid(self.id)
end

---@param buffer hydra.api.Buffer
function Window:set_buffer(buffer)
   api.nvim_win_set_buf(self.id, buffer.id)
end

---@param name string
function Window:set_option(name, value)
   return api.nvim_win_set_option(self.id, name, value)
end

---@param force? boolean
function Window:close(force)
   api.nvim_win_close(self.id, force or false)
end

---Set float window config
---@param config table
function Window:set_config(config)
   api.nvim_win_set_config(self.id, config)
end

--------------------------------------------------------------------------------

---@class hydra.api.Buffer
---@field id integer
---@field bo table buffer options meta-accessor
local Buffer = class()

function Buffer:initialize(bufnr)
   self.id = bufnr

   self.bo = setmetatable({}, {
      __index = function(_, opt)
         return api.nvim_buf_get_option(self.id, opt)
      end,
      __newindex = function(_, opt, value)
         api.nvim_buf_set_option(self.id, opt, value)
      end
   })
end

---@return boolean
function Buffer:is_loaded()
   return api.nvim_buf_is_loaded(self.id)
end

---@param name string
function Buffer:set_option(name, value)
   return api.nvim_buf_set_option(self.id, name, value)
end

---Returns the number of lines in the given buffer.
---@return integer
function Buffer:line_count()
   return api.nvim_buf_line_count(self.id)
end

---@param start integer First line index
---@param end_ integer Last line index, exclusive.
---@param lines string[] Array of lines to set.
---@param strict_indexing? boolean Whether out-of-bounds should be an error.
function Buffer:set_lines(start, end_, lines, strict_indexing)
   api.nvim_buf_set_lines(self.id, start, end_, strict_indexing or false, lines)
end

---@param ns_id integer Namespace to use or -1 for ungrouped highlight.
---@param hl_group string Name of the highlight group to use.
---@param line integer Line to highlight (zero-indexed).
---@param col_start integer Start of (byte-indexed) column range to highlight.
---@param col_end integer End of (byte-indexed) column range to highlight, or -1 to highlight to end of line.
function Buffer:add_highlight(ns_id, hl_group, line, col_start, col_end)
   api.nvim_buf_add_highlight(self.id, ns_id, hl_group, line, col_start, col_end)
end

---@param opts? table
function Buffer:delete(opts)
   local opts = opts or {}
   api.nvim_buf_delete(self.id, opts)
end

--------------------------------------------------------------------------------
M.Window = Window
M.Buffer = Buffer

return M



