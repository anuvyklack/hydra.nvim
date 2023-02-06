local class = require('hydra.lib.class')

---@class hydra.Hint
---@field hydra_name? string
---@field config hydra.hint.Config
---@field heads table<string, hydra.HeadSpec>
---@field show function
---@field close function
---@field update function | nil
---@field _debug boolean
local BaseHint = class()

function BaseHint:initialize(input)
   self.hydra_name = input.name
   self.hydra_color = input.color
   self.hint = input.hint
   self.heads = input.heads
   self.config = input.config --[[@as hydra.hint.Config]]
   self._debug = input.debug
end

function BaseHint:_get_leave_msg()
   if self.hydra_color == 'amaranth' then
      -- 'An Amaranth Hydra can only exit through a blue head'
      return {
         {'An '},
         {'Amaranth', 'HydraAmaranth'},
         {' Hydra can only exit through a blue head'}
      }
   elseif self.hydra_color == 'teal' then
      -- 'A Teal Hydra can only exit through one of its heads'
      return {
         {'A '},
         {'Teal', 'HydraTeal'},
         {' Hydra can only exit through one of its heads'}
      }
   end
end

function BaseHint:leave()
   vim.api.nvim_echo(self:_get_leave_msg(), false, {})
end

---In `self.heads` table for every head makes the next:
---
---```
---head = {              index = {
---   head = ...,           head = ...,
---   index = ...,          index = ...,
---   color = ...,   =>     color = ...,
---   desc = ...            desc = ...
---}                     }
---```
---@return table<integer, hydra.HeadSpec>
function BaseHint:_get_heads_in_sequential_form()
   local new = {}
   for _, spec in pairs(self.heads) do
      new[spec.index] = spec
   end
   return new
end

function BaseHint:debug(...)
   if self._debug then
      vim.pretty_print(...)
   end
end

---Virtual method
function BaseHint:close() end

return BaseHint
