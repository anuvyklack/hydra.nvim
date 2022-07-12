local Class = require('hydra.class')
local Hint = require('hydra.hint.hint')

---@class HydraHintStatusLine : HydraHint
---@field config 'statusline'
---@field hint nil
---@field meta_accessors HydraOptions
---@field update nil
---@field get_statusline nil
local HintStatusLine = Class(Hint)

function HintStatusLine:_constructor(hydra, ...)
   Hint._constructor(self, hydra, ...)
   self.meta_accessors = hydra.options
   self.statusline = nil
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
   local statusline = table.concat{
      ' ', self.hydra_name or 'HYDRA', ': ', self.statusline
   }
   local wo = self.meta_accessors.wo
   wo.statusline = statusline
end

function HintStatusLine:close() end

--------------------------------------------------------------------------------

---@class HydraHintStatusLineMute : HydraHintStatusLine
---@field config false
---@field hint nil
---@field update nil
---@field get_statusline function
local HintStatusLineMute = Class(HintStatusLine)

function HintStatusLineMute:_constructor(...)
   HintStatusLine._constructor(self, ...)
   return self
end

function HintStatusLineMute:get_statusline()
   if not self.statusline then self:_make_statusline() end
   return self.statusline
end

function HintStatusLineMute:show() end

function HintStatusLineMute:close() end


return { HintStatusLine, HintStatusLineMute }
