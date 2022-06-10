--[[

Hydras "head" is a "lhs" (left hand side), i.e keys you have to type to invoke
mapping.

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

---@type function
local termcodes = utils.termcodes

local default_config = {
   pre  = nil, -- before entering hydra
   post = nil, -- after leaving hydra
   timeout = false, -- true, false or number in milliseconds
   color = 'red',
   exit = false,
   foreign_keys = nil, -- nil | warn | run
   invoke_on_body = false,
   hint = {
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
         name = { input.name, 'string', true },
         config = { input.config, 'table', true },
         mode = { input.mode, 'string', true },
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
            color = { input.config.color, function(color)
               if not color then return true end
               local valid_colors = {
                  red = true, blue = true, amaranth = true, teal = true, pink = true
               }
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
                  or (rhs and type(rhs) ~= 'string' and type(rhs) ~= 'function')
                  or (opts and (type(opts) ~= 'table' or opts.desc == true))
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
   self.config = vim.tbl_deep_extend('force', default_config, input.config or {})
   self.mode  = input.mode or 'n'
   self.body  = input.body
   self.original_options = {}

   self.hint = { lines = input.hint }
   if self.hint.lines then
      self.hint.lines = vim.split(self.hint.lines, '\n')
      -- Remove last empty string.
      if self.hint.lines[#self.hint.lines] == '' then
         self.hint.lines[#self.hint.lines] = nil
      end
   end

   -- Bring 'foreign_keys', 'exit' and 'color' options into line.
   local color = utils.get_color_from_config(self.config.foreign_keys, self.config.exit)
   if color ~= 'red' and color ~= self.config.color then
      self.config.color = color
   elseif color ~= self.config.color then
      self.config.foreign_keys, self.config.exit = utils.get_config_from_color(self.config.color)
   end
   if self.config.exit then
      self.config.invoke_on_body = true
   end

   -- Table with all left hand sides of key mappings of the type `<Plug>...`.
   self.plug = setmetatable({}, {
      __index = function(t, key)
         t[key] = ('<Plug>(Hydra%s_%s)'):format(self.id, key)
         return t[key]
      end
   })

   self.heads = {}; self.heads_order = {}
   local has_exit_head = self.config.exit and true or nil
   for index, head in ipairs(input.heads) do
      local lhs, rhs, opts = head[1], head[2], head[3] or {}

      if opts.exit ~= nil then -- User explicitly passed `exit` parameter to the head
         color = utils.get_color_from_config(self.config.foreign_keys, opts.exit)
         if opts.exit and has_exit_head == nil then
            has_exit_head = true
         end
      else
         opts.exit = self.config.exit
         color = self.config.color
      end
      opts.color = color:gsub("^%l", string.upper) -- Capitalize first letter.

      self.heads[lhs] = { rhs, opts }
      self.heads_order[lhs] = index
   end
   if not has_exit_head then
      self.heads['<Esc>'] = { nil, {
         exit = true,
         desc = 'exit',
         color = self.config.foreign_keys == 'warn' and 'Teal' or 'Blue'
      }}
      self.heads_order['<Esc>'] = vim.tbl_count(self.heads)
   end

   if self.config.color == 'pink' then
      self:_setup_pink_hydra()
   else
      self:_setup_hydra_keymaps()
   end
end

function Hydra:_setup_hydra_keymaps()
   self:_set_keymap(self.plug.pre,   function() self:_pre() end)
   self:_set_keymap(self.plug.post,  function() self:_post() end)
   self:_set_keymap(self.plug.leave, function() self:_leave() end)
   self:_set_keymap(self.plug.wait, self.plug.leave)

   -- Define entering keymap if Hydra is called only on body keymap.
   if self.config.invoke_on_body then
      self:_set_keymap(self.body, table.concat{ self.plug.pre, self.plug.wait })
   end

   -- Define Hydra kyebindings.
   for head, map in pairs(self.heads) do
      local rhs, opts = map[1], map[2]

      if not rhs then
         self.plug[head] = ''
      else
         self:_set_keymap(self.plug[head], rhs, opts)
      end

      -- Define entering mappings
      if not self.config.invoke_on_body and not opts.exit and not opts.private then
         self:_set_keymap(self.body..head, table.concat{
            self.plug.pre,
            self.plug[head],
            self.plug.wait
         })
      end

      if opts.exit then -- blue head
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

      -- Assumption:
      -- Special keys such as <C-u> are escaped with < and >, i.e.,
      -- key sequences doesn't directly contain any escape sequences.
      local keys = vim.fn.split(head, [[\(<[^<>]\+>\|.\)\zs]])
      for i = #keys-1, 1, -1 do
         local first_n_keys = table.concat(vim.list_slice(keys, 1, i))
         self:_set_keymap(self.plug.wait..first_n_keys, self.plug.leave)
      end
   end
end

function Hydra:_setup_pink_hydra()
   local available, KeyLayer = pcall(require, 'keymap-layer')
   if not available then
      vim.schedule(function() vim.notify_once(
         '[hyda.nvim] For pink hydra you need https://github.com/anuvyklack/keymap-layer.nvim package',
         vim.log.levels.ERROR)
      end)
      return false
   end

   local function create_layer_input_in_internal_form()

      local layer = setmetatable({}, {
         __index = function(self, mappings_type)
            self[mappings_type] = setmetatable({}, {
               __index = function(self, mode)
                  self[mode] = setmetatable({}, {
                     __index = function(self, lhs)
                        self[lhs] = {}
                        return self[lhs]
                     end
                  })
                  return self[mode]
               end
            })
            return self[mappings_type]
         end
      })

      layer.config = {
         on_enter = function()
            if self.config.pre then self.config.pre() end
            self:_show_hint()
         end,
         on_exit = function()
            vim.api.nvim_win_close(self.hint.winid, false)
            if self.config.post then self.config.post() end
         end,
         timeout = self.config.timeout
      }

      local modes = type(self.mode) == 'table' and self.mode or { self.mode }
      for _, mode in ipairs(modes) do
         self.body = termcodes(self.body)

         if self.config.invoke_on_body then
            layer.enter_keymaps[mode][self.body] = {'<Nop>', {}}
         end

         for head, map in pairs(self.heads) do
            head = termcodes(head)
            local rhs, opts = map[1], map[2] and vim.deepcopy(map[2]) or {}
            if not rhs then rhs = '<Nop>' end
            local exit, private = opts.exit, opts.private
            opts.color, opts.private, opts.exit, opts.hint = nil, nil, nil, nil

            if not self.config.invoke_on_body and not exit and not private then
               layer.enter_keymaps[mode][self.body..head] = { rhs, opts }
            end

            if exit then
               layer.exit_keymaps[mode][head] = { rhs, opts }
            else
               layer.layer_keymaps[mode][head] = { rhs, opts }
            end
         end
      end

      utils.deep_unsetmetatable(layer)

      return layer
   end

   local function create_layer_input_in_public_form()
      local layer = {
         enter = {}, layer = {}, exit = {},
         config = {
            on_enter = function()
               if self.config.pre then self.config.pre() end
               self:_show_hint()
            end,
            on_exit = function()
               vim.api.nvim_win_close(self.hint.winid, false)
               if self.config.post then self.config.post() end
            end,
            timeout = self.config.timeout
         }
      }

      if self.config.invoke_on_body then
         layer.enter[1] = { self.mode, self.body }
      end

      for head, map in pairs(self.heads) do
         local rhs, opts = map[1], map[2]
         if not rhs then rhs = '<Nop>' end
         local exit, private = opts.exit, opts.private
         opts.color, opts.private, opts.exit, opts.hint = nil, nil, nil, nil

         if not self.config.invoke_on_body and not exit and not private then
            table.insert(layer.enter, { self.mode, self.body..head, rhs, opts })
         end

         if exit then
            table.insert(layer.exit, { self.mode, head, rhs, opts })
         else
            table.insert(layer.layer, { self.mode, head, rhs, opts })
         end
      end

      return layer
   end

   local layer = create_layer_input_in_internal_form()
   -- local layer = create_layer_input_in_public_form()

   self.layer = KeyLayer(layer)
end

function Hydra:_pre()
   if _G.active_hydra then
      if _G.active_hydra.layer then
         _G.active_hydra.layer.exit()
      else
         _G.active_hydra:_post()
      end
   end
   _G.active_hydra = self

   self.original_options.showcmd  = vim.o.showcmd
   vim.o.showcmd = false

   -- self.original_options.showmode = vim.o.showmode
   -- vim.o.showmode = false

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

   self:_show_hint()
end

function Hydra:_post()
   for option, value in pairs(self.original_options) do
      vim.o[option] = value
   end

   vim.api.nvim_win_close(self.hint.winid, false)
   -- vim.api.nvim_buf_delete(self.hint.bufnr, { force = true, unload = false })

   if self.config.post then self.config.post() end
   _G.active_hydra = nil
   vim.cmd 'echo'
end

function Hydra:_leave()
   if self.config.color == 'amaranth' then
      if vim.fn.getchar(1) ~= 0 then
         -- print 'An Amaranth Hydra can only exit through a blue head'
         local msg = {
            'echon "An "',
            'echohl HydraAmaranth',
            'echon "Amaranth "',
            'echohl None',
            'echon "Hydra can only exit through a blue head"',
         }
         msg = table.concat(msg, ' | ')
         vim.cmd(msg)

         vim.fn.getchar()
         local keys = vim.api.nvim_replace_termcodes(self.plug.wait, true, true, true)
         vim.api.nvim_feedkeys(keys, '', false)
         -- vim.api.nvim_feedkeys(self.plug.wait, '', true)
         -- vim.fn.feedkeys([[\]]..self.plug.wait)
      end
   elseif self.config.color == 'teal' then
      if vim.fn.getchar(1) ~= 0 then
         -- print 'A Teal Hydra can only exit through one of its heads'
         local msg = {
            'echon "A "',
            'echohl HydraTeal',
            'echon "Teal "',
            'echohl None',
            'echon "Hydra can only exit through one of its heads"',
         }
         msg = table.concat(msg, ' | ')
         vim.cmd(msg)

         vim.fn.getchar()
         local keys = vim.api.nvim_replace_termcodes(self.plug.wait, true, true, true)
         vim.api.nvim_feedkeys(keys, '', false)
      end
   else
      self:_post()
   end
end

function Hydra:_show_hint()
   if not self.hint.bufnr then self:_prepare_hint_buffer() end

   self.hint.winid = vim.api.nvim_open_win(self.hint.bufnr, false, {
      relative = 'editor',
      anchor = self.config.hint.anchor,
      row = self.config.hint.row or (vim.o.lines - 2),
      col = self.config.hint.col or
            math.floor((vim.o.columns - self.hint.win_width) / 2),
      width  = self.hint.win_width,
      height = self.hint.win_height,
      style = 'minimal',
      border = self.config.hint.border or 'none',
      focusable = false,
      noautocmd = true
   })
   vim.wo[self.hint.winid].winhighlight = 'NormalFloat:HydraHint'
   vim.wo[self.hint.winid].conceallevel = 3
   vim.wo[self.hint.winid].foldenable = false

   -- self.original_options.statusline = vim.o.statusline
end

function Hydra:_prepare_hint_buffer()
   local ns_id = vim.api.nvim_create_namespace('hydra.plugin')
   self.hint.bufnr = vim.api.nvim_create_buf(false, true)
   vim.bo[self.hint.bufnr].filetype = 'hydra_hint'

   if self.hint.lines then
      local longest_line_nr   -- Index of the longest line
      local max_line_len = -1 -- The lenght of the longest line
      for i, line in ipairs(self.hint.lines) do
         local line_len = vim.fn.strdisplaywidth(line)
         if line_len > max_line_len then
            max_line_len = line_len
            longest_line_nr = i
         end
      end

      local visible_width = max_line_len
      local i = 0
      while(true) do
         i = self.hint.lines[longest_line_nr]:find('[_^]', i + 1)
         if i then visible_width = visible_width - 1 else break end
      end
      self.hint.win_height = #self.hint.lines

      vim.api.nvim_buf_set_lines(self.hint.bufnr, 0, 1, false, self.hint.lines)

      for line_nr, line in ipairs(self.hint.lines) do
         local start, stop, head
         stop = 0
         repeat
            start, stop, head = line:find('_(.-)_', stop + 1)
            if head and vim.startswith(head, [[\]]) then head = head:sub(2) end
            if start then
               if not self.heads[head] then
                  error(string.format('Hydra: docsting error, head %s does not exist', head))
               end
               local color = self.heads[head][2].color
               self.heads_order[head] = nil

               vim.api.nvim_buf_add_highlight(
                  self.hint.bufnr, ns_id, 'Hydra'..color, line_nr-1, start, stop)
            end
         until not stop
      end

      -- If there are remain hydra heads, that not present in manually created hint.
      if not vim.tbl_isempty(self.heads_order) then
         local heads = vim.tbl_keys(self.heads_order)
         table.sort(heads, function (a, b)
            return self.heads_order[a] < self.heads_order[b]
         end)

         local line, len = {}, 0
         for _, head in pairs(heads) do
            if vim.tbl_get(self.heads, head, 2, 'desc') ~= false then
               line[#line+1] = string.format('_%s_', head)
               -- line[#line+1] = string.format('[_%s_]', head)
               local desc = vim.tbl_get(self.heads, head, 2, 'desc')
               if desc then
                  desc = string.format(': %s, ', desc)
               else
                  desc = ', '
               end
               line[#line+1] = desc
               len = len + #head + #desc
            end
         end
         line = table.concat(line):gsub(', $', '')
         len = len - 2
         if len > visible_width then visible_width = len end

         vim.api.nvim_buf_set_lines(self.hint.bufnr, -1, -1, false, { '', line })
         self.hint.win_height = self.hint.win_height + 2

         local start, stop, head
         stop = 0
         repeat
            start, stop, head = line:find('_(.-)_', stop + 1)
            if start then
               local color = self.heads[head][2].color
               vim.api.nvim_buf_add_highlight(
                  self.hint.bufnr, ns_id, 'Hydra'..color, self.hint.win_height - 1, start, stop)
            end
         until not stop

      end

      self.hint.win_width = visible_width
   else
      self.heads_order = utils.reverse_tbl(self.heads_order)
      local line = { ' ', self.name or 'HYDRA', ': ' }
      for _, head in pairs(self.heads_order) do
         if vim.tbl_get(self.heads, head, 2, 'desc') ~= false then
            line[#line+1] = string.format('_%s_', head)
            -- line[#line+1] = string.format('[_%s_]', head)
            local desc = self.heads[head][2].desc
            if desc then
               desc = string.format(': %s, ', desc)
            else
               desc = ', '
            end
            line[#line+1] = desc
         end
      end
      line = table.concat(line):gsub(', $', '')
      vim.api.nvim_buf_set_lines(self.hint.bufnr, 0, 1, false, { line })

      local start, stop, head
      stop = 0
      repeat
         start, stop, head = line:find('_(.-)_', stop + 1)
         if head and vim.startswith(head, [[\]]) then head = head:sub(2) end
         if start then
            local color = self.heads[head][2].color
            vim.api.nvim_buf_add_highlight(
               self.hint.bufnr, ns_id, 'Hydra'..color, 0, start, stop)
         end
      until not stop

      self.config.hint.row = vim.o.lines
      self.config.hint.col = 1
      self.hint.win_height = 1
      self.hint.win_width = vim.o.columns
   end

   vim.bo[self.hint.bufnr].modifiable = false
   vim.bo[self.hint.bufnr].readonly = true
end

function Hydra:_set_keymap(lhs, rhs, opts)
   local o = opts and vim.deepcopy(opts) or nil
   if o then
      o.color = nil
      o.private = nil
      o.exit = nil
      if type(o.desc) == 'boolean' then o.desc = nil end
   end
   vim.keymap.set(self.mode, lhs, rhs, o)
end

return Hydra
