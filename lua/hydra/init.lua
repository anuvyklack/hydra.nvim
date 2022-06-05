--[[

head == lhs

-- enter hydra
keymap.set(body..lhs, table.concat{
   <Plug>(hydra_pre),
   <Plug>(hydra_lhs),
   <Plug>(hydra_wait)
})

-- red head
keymap.set(<Plug>(hydra_wait)head, table.concat{
   <Plug>(hydra_head),
   <Plug>(hydra_wait)
})

-- blue head
keymap.set(<Plug>(hydra_wait)head, table.concat{
   <Plug>(hydra_head),
   <Plug>(hydra_post)
})

keymap.set(<Plug>(hydra_wait){the first N keys in head},
   <Plug>(hydra_leave)
)

keymap.set(<Plug>(hydra_wait), <Plug>(hydra_leave))

--]]

local utils = require('hydra/utils')
local default_config = {
   pre  = nil, -- before entering hydra
   post = nil, -- after leaving hydra
   timeout = false, -- true, false or number in milliseconds
   exit = false,
   foreign_keys = nil, -- nil | warn | run
   color = 'red',
   invoke_on_body = false,
   doc = {
      show = true,
      anchor = 'SW',
      row = nil, col = nil,
      border = nil
   }
}

_G.active_hydra = nil

---@class Hydra
---@field id number
---@field name string
---@field doc string[]
---@field config table
---@field mode string
---@field body string
---@field heads table<string, string|function|table>
---@field plug table<string, string>
---@field _show_doc function
---@field _close_doc function
local Hydra = {}
Hydra.__index = Hydra
setmetatable(Hydra, {
   ---The `new` method which created a new object and call constructor for it.
   ---@param ... unknown everything that constructor accepts
   ---@return Hydra
   __call = function(_, ...)
      local obj = setmetatable({}, Hydra)
      obj:_constructor(...)
      return obj
   end
})

