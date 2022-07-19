local Class = require('hydra.class')

---@class hydra.Hint
---@field hydra_name? string
---@field config hydra.hint.Config | "statusline" | false
---@field hint? string
---@field namespaces_id integer
---@field heads table<string, hydra.HeadSpec>
---@field show function
---@field close function
---@field update function | nil
---@field get_statusline function | nil
---@field _debug boolean
local Hint = Class()

---@param hydra Hydra
---@param hint? string[]
function Hint:_constructor(hydra, hint)
   self.hydra_name = hydra.name
   self.heads = hydra.heads_spec
   self.config = hydra.config.hint
   self.hint = hint
   self.namespaces_id = vim.api.nvim_create_namespace('hydra.hint')

   if vim.tbl_get(self, 'config', 'position')
      and type(self.config.position) == 'string'
   then
      self.config.position = vim.split(self.config.position, '-')
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
