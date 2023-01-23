local class = require('hydra.lib.class')
local BaseHint = require('hydra.hint.basehint')
local M = {}

---@class hydra.hint.StatusLine : hydra.Hint
---@field update nil
local HintStatusLine = class(BaseHint)

function HintStatusLine:initialize(input)
   BaseHint.initialize(self, input)
end

function HintStatusLine:_make_statusline()
   if self.statusline then return end

   require('hydra.lib.highlight')

   ---@type string[]
   local statusline = {}
   local heads = self:_get_heads_in_sequential_form()
   for _, head in ipairs(heads) do
      if head.desc ~= false then
         vim.list_extend(statusline, {
            string.format('%%#HydraStatusLine%s#', head.color),
            head.head,
            '%#StatusLine#',
            head.desc and string.format(': %s, ', head.desc) or ', '
         })
      end
   end
   statusline = table.concat(statusline) ---@diagnostic disable-line
   self.statusline = statusline:gsub(', $', '')
end

function HintStatusLine:show()
   if not self.statusline then self:_make_statusline() end

   local statusline = { ' ', self.statusline } ---@type string[]
   if self.config.show_name then
      table.insert(statusline, 2, (self.hydra_name or 'HYDRA')..': ')
   end
   statusline = table.concat(statusline) ---@diagnostic disable-line

   self.original_statusline = vim.wo.statusline
   vim.wo.statusline = statusline
end

function HintStatusLine:close()
   if self.original_statusline then
      vim.wo.statusline = self.original_statusline
      self.original_statusline = nil
   end
end

--------------------------------------------------------------------------------

---Statusline hint that won't be shown. It is used in "hydra.statusline" module.
---@class hydra.hint.StatusLineMute : hydra.hint.StatusLine
---@field config nil
local HintStatusLineMute = class(HintStatusLine)

function HintStatusLineMute:initialize(input)
   HintStatusLine.initialize(self, input)
end

---@param do_return? boolean Do return statusline hint string?
---@return string?
function HintStatusLineMute:show(do_return)
   if do_return then
      if not self.statusline then self:_make_statusline() end
      return self.statusline
   end
end

--------------------------------------------------------------------------------

M.HintStatusLine = HintStatusLine
M.HintStatusLineMute = HintStatusLineMute
return M
