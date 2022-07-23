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
   self.hydra_color = hydra.config.color
   self.heads = hydra.heads_spec
   if hydra.config.hint then
      self.config = hydra.config.hint --[[@as hydra.hint.Config]]
   end

   self._debug = hydra.config.debug
end

function Hint:leave()
   if self.hydra_color == 'amaranth' then
      -- 'An Amaranth Hydra can only exit through a blue head'
      vim.api.nvim_echo({
         {'An '},
         {'Amaranth', 'HydraAmaranth'},
         {' Hydra can only exit through a blue head'}
      }, false, {})
   elseif self.hydra_color == 'teal' then
      -- 'A Teal Hydra can only exit through one of its heads'
      vim.api.nvim_echo({
         {'A '},
         {'Teal', 'HydraTeal'},
         {' Hydra can only exit through one of its heads'}
      }, false, {})
   end
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

function Hint:close() end

return Hint
