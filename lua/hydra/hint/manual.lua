local Class = require('hydra.class')
local Hint = require('hydra.hint.hint')
local vim_options = require('hydra.hint.vim_options')


---@class hydra.hint.ManualWindow : hydra.Hint
---@field config hydra.hint.Config
---@field hint string[]
---@field bufnr integer | nil
---@field winid integer | nil
---@field win_width integer
---@field need_to_update boolean
---@field update function
---@field get_statusline nil
local HintManualWindow = Class(Hint)

function HintManualWindow:_constructor(...)
   Hint._constructor(self, ...)
   self.need_to_update = false

   self.config.functions = setmetatable(self.config.functions or {}, {
      __index = vim_options
   })

   self.hint = vim.split(self.hint, '\n')
   -- Remove last empty string.
   if self.hint and self.hint[#self.hint] == '' then
      self.hint[#self.hint] = nil
   end
end

function HintManualWindow:_make_buffer()
   if self.bufnr then return end

   self.bufnr = vim.api.nvim_create_buf(false, true)

   ---@type string[]
   local hint = vim.deepcopy(self.hint)

   ---@type table<string, hydra.HeadSpec>
   local heads = vim.deepcopy(self.heads)

   self.win_width = 0 -- The width of the window
   for line_nr, line in ipairs(hint) do
      local start, stop, fname = 0, nil, nil
      while start do
         start, stop, fname = line:find('%%{(.-)}', 1)
         if start then
            self.need_to_update = true

            local fun = self.config.functions[fname]
            if not fun then
               error(string.format('[Hydra] "%s" not present in "config.hint.functions" table', fname))
            end

            line = table.concat({
               line:sub(1, start - 1),
               fun(),
               line:sub(stop + 1)
            })
            hint[line_nr] = line
         end
      end

      local visible_line_len = vim.fn.strdisplaywidth(line:gsub('[_^]', '')) --[[@as integer]]
      if visible_line_len > self.win_width then
         self.win_width = visible_line_len
      end
   end

   self.win_height = #hint

   local line_count = vim.api.nvim_buf_line_count(self.bufnr)
   vim.api.nvim_buf_set_lines(self.bufnr, 0, line_count, false, hint)

   for line_nr, line in ipairs(hint) do
      local start, stop, head = 0, 0, nil
      while start do
         start, stop, head = line:find('_(.-)_', stop + 1)
         if head and vim.startswith(head, [[\]]) then head = head:sub(2) end
         if start then
            if not heads[head] then
               error(string.format('Hydra: docsting error, head "%s" does not exist', head))
            end
            local color = heads[head].color
            if color then
               vim.api.nvim_buf_add_highlight(
                  self.bufnr, self.namespaces_id, 'Hydra'..color, line_nr-1, start, stop-1)
            end
            heads[head] = nil
         end
      end
   end

   -- Remove heads with `desc = false`.
   for head, properties in pairs(heads) do
      if properties.desc == false then
         heads[head] = nil
      end
   end

   -- If there are remain hydra heads, that not present in manually created hint.
   if not vim.tbl_isempty(heads) then
      ---@type string[]
      local heads_lhs = vim.tbl_keys(heads)
      table.sort(heads_lhs, function (a, b)
         return heads[a].index < heads[b].index
      end)

      local line = {}
      for _, head in pairs(heads_lhs) do
         line[#line+1] = string.format('_%s_', head)
         -- line[#line+1] = string.format('[_%s_]', head)
         local desc = self.heads[head].desc
         if desc then
            desc = string.format(': %s, ', desc)
         else
            desc = ', '
         end
         line[#line+1] = desc
      end
      line = ' '..table.concat(line):gsub(', $', '')

      local len = vim.fn.strdisplaywidth(line:gsub('[_^]', '')) --[[@as integer]]
      if len > self.win_width then self.win_width = len end

      vim.api.nvim_buf_set_lines(self.bufnr, -1, -1, false, { '', line })
      self.win_height = self.win_height + 2

      local start, stop, head = 0, 0, nil
      while start do
         start, stop, head = line:find('_(.-)_', stop + 1)
         if start then
            local color = self.heads[head].color
            vim.api.nvim_buf_add_highlight(
               self.bufnr, self.namespaces_id, 'Hydra'..color, self.win_height - 1, start, stop - 1)
         end
      end
   end

   vim.bo[self.bufnr].filetype = 'hydra_hint'
   vim.bo[self.bufnr].modifiable = false
end

function HintManualWindow:_make_win_config()
   --   top-left   |   top   |  top-right
   -- -------------+---------+--------------
   --  middle-left | middle  | middle-right
   -- -------------+---------+--------------
   --  bottom-left | bottome | bottom-right

   local pos = vim.split(self.config.position, '-')

   self.win_config = {
      relative = 'editor',
      anchor = 'SW',
      width  = self.win_width,
      height = self.win_height,
      style = 'minimal',
      border = self.config.border or 'none',
      focusable = false,
      noautocmd = true,
   }

   if pos[1] == 'top' then
      self.win_config.row = 2
   elseif pos[1] == 'middle' then
      self.win_config.row = math.floor((vim.o.lines + self.win_height) / 2)
   elseif pos[1] == 'bottom' then
      self.win_config.row = vim.o.lines - vim.o.cmdheight - 1
   end

   if pos[2] == 'left' then
      self.win_config.col = 0
   elseif pos[2] == 'right' then
      self.win_config.col = vim.o.columns - self.win_width
   else -- center
      self.win_config.col = math.floor((vim.o.columns - self.win_width) / 2)
   end
end

function HintManualWindow:show()
   if not self.bufnr then
      self:_make_buffer()
   end
   if not self.winid then
      self:_make_win_config()
   end

   if not self.winid or not vim.api.nvim_win_is_valid(self.winid) then
      local winid = vim.api.nvim_open_win(self.bufnr, false, self.win_config)
      self.winid = winid
      vim.wo[winid].winhighlight = 'NormalFloat:HydraHint'
      vim.wo[winid].conceallevel = 3
      vim.wo[winid].foldenable = false
      vim.wo[winid].wrap = false
   end
end

function HintManualWindow:update()
   -- All this method is full of HACKs:
   -- 1. If update buffer, the concealing falls,
   --    so I have to create the new one and wipe the old one.
   -- 2. config table for nvim_win_set_config API function can't containing
   --    "noautocmd" key, despite documentation says it is equal to the same
   --    for nvim_open_win.

   if not self.need_to_update then return end

   local old_bufnr = self.bufnr --[[@as integer]]
   self.bufnr = nil
   self:_make_buffer()

   vim.api.nvim_win_set_buf(self.winid, self.bufnr)
   vim.api.nvim_buf_delete(old_bufnr, {})

   self:_make_win_config()
   local win_config = vim.deepcopy(self.win_config)
   win_config.noautocmd = nil

   vim.api.nvim_win_set_config(self.winid, win_config)

end

function HintManualWindow:close()
   if self.winid and vim.api.nvim_win_is_valid(self.winid) then
      vim.api.nvim_win_close(self.winid, false)
   end
   self.winid = nil
   if self.need_to_update then
      vim.api.nvim_buf_delete(self.bufnr, {})
      self.bufnr = nil
   end
end

return HintManualWindow
