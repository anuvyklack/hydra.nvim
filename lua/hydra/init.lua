local util = require('hydra/util')

---@type function
local termcodes = util.termcodes

local augroup_name = 'Hydra'
local augroup_id = vim.api.nvim_create_augroup(augroup_name, { clear = true })

local default_config = {
   exit = false,
   foreign_keys = nil, -- nil | warn | run
   color = 'red',
   on_enter  = nil, -- before entering hydra
   on_exit = nil, -- after leaving hydra
   timeout = false, -- true, false or number in milliseconds
   invoke_on_body = false,
   buffer = nil,
   hint = {
      position = 'bottom',
      border = nil
   },
   debug = false
}

---Currently active hydra
_G.Hydra = nil

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
         mode = { input.mode, { 'string', 'table' }, true },
         body = { input.body, 'string' },
         heads = { input.heads, 'table' },
      })
      if input.config then
         vim.validate({
            on_enter = { input.config.on_enter, 'function', true },
            on_exit = { input.config.on_exit, 'function', true },
            exit = { input.config.exit, 'boolean', true },
            timeout = { input.config.timeout, { 'boolean', 'number' }, true },
            buffer = { input.config.buffer, { 'boolean', 'number' }, true }
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

   self.id = util.generate_id() -- Unique ID for each Hydra.
   self.name  = input.name
   self.config = vim.tbl_deep_extend('force', default_config, input.config or {})
   self.mode  = input.mode or 'n'
   self.body  = input.body
   self.original = { o  = {}, go = {}, bo = {}, wo = {} }

   -- make Hydra buffer local
   if self.config.buffer and type(self.config.buffer) ~= 'number' then
      self.config.buffer = vim.api.nvim_get_current_buf()
   end

   self.hint = { lines = input.hint }
   if self.hint.lines then
      self.hint.lines = vim.split(self.hint.lines, '\n')
      -- Remove last empty string.
      if self.hint.lines[#self.hint.lines] == '' then
         self.hint.lines[#self.hint.lines] = nil
      end
   end

   -- Bring 'foreign_keys', 'exit' and 'color' options into line.
   local color = util.get_color_from_config(self.config.foreign_keys, self.config.exit)
   if color ~= 'red' and color ~= self.config.color then
      self.config.color = color
   elseif color ~= self.config.color then
      self.config.foreign_keys, self.config.exit = util.get_config_from_color(self.config.color)
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
         color = util.get_color_from_config(self.config.foreign_keys, opts.exit)
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
      if self.config.on_enter then
         local env = vim.tbl_deep_extend('force', getfenv(), {
            vim = { o = {}, go = {}, bo = {}, wo = {} }
         })
         env.vim.o  = self:_get_meta_accessor('o')
         env.vim.go = self:_get_meta_accessor('go')
         env.vim.bo = self:_get_meta_accessor('bo')
         env.vim.wo = self:_get_meta_accessor('wo')

         setfenv(self.config.on_enter, env)
      end
      if self.config.on_exit then
         local env = vim.tbl_deep_extend('force', getfenv(), {
            vim = { o = {}, go = {}, bo = {}, wo = {} }
         })
         env.vim.o  = util.disable_meta_accessor('o')
         env.vim.go = util.disable_meta_accessor('go')
         env.vim.bo = util.disable_meta_accessor('bo')
         env.vim.wo = util.disable_meta_accessor('wo')

         setfenv(self.config.on_exit, env)
      end
      self:_setup_hydra_keymaps()
   end
end

function Hydra:_setup_hydra_keymaps()
   self:_set_keymap(self.plug.enter, function() self:_enter() end)
   self:_set_keymap(self.plug.exit,  function() self:_exit()  end)
   self:_set_keymap(self.plug.leave, function() self:_leave() end)
   self:_set_keymap(self.plug.wait, self.plug.leave)

   -- Define entering keymap if Hydra is called only on body keymap.
   if self.config.invoke_on_body then
      self:_set_keymap(self.body, table.concat{ self.plug.enter, self.plug.wait })
   end

   -- Define Hydra kyebindings.
   for head, map in pairs(self.heads) do
      local rhs, opts = map[1], map[2]

      if not rhs then
         self.plug[head] = ''
      else
         self:_set_keymap(self.plug[head], rhs, opts)
      end

      -- Define enter mappings
      if not self.config.invoke_on_body and not opts.exit and not opts.private then
         self:_set_keymap(self.body..head, table.concat{
            self.plug.enter,
            self.plug[head],
            self.plug.wait
         })
      end

      -- Define exit mappings
      if opts.exit then -- blue head
         self:_set_keymap(self.plug.wait..head, table.concat{
            self.plug.exit,
            self.plug[head]
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
      local layer = util.unlimited_depth_table()
      layer.config = {
         buffer = self.config.buffer,
         on_enter = {
            function()
               _G.Hydra = self
               self:_show_hint()
            end,
            self.config.on_enter
         },
         on_exit = {
            self.config.on_exit,
            function()
               vim.api.nvim_win_close(self.hint.winid, false)
               _G.Hydra = nil
            end
         },
         timeout = self.config.timeout
      }

      local modes = type(self.mode) == 'table' and self.mode or { self.mode }
      self.body = termcodes(self.body)

      if self.config.invoke_on_body then
         for _, mode in ipairs(modes) do
            layer.enter_keymaps[mode][self.body] = {'<Nop>', {}}
         end
      end

      for head, map in pairs(self.heads) do
         head = termcodes(head)
         local rhs = map[1] or '<Nop>'
         local opts = map[2] and vim.deepcopy(map[2]) or {}
         local exit, private, head_modes = opts.exit, opts.private, opts.mode
         opts.color, opts.private, opts.exit, opts.modes = nil, nil, nil, nil
         if type(opts.desc) == 'boolean' then opts.desc = nil end

         if head_modes then
            head_modes = type(head_modes) == 'table' and head_modes or { head_modes }
         end

         for _, mode in ipairs(head_modes or modes) do
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

      util.deep_unsetmetatable(layer)

      return layer
   end

   local function create_layer_input_in_public_form()
      local layer = { enter = {}, layer = {}, exit = {} }
      layer.config = {
         buffer = self.config.buffer,
         on_enter = {
            function()
               _G.Hydra = self
               self:_show_hint()
            end,
            self.config.on_enter
         },
         on_exit = {
            self.config.on_exit,
            function()
               vim.api.nvim_win_close(self.hint.winid, false)
               _G.Hydra = nil
            end
         },
         timeout = self.config.timeout
      }

      if self.config.invoke_on_body then
         layer.enter[1] = { self.mode, self.body }
      end

      for head, map in pairs(self.heads) do
         head = termcodes(head)
         local rhs  = map[1] or '<Nop>'
         local opts = map[2] and vim.deepcopy(map[2]) or {}
         local exit, private, head_modes = opts.exit, opts.private, opts.mode
         opts.color, opts.private, opts.exit, opts.mode = nil, nil, nil, nil

         local mode = self.mode
         if head_modes then
            mode = type(head_modes) == 'table' and head_modes or { head_modes }
         end

         if not self.config.invoke_on_body and not exit and not private then
            table.insert(layer.enter, { mode, self.body..head, rhs, opts })
         end

         if exit then
            table.insert(layer.exit, { mode, head, rhs, opts })
         else
            table.insert(layer.layer, { mode, head, rhs, opts })
         end
      end

      return layer
   end

   local layer = create_layer_input_in_internal_form()
   -- local layer = create_layer_input_in_public_form()

   self.layer = KeyLayer(layer)
end

function Hydra:_enter()
   if _G.Hydra then
      if _G.Hydra.layer then
         _G.Hydra.layer:exit()
      else
         _G.Hydra:_exit()
      end
   end
   _G.Hydra = self

   local o = self:_get_meta_accessor('o')
   o.showcmd = false

   if self.config.timeout then
      o.timeout = true
      if type(self.config.timeout) == 'number' then
         o.timeoutlen = self.config.timeout
      end
   else
      o.timeout = false
   end
   o.ttimeout = not self.original.timeout and true
                or self.original.ttimeout

   if self.config.on_enter then self.config.on_enter() end

   self:_show_hint()
end

function Hydra:_exit()
   -- Restore original options
   for _, otype in ipairs({'o', 'go'}) do
      for opt, val in pairs(self.original[otype]) do
         vim[otype][opt] = val
      end
   end
   for bufnr, opts in pairs(self.original.bo) do
      if vim.fn.buflisted(bufnr) then
         for opt, val in pairs(opts) do
            vim.bo[bufnr][opt] = val
         end
      end
   end
   for winnr, opts in pairs(self.original.wo) do
      if vim.api.nvim_win_is_valid(winnr) then
         for opt, val in pairs(opts) do
            vim.wo[winnr][opt] = val
         end
      end
   end
   self.original = { o  = {}, go = {}, bo = {}, wo = {} }

   vim.api.nvim_clear_autocmds({ group = augroup_id })

   vim.api.nvim_win_close(self.hint.winid, false)
   -- vim.api.nvim_buf_delete(self.hint.bufnr, { force = true, unload = false })

   if self.config.on_exit then self.config.on_exit() end
   _G.Hydra = nil
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
      self:_exit()
   end
end

function Hydra:_show_hint()
   if not self.hint.bufnr then self:_prepare_hint_buffer() end

   if not self.hint.win_config then

      --   top-left   |   top   |  top-right
      -- -------------+---------+--------------
      --  middle-left | middle  | middle-right
      -- -------------+---------+--------------
      --  bottom-left | bottome | bottom-right

      -- self.config.hint.position = vim.split(self.config.hint.position, '-')
      local pos = vim.split(self.config.hint.position, '-')

      self.hint.win_config = {
         relative = 'editor',
         anchor = 'SW',
         width  = self.hint.win_width,
         height = self.hint.win_height,
         style = 'minimal',
         border = self.config.hint.border or 'none',
         focusable = false,
         noautocmd = true,
      }

      if pos[1] == 'top' then
         self.hint.win_config.row = 2
      elseif pos[1] == 'middle' then
         self.hint.win_config.row = math.floor((vim.o.lines + self.hint.win_height) / 2)
      elseif pos[1] == 'bottom' then
         self.hint.win_config.row = vim.o.lines - 2
      end

      if pos[2] == 'left' then
         self.hint.win_config.col = 0
      elseif pos[2] == 'right' then
         self.hint.win_config.col = vim.o.columns - self.hint.win_width
      else -- center
         self.hint.win_config.col = math.floor((vim.o.columns - self.hint.win_width) / 2)
      end
   end

   self.hint.winid = vim.api.nvim_open_win(self.hint.bufnr, false, self.hint.win_config)

   vim.wo[self.hint.winid].winhighlight = 'NormalFloat:HydraHint'
   vim.wo[self.hint.winid].conceallevel = 3
   vim.wo[self.hint.winid].foldenable = false
   vim.wo[self.hint.winid].wrap = false

   -- self.original_options.statusline = vim.o.statusline
end

function Hydra:_prepare_hint_buffer()
   -- Namespace ID
   local ns_id = vim.api.nvim_create_namespace('hydra.plugin')
   self.hint.bufnr = vim.api.nvim_create_buf(false, true)
   vim.bo[self.hint.bufnr].filetype = 'hydra_hint'

   if self.hint.lines then
      local visible_width = -1  -- The width of the window
      for _, line in ipairs(self.hint.lines) do
         local visible_line_len = vim.fn.strdisplaywidth(line:gsub('[_^]', ''))
         if visible_line_len > visible_width then
            visible_width = visible_line_len
         end
      end

      self.hint.win_width = visible_width
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
         line = ' '..table.concat(line):gsub(', $', '')
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
   else
      self.heads_order = util.reverse_tbl(self.heads_order)
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
   local o = opts and vim.deepcopy(opts) or {}
   if not vim.tbl_isempty(o) then
      o.color = nil
      o.private = nil
      o.exit = nil
      if type(o.desc) == 'boolean' then o.desc = nil end
      o.nowait = nil
      o.mode = nil
   end
   o.buffer = self.config.buffer
   vim.keymap.set(self.mode, lhs, rhs, o)
end

---Returns meta-accessor for vim options
---@param accessor string One from: 'o', 'go', 'bo', 'wo'
---@return any
function Hydra:_get_meta_accessor(accessor)
   local function set_buf_option(opt, val)
      local bufnr = vim.api.nvim_get_current_buf()
      self.original.bo[bufnr] = self.original.bo[bufnr] or {}
      if self.original.bo[bufnr][opt] then return end
      self.original.bo[bufnr][opt] = vim.api.nvim_buf_get_option(bufnr, opt)
      vim.api.nvim_buf_set_option(bufnr, opt, val)
   end

   local function set_win_option(opt, val)
      local winnr = vim.api.nvim_get_current_win()
      self.original.wo[winnr] = self.original.wo[winnr] or {}
      if self.original.wo[winnr][opt] then return end
      self.original.wo[winnr][opt] = vim.api.nvim_win_get_option(winnr, opt)
      vim.api.nvim_win_set_option(winnr, opt, val)
   end

   local ma = {
      bo = util.make_meta_accessor(
         function(opt)
            assert(type(opt) ~= 'number',
               '[Hydra] "vim.bo[bufnr]" meta-aссessor in config.on_enter() function is forbiden, use "vim.bo" instead')
            return vim.api.nvim_buf_get_option(0, opt)
         end,
         function(opt, val)
            set_buf_option(opt, val)

            vim.api.nvim_create_autocmd('BufEnter', {
               group = augroup_id,
               desc = string.format('set "%s" buffer option', opt),
               callback = function()
                  set_buf_option(opt, val)
               end
            })
         end
      ),
      wo = util.make_meta_accessor(
         function(opt)
            assert(type(opt) ~= 'number',
               '[Hydra] "vim.wo[winnr]" meta-aссessor in config.on_enter() function is forbiden, use "vim.wo" instead')
            return vim.api.nvim_win_get_option(0, opt)
         end,
         function(opt, val)
            set_win_option(opt, val)

            vim.api.nvim_create_autocmd('WinEnter', {
               group = augroup_id,
               desc = string.format('set "%s" window option', opt),
               callback = function()
                  set_win_option(opt, val)
               end
            })
         end
      ),
      go = util.make_meta_accessor(
         function(opt)
            return vim.api.nvim_get_option_value(opt, { scope = 'global' })
         end,
         function(opt, val)
            self.original.go[opt] = vim.api.nvim_get_option_value(opt, { scope = 'global' })
            vim.api.nvim_set_option_value(opt, val, { scope = 'global' })
         end
      ),
       o = util.make_meta_accessor(
         function(opt)
            return vim.api.nvim_get_option_value(opt, {})
         end,
         function(opt, val)
            self.original.o[opt] = vim.api.nvim_get_option_value(opt, {})
            vim.api.nvim_set_option_value(opt, val, {})
         end
      )
   }

   return ma[accessor]
end

function Hydra:_debug(...)
   if self.config.debug then
      vim.pretty_print(...)
   end
end

---Programmatically activate hydra
function Hydra:activate()
   if self.layer then
      self.layer:enter()
   else
      local keys = { self.plug.enter, self.plug.wait }
      for i, k in ipairs(keys) do
         keys[i] = vim.api.nvim_replace_termcodes(k, true, true, true)
      end
      keys = table.concat(keys)
      vim.api.nvim_feedkeys(keys, '', false)
   end
end

return Hydra
