local Class = require('hydra.class')
local Hint = require('hydra.hint.hint')

---@class hydra.hint.AutoWindow : hydra.Hint
---@field hint nil
---@field config hydra.hint.Config
---@field bufnr integer | nil
---@field winid integer | nil
---@field update nil
---@field get_statusline nil
local HintAutoWindow = Class(Hint)

function HintAutoWindow:_constructor(...)
   Hint._constructor(self, ...)
end

function HintAutoWindow:_make_buffer()
   self.bufnr = vim.api.nvim_create_buf(false, true)

   ---@type string[]
   local hint = { ' ', self.hydra_name or 'HYDRA', ': ' }
   local heads = self:_swap_head_with_index()
   for _, head in ipairs(heads) do
      if head.desc ~= false then
         hint[#hint+1] = string.format('_%s_', head.head)
         -- line[#line+1] = string.format('[_%s_]', head.head)
         local desc = head.desc
         if desc then
            desc = string.format(': %s, ', desc)
         else
            desc = ', '
         end
         hint[#hint+1] = desc
      end
   end
   hint = table.concat(hint)
   hint = hint:gsub(', $', '')
   vim.api.nvim_buf_set_lines(self.bufnr, 0, 1, false, { hint })

   -- Add highlight to buffer
   local start, stop, head = 0, 0, nil
   while start do
      start, stop, head = hint:find('_(.-)_', stop + 1)
      if head and vim.startswith(head, [[\]]) then head = head:sub(2) end
      if start then
         local color = self.heads[head].color
         vim.api.nvim_buf_add_highlight(
            self.bufnr, self.namespaces_id, 'Hydra'..color, 0, start, stop)
      end
   end

   vim.bo[self.bufnr].filetype = 'hydra_hint'
   vim.bo[self.bufnr].modifiable = false
   vim.bo[self.bufnr].readonly = true
end

function HintAutoWindow:_make_win_config()
   self.win_config = {
      relative = 'editor',
      anchor = 'SW',
      row = vim.o.lines - vim.o.cmdheight - 1,
      col = 1,
      width  = vim.o.columns,
      height = 1,
      style = 'minimal',
      border = self.config.border or 'none',
      focusable = false,
      noautocmd = true,
   }
end

function HintAutoWindow:show()
   if not self.bufnr then self:_make_buffer() end
   if not self.win_config then self:_make_win_config() end

   local winid = vim.api.nvim_open_win(self.bufnr, false, self.win_config)
   self.winid = winid
   vim.wo[winid].winhighlight = 'NormalFloat:HydraHint'
   vim.wo[winid].conceallevel = 3
   vim.wo[winid].foldenable = false
   vim.wo[winid].wrap = false
end

function HintAutoWindow:close()
   if self.winid and vim.api.nvim_win_is_valid(self.winid) then
      vim.api.nvim_win_close(self.winid, false)
   end
   self.winid = nil
end

return HintAutoWindow
