local Class = require('hydra.class')

---@class hydra.Hint
---@field hydra_name? string
---@field config hydra.hint.Config
---@field heads table<string, hydra.HeadSpec>
---@field show function
---@field close function
---@field update function | nil
---@field _debug boolean
local Hint = Class()

---@param hydra Hydra
function Hint:_constructor(hydra)
   self.hydra_name = hydra.name
   self.heads = hydra.heads_spec
   if hydra.config.hint then
      self.config = hydra.config.hint --[[@as hydra.hint.Config]]
   end

   self._debug = hydra.config.debug
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
function Hint:_swap_head_with_index()
   local new = {}
   for _, properties in pairs(self.heads) do
      new[properties.index] = properties
   end
   return new
end

function Hint:debug(...)
   if self._debug then
      vim.pretty_print(...)
   end
end

return Hint
