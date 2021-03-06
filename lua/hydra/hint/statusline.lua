local Class = require('hydra.class')
local Hint = require('hydra.hint.hint')

---@class hydra.hint.StatusLine : hydra.Hint
---@field update nil
local HintStatusLine = Class(Hint)

---@param hydra Hydra
function HintStatusLine:_constructor(hydra)
   Hint._constructor(self, hydra)
   self.meta_accessors = hydra.options
end

function HintStatusLine:_make_statusline()
   if self.statusline then return end

   require('hydra.highlight').create_statusline_hl_groups()

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
local HintStatusLineMute = Class(HintStatusLine)

function HintStatusLineMute:_constructor(...)
   HintStatusLine._constructor(self, ...)
end

---@param return_value boolean Return statusline string or not?
---@return string?
function HintStatusLineMute:show(return_value)
   if not return_value then return end

   if not self.statusline then self:_make_statusline() end
   return self.statusline
end


return { HintStatusLine, HintStatusLineMute }
