local class = require('hydra.lib.class')
local api = vim.api
local autocmd = api.nvim_create_autocmd
local api_wrappers = require('hydra.lib.api-wrappers')
local BaseHint = require('hydra.hint.basehint')
local Window = api_wrappers.Window
local Buffer = api_wrappers.Buffer
local vim_options = require('hydra.hint.vim-options')
local strdisplaywidth = vim.fn.strdisplaywidth
local namespace = api.nvim_create_namespace('hydra.hint.window')
local augroup = api.nvim_create_augroup('hydra.hint', { clear = true })
local M = {}

--------------------------------------------------------------------------------

---@class hydra.hint.AutoWindow : hydra.Hint
---@field namespace integer
---@field buffer hydra.api.Buffer | nil
---@field win hydra.api.Window | nil
---@field update nil
local HintAutoWindow = class(BaseHint)

function HintAutoWindow:initialize(input)
   BaseHint.initialize(self, input)

   if type(self.config.position) == 'string' then
      self.config.position = vim.split(self.config.position, '-')
   end

   autocmd('VimResized', {
      desc = 'update Hydra hint window position',
      callback = function() self.win_config = nil end,
   })

   autocmd('OptionSet', {
      pattern = 'cmdheight',
      desc = 'update Hydra hint window position',
      callback = function() self.win_config = nil end,
   })
end