---Constructor
---@param input table
---@return Hydra
function Hydra:_constructor(input)
   do -- validate parameters
      vim.validate({
         name = { input.name, 'string' },
         config = { input.config, 'table', true },
         mode = { input.mode, 'string' },
         body = { input.body, 'string' },
         heads = { input.heads, 'table' },
         exit = { input.exit, { 'string', 'table' }, true }
      })
      if input.config then
         vim.validate({
            pre = { input.config.pre, 'function', true },
            post = { input.config.post, 'function', true },
            exit = { input.config.exit, 'boolean', true },
            timeout = { input.config.timeout, { 'boolean', 'number' }, true }
         })
         vim.validate({
            foreign_keys = { input.config.foreign_keys, function(foreign_keys)
               if type(foreign_keys) == 'nil'
                  or foreign_keys == 'warn' or foreign_keys == 'run'
               then
                  return true
               else
                  return false
               end
            end, 'Hydra: config.foreign_keys value could be either "warn" or "run"' }
         })
         vim.validate({
            color = { input.config.color, function (color)
               local valid_colors = { red = true, blue = true, amaranth = true,
                                      teal = true, pink = true }
               return valid_colors[color] or false
            end, 'Hydra: color value could be one of: red, blue, amaranth, teal, pink' }
         })
      end
      for _, map in ipairs(input.heads) do
         vim.validate({
            head = { map, function(kmap)
               local lhs, rhs, opts = kmap[1], kmap[2], kmap[3]
               if type(kmap) ~= 'table'
                  or type(lhs) ~= 'string'
                  or (type(rhs) ~= 'string' and type(rhs) ~= 'function')
                  or (opts and type(opts) ~= 'table')
               then
                  return false
               else
                  return true
               end
            end, 'Hydra: wrong head type'}
         })
      end
   end

   self.id = utils.generate_id() -- Unique ID for each Hydra.
   self.name  = input.name
   self.config = vim.tbl_deep_extend('keep', input.config, default_config)
   self.mode  = input.mode
   self.body  = input.body
   -- self.exit = type(input.exit) == "string" and { input.exit } or input.exit or { '<Esc>' }

   self.doc = vim.split(input.doc, '\n')
   self.doc[#self.doc] = nil -- remove last empty string

   -- Bring 'foreign_keys', 'exit' and 'color' options into line.
   local color = utils.get_color_from_config(self.config.foreign_keys, self.config.exit)
   if color ~= 'red' and color ~= self.config.color then
      self.config.color = color
   elseif color ~= self.config.color then
      self.config.foreign_keys, self.config.exit = utils.get_config_from_color(self.config.color)
   end

   -- Table with all left hand sides of key mappings of the type `<Plug>...`.
   self.plug = setmetatable({}, {
      __index = function (t, key)
         t[key] = ('<Plug>(hydra_%s_%s)'):format(self.id, key)
         return t[key]
      end
   })

   self:_set_keymap(self.plug.pre, function() self:_pre() end)
   self:_set_keymap(self.plug.post, function() self:_post() end)

   self.heads, self.heads_order = {}, {}
   for index, head in ipairs(input.heads) do
      local lhs, rhs, opts = head[1], head[2], head[3] or {}

      if opts.exit ~= nil then -- User explicitly passed 'exit' option inside the head.
         color = utils.get_color_from_config(self.config.foreign_keys, opts.exit)
      else
         color = self.config.color
      end
      opts.color = color:gsub("^%l", string.upper) -- Capitalize first letter.

      self.heads[lhs] = { rhs, opts }
      self.heads_order[lhs] = index
   end

   -- Define entering mapping
   if self.config.invoke_on_body then
      self:_set_keymap(self.body, table.concat{ self.plug.pre, self.plug.wait })
   end

   for head, map in pairs(self.heads) do
      -- Define entering mappings
      if not self.config.invoke_on_body
         and not vim.tbl_get(map, 2, 'private')
         and not vim.tbl_get(map, 2, 'exit')
      then
         self:_set_keymap(self.body..head, table.concat{
            self.plug.pre,
            self.plug[head],
            self.plug.wait
         })
      end

      self:_define_hydra_map(head, map)
   end

   self:_set_keymap(self.plug.wait, function() self:_leave() end)

end

function Hydra:_define_hydra_map(head, map)
   if vim.tbl_get(map, 2, 'exit') or self.config.color == 'teal' then
      -- blue head
      self:_set_keymap(self.plug.wait..head, table.concat{
         self.plug[head],
         self.plug.post
      })
   else
      self:_set_keymap(self.plug.wait..head, table.concat{
         self.plug[head],
         self.plug.wait
      })
   end

   self:_set_keymap(self.plug[head], unpack(map))

   -- Assumption:
   -- Special keys such as <C-u> are escaped with < and >, i.e.,
   -- key sequences doesn't directly contain any escape sequences.
   local keys = vim.fn.split(head, [[\(<[^<>]\+>\|.\)\zs]])
   for i = #keys - 1, 1, -1 do
      local first_n_keys = table.concat(vim.list_slice(keys, 1, i))
      self:_set_keymap(self.plug.wait..first_n_keys, self.plug.leave)
   end
end

function Hydra:_pre()
   if _G.active_hydra then _G.active_hydra:_post() end
   _G.active_hydra = self

   -- self.original_options.showcmd  = vim.o.showcmd
   -- self.original_options.showmode = vim.o.showmode
   -- vim.o.showcmd = true
   -- vim.o.showmode = false

   self.original_options = {}
   self.original_options.timeout  = vim.o.timeout
   self.original_options.ttimeout = vim.o.ttimeout
   vim.o.ttimeout = not self.original_options.timeout and true
                    or self.original_options.ttimeout
   if self.config.timeout then
      vim.o.timeout = true
      if type(self.config.timeout) == 'number' then
         self.original_options.timeoutlen = vim.o.timeoutlen
         vim.o.timeoutlen = self.config.timeout
      end
   else
      vim.o.timeout = false
   end

   if self.config.pre then self.config.pre() end

   self:_show_doc()
end

function Hydra:_post()
   for option, value in pairs(self.original_options) do
      vim.o[option] = value
   end
   if self._close_doc then self._close_doc() end
   if self.config.post then self.config.post() end
   _G.active_hydra = nil
end

function Hydra:_leave()
   if self.config.color == 'amaranth' then
      if vim.fn.getchar(1) ~= 0 then
         print 'An Amaranth Hydra can only exit through a blue head'
         vim.fn.getchar()
         local keys = vim.api.nvim_replace_termcodes(self.plug.wait, true, true, true)
         vim.api.nvim_feedkeys(keys, '', false)
         -- vim.api.nvim_feedkeys(self.plug.wait, '', true)
         -- vim.fn.feedkeys([[\]]..self.plug.wait)
      end
   elseif self.config.color == 'teal' then
      if vim.fn.getchar(1) ~= 0 then
         print 'An Teal Hydra can only exit through one of its head'
         vim.fn.getchar()
         local keys = vim.api.nvim_replace_termcodes(self.plug.wait, true, true, true)
         vim.api.nvim_feedkeys(keys, '', false)
      end
   else
      self:_post()
   end
end

function Hydra:_show_doc()

   local longest_line_nr   -- Index of the longest line
   local max_line_len = -1 -- The lenght of the longest line
   for i, line in ipairs(self.doc) do
      local line_len = vim.fn.strdisplaywidth(line)
      if line_len > max_line_len then
         max_line_len = line_len
         longest_line_nr = i
      end
   end

   local bufnr = vim.api.nvim_create_buf(false, true)
   vim.api.nvim_buf_set_lines(bufnr, 0, 1, false, self.doc)
   vim.bo[bufnr].filetype = 'hydra_docstring'
   vim.bo[bufnr].modifiable = false
   vim.bo[bufnr].readonly = true

   local visible_width = max_line_len
   local i = 0
   while(true) do
      i = self.doc[longest_line_nr]:find('[_^]', i + 1)
      if i then visible_width = visible_width - 1 else break end
   end

   local winid = vim.api.nvim_open_win(bufnr, false, {
      relative = 'editor',
      anchor = self.config.doc.anchor or 'SW',
      row = self.config.doc.row or (vim.o.lines - 2),
      col = self.config.doc.col or math.floor((vim.o.columns - visible_width) / 2),
      width = visible_width,
      height = #self.doc,
      style = 'minimal',
      border = self.config.doc.border or 'none',
      focusable = false,
      noautocmd = true
   })
   vim.wo[winid].winhighlight = 'NormalFloat:HydraFloatWindow'
   vim.wo[winid].conceallevel = 3
   vim.wo[winid].foldenable = false
   -- vim.wo[winid].signcolumn = 'no'

   local ns_id = vim.api.nvim_create_namespace('hydra-docstring')

   local start, stop, head
   for line_nr, line in ipairs(self.doc) do
      stop = 0
      repeat
         start, stop, head = line:find('_(.-)_', stop + 1)
         if start then
            if not self.heads[head] then
               error(string.format('Hydra: docsting error, head %s does not exists', head))
            end
            local color = self.heads[head][2].color
            self.heads_order[head] = nil

            vim.api.nvim_buf_add_highlight(
               bufnr, ns_id, 'Hydra'..color, line_nr-1, start, stop)
         end
      until not stop
   end

   -- local hint = { ('echon "%s: '):format(self.name) }
   -- for head, map in pairs(self.heads) do
   --    -- Define <Plug> mappings for hydra heads actions.
   --    self:set_keymap(self.plug[head], unpack(map))
   --    do
   --       local desc = map[2].desc and string.format(': %s, ', map[2].desc) or ', '
   --       if map[2].exit then
   --          color = utils.get_color_from_config(self.config.foreign_keys, map[2].exit)
   --       else
   --          color = self.config.color
   --       end
   --       color = color:gsub("^%l", string.upper) -- amaranth -> Amaranth
   --       hint[#hint+1] = ('echohl Hydra%s'):format(color)
   --       hint[#hint+1] = ('echon "%s"'):format(head)
   --       hint[#hint+1] = 'echohl None'
   --       hint[#hint+1] = ('echon "%s"'):format(desc)
   --    end
   -- end
   -- for i, key in ipairs(self.exit) do
   --    hint[#hint+1] = 'echohl HydraBlue'
   --    hint[#hint+1] = ('echon "%s"'):format(key)
   --    hint[#hint+1] = 'echohl None'
   --    hint[#hint+1] = ('echon ": exit%s"'):format(i < #self.exit and ', ' or '')
   -- end
   --
   -- hint = table.concat(hint, ' | ')
   -- function self:_show_hint()
   --    vim.cmd(hint)
   -- end
   -- self:set_keymap(self.plug.show_hint, function() self:_show_hint() end)

   self.original_options.statusline = vim.o.statusline

   self.heads_order = utils.reverse_tbl(self.heads_order)
   self.statusline = { ' ', self.name, ': ' }
   for _, head in pairs(self.heads_order) do
      local color
      if self.config.color == 'teal' then
         color = 'teal'
      elseif vim.tbl_get(self.heads, head, 2, 'exit') then
         color = 'blue'
      else
         color = self.config.color
      end
      color = color:gsub("^%l", string.upper) -- Capitalize first letter.

   end

   function self:_close_doc()
      vim.api.nvim_win_close(winid, false)
      vim.api.nvim_buf_delete(bufnr, { force = true, unload = false })
   end
end

function Hydra:_set_keymap(lhs, rhs, opts)
   local o = opts and vim.deepcopy(opts) or nil
   if o then
      o.color = nil
      o.private = nil
      o.exit = nil
   end
   vim.keymap.set(self.mode, lhs, rhs, o)
end

-------------------------------------------------------------------------------
local sample_hydra = Hydra({
   name = 'Side scroll',
   docstring =
[[
Title
^-^--------^-^-------
_h_: left  _l_: right
]],
   config = {
      pre  = function() end, -- before entering hydra
      post = function() end, -- after leaving hydra
      timeout = false, -- false or num in milliseconds
      exit = false,
      foreign_keys = nil, -- nil | 'warn' | 'run'
      color = 'blue',
      invoke_on_body = false,
      docstring = {
         show = true,
         win_config = nil,
      }
   },
   mode = 'n',
   body = 'z',
   heads = {
      { 'h', 'zh', { desc = 'left' } },
      { 'l', 'zl' },
      { 'H', 'zH', { desc = 'half screen left', exit = true } },
      { 'L', 'zL', { desc = 'half screen right', private = true } },
      { 'q', nil, { exit = true } },
      { '<Esc>', nil, { desc = 'exit', exit = true } },
   }
})
print(sample_hydra)
-------------------------------------------------------------------------------

return Hydra
