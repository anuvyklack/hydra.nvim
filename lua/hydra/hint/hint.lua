local Class = require('hydra.class')

---@class HydraHint
---@field hydra_name string
-- @field config table | string | false
---@field hint string[] | nil
---@field namespaces_id integer
---@field heads table<string, table>
---@field show function
---@field close function
---@field update function | nil
---@field get_statusline function | nil
local Hint = Class()

---@param hydra Hydra
---@param hint? string[]
function Hint:_constructor(hydra, hint)
   self.hydra_name = hydra.name
   self.heads = hydra.heads_spec
   self.config = hydra.config.hint
   self.hint = hint
   self.namespaces_id = vim.api.nvim_create_namespace('hydra.hint')
end

---In `self.heads` for every head makes the next:
---
---````
---head = {              index = {
---   index = ...,          head = ...,
---   color = ...,   =>     color = ...,
---   desc = ...            desc = ...
---}                     }
---````
---@return table
function Hint:swap_head_with_index()
   local old = vim.deepcopy(self.heads)
   local new = {}
   for head, properties in pairs(old) do
      local index = properties.index
      properties.index = nil
      properties.head = head
      new[index] = properties
   end
   return new
end

return Hint