function HintAutoWindow:_make_buffer()
   ---@type hydra.api.Buffer
   local buffer = Buffer(api.nvim_create_buf(false, true))
   self.buffer = buffer

   local hint = { ' ' } ---@type string[]

   if self.config.show_name then
      hint[#hint+1] = (self.hydra_name or 'HYDRA')..': '
   end

   local heads = self:_get_heads_in_sequential_form()
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

   ---@diagnostic disable
   hint = table.concat(hint)
   hint = hint:gsub(', $', '')
   ---@diagnostic enable

   buffer:set_lines(0, 1, { hint })

   -- Add highlight to buffer
   local start, stop, head = 0, 0, nil
   while start do
      start, stop, head = hint:find('_(.-)_', stop + 1)
      if head and vim.startswith(head, [[\]]) then head = head:sub(2) end
      if start then
         local color = self.heads[head].color
         buffer:add_highlight(namespace, 'Hydra'..color, 0, start, stop)
      end
   end

   buffer.bo.filetype = 'hydra_hint'
   buffer.bo.modifiable = false
end

function HintAutoWindow:_make_win_config()
   self.win_config = {
      relative = 'editor',
      anchor = 'SW',
      row = vim.o.lines - vim.o.cmdheight - 1 - self.config.offset,
      col = 1,
      width  = vim.o.columns,
      height = 1,
      style = 'minimal',
      border = self.config.border,
      focusable = false,
      noautocmd = true,
   }
end

function HintAutoWindow:show()
   if not self.buffer or not self.buffer:is_loaded() then
      self:_make_buffer()
   end
   if not self.win_config then self:_make_win_config() end

   vim.o.eventignore = 'all' -- turn off autocommands

   local winid = api.nvim_open_win(self.buffer.id, false, self.win_config)
   ---@type hydra.api.Window
   local win = Window(winid)
   self.win = win

   win.wo.winhighlight = 'NormalFloat:HydraHint,FloatBorder:HydraBorder'
   win.wo.conceallevel = 3
   win.wo.foldenable = false
   win.wo.wrap = false

   vim.o.eventignore = nil -- turn on autocommands

   autocmd('TabEnter', { group = augroup, callback = function()
      if self.win:is_valid() then
         self.win:close()
      end
      self:show()
   end })
end

function HintAutoWindow:close()
   if self.win and self.win:is_valid() then
      self.win:close()
   end
   self.win = nil

   api.nvim_clear_autocmds({ group = augroup })
end

--------------------------------------------------------------------------------

---@class hydra.hint.ManualWindow : hydra.hint.AutoWindow
---@field hint string[]
---@field buffer hydra.api.Buffer | nil
---@field win_width integer
---@field need_to_update boolean
local HintManualWindow = class(HintAutoWindow)

function HintManualWindow:initialize(input)
   HintAutoWindow.initialize(self, input)
   self.need_to_update = false

   self.config.funcs = setmetatable(self.config.funcs or {}, {
      __index = vim_options
   })

   self.hint = vim.split(self.hint, '\n')
   -- Remove last empty string.
   if self.hint and self.hint[#self.hint] == '' then
      self.hint[#self.hint] = nil
   end
end

function HintManualWindow:_make_buffer()
   local bufnr = api.nvim_create_buf(false, true)

   ---@type hydra.api.Buffer
   local buffer = Buffer(bufnr)
   self.buffer = buffer

   ---@type string[]
   local hint = vim.deepcopy(self.hint)

   ---@type table<string, hydra.HeadSpec>
   local heads = vim.deepcopy(self.heads)

   self.win_width = 0 -- The width of the window
   for n, line in ipairs(hint) do
      local start, stop, fname = 0, nil, nil
      while start do
         start, stop, fname = line:find('%%{(.-)}', 1)
         if start then
            self.need_to_update = true

            local fun = self.config.funcs[fname]
            if not fun then
               error(string.format('[Hydra] "%s" not present in "config.hint.functions" table', fname))
            end

            line = table.concat({
               line:sub(1, start - 1),
               fun(),
               line:sub(stop + 1)
            })
            hint[n] = line
         end
      end

      local visible_line_len = strdisplaywidth(line:gsub('[_^]', ''))
      if visible_line_len > self.win_width then
         self.win_width = visible_line_len
      end
   end

   self.win_height = #hint

   local line_count = buffer:line_count()
   buffer:set_lines(0, line_count, hint)

   for n, line in ipairs(hint) do
      local start, stop, head = 0, 0, nil
      while start do
         start, stop, head = line:find('_(.-)_', stop + 1)
         if head and vim.startswith(head, [[\]]) then head = head:sub(2) end
         if start then
            if not heads[head] then
               error(string.format('[Hydra] docsting error, head "%s" does not exist', head))
            end
            local color = heads[head].color
            buffer:add_highlight(namespace, 'Hydra'..color, n-1, start, stop-1)
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

      local line = {} ---@type string[]
      for _, head in ipairs(heads_lhs) do
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
      line = ' '..table.concat(line):gsub(', $', '') ---@diagnostic disable-line

      local len = strdisplaywidth(line:gsub('[_^]', ''))
      if len > self.win_width then self.win_width = len end

      buffer:set_lines(-1, -1, { '', line })
      self.win_height = self.win_height + 2

      local start, stop, head = 0, 0, nil
      while start do
         start, stop, head = line:find('_(.-)_', stop+1)
         if start then
            local color = self.heads[head].color
            buffer:add_highlight(namespace, 'Hydra'..color, self.win_height-1, start, stop-1)
         end
      end
   end

   buffer.bo.buftype = 'nofile'
   buffer.bo.filetype = 'hydra_hint'
   buffer.bo.modifiable = false
end

function HintManualWindow:_make_win_config()
    --   top-left   |   top    |  top-right
    -- -------------+----------+--------------
    --  middle-left |  middle  | middle-right
    -- -------------+----------+--------------
    --  bottom-left |  bottom  | bottom-right
   local pos = self.config.position
   local offset = self.config.offset
   local anchor

   self.win_config = {
      relative = 'editor',
      width  = self.win_width,
      height = self.win_height,
      style = 'minimal',
      border = self.config.border,
      focusable = false,
      noautocmd = true,
   }

   if pos[1] == 'top' then
      anchor = 'N'
      self.win_config.row = offset
   elseif pos[1] == 'middle' then
      anchor = 'S'
      self.win_config.row = math.floor((vim.o.lines + self.win_height) / 2)
   elseif pos[1] == 'bottom' then
      anchor = 'S'
      self.win_config.row = vim.o.lines - vim.o.cmdheight - 1 - offset
   end

   if pos[2] == 'left' then
      anchor = anchor..'W'
      self.win_config.col = offset
   elseif pos[2] == 'right' then
      anchor = anchor..'E'
      self.win_config.col = vim.o.columns - offset
   else -- center
      anchor = anchor..'W'
      self.win_config.col = math.floor((vim.o.columns - self.win_width) / 2)
   end

   self.win_config.anchor = anchor
end

function HintManualWindow:update()
   -- All this method is full of HACKs:
   -- 1. If update buffer, the concealing falls, so I have to create the new one
   --    and wipe the old one.
   -- 2. "config" table for "nvim_win_set_config" API function can't containes
   --    "noautocmd" key, despite documentation says it is equal to the same
   --    for "nvim_open_win".

   if not self.need_to_update then return end

   local old_buffer = self.buffer
   self.buffer = nil
   self:_make_buffer()

   self.win:set_buffer(self.buffer)
   if old_buffer then old_buffer:delete() end

   self:_make_win_config()
   local win_config = vim.deepcopy(self.win_config)
   win_config.noautocmd = nil
   self.win:set_config(win_config)
end

function HintManualWindow:close()
   HintAutoWindow.close(self)

   if self.need_to_update then
      self.win_config = nil
      self.buffer:delete()
      self.buffer = nil
   end
end

--------------------------------------------------------------------------------

M.HintAutoWindow = HintAutoWindow
M.HintManualWindow = HintManualWindow
return M
