local class = require('hydra.lib.class')
local Hint = require('hydra.hint.hint')
local M = {}

---@class hydra.hint.StatusLine : hydra.Hint
---@field update nil
local HintStatusLine = class(Hint)

---@param hydra Hydra
function HintStatusLine:initialize(hydra)
   Hint.initialize(self, hydra)
   self.meta_accessors = hydra.options
end

function HintStatusLine:_make_statusline()
   if self.statusline then return end

   require('hydra.lib.highlight').create_statusline_hl_groups()

   local statusline = {}
   local insert = table.insert
   local heads = self:_swap_head_with_index()
   for _, head in ipairs(heads) do
      if head.desc ~= false then
         insert(statusline, string.format('%%#HydraStatusLine%s#', head.color))
         insert(statusline, head.head)
         insert(statusline, '%#StatusLine#')
         local desc = head.desc
         if desc then
            desc = string.format(': %s, ', desc)
         else
            desc = ', '
         end
         insert(statusline, desc)
      end
   end
   statusline = table.concat(statusline)
   self.statusline = statusline:gsub(', $', '')
end

function HintStatusLine:show()
   if not self.statusline then self:_make_statusline() end

   local statusline = { ' ', self.statusline }
   if self.config.show_name then
      table.insert(statusline, 2, (self.hydra_name or 'HYDRA')..': ')
   end
   statusline = table.concat(statusline)

   local wo = self.meta_accessors.wo
   wo.statusline = statusline
end

--------------------------------------------------------------------------------

---@class HydraHintStatusLineMute : hydra.hint.StatusLine
---@field config nil
local HintStatusLineMute = class(HintStatusLine)

function HintStatusLineMute:initialize(...)
   HintStatusLine.initialize(self, ...)
end

---@param return_value boolean Return statusline string or not?
---@return string?
function HintStatusLineMute:show(return_value)
   if not return_value then return end

   if not self.statusline then self:_make_statusline() end
   return self.statusline
end

--------------------------------------------------------------------------------

M.intStatusLine = HintStatusLine
M.HintStatusLineMute = HintStatusLineMute
return M
