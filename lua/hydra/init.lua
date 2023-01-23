local class = require('hydra.lib.class')
local make_hint = require('hydra.hint')
local options = require('hydra.lib.meta-accessor')
local util = require('hydra.lib.util')
local termcodes = util.termcodes
local api = vim.api

---Currently active hydra
---@type Hydra | nil
_G.Hydra = nil

---@class Hydra
---@field id number
---@field name? string
---@field hint hydra.Hint
---@field config hydra.Config
---@field mode string | string[]
---@field body? string
---@field heads table<string, hydra.Head>
---@field heads_spec table<string, hydra.HeadSpec> Used in hint class.
---@field options hydra.MetaAccessor
---@field plug_wait string
local Hydra = class()

---@type hydra.Config
local default_config = {
   debug = false,
   exit = false,
   foreign_keys = nil,
   color = 'red',
   timeout = false,
   invoke_on_body = false,
   hint = {
      show_name = true,
      position = { 'bottom' },
      offset = 0,
      border = nil,
   }
}

---@param input table
function Hydra:initialize(input)
   do -- validate parameters
      vim.validate({
         name = { input.name, 'string', true },
         config = { input.config, 'table', true },
         mode = { input.mode, { 'string', 'table' }, true },
         body = { input.body, 'string', true },
         heads = { input.heads, 'table' },
      })
      if input.config then
         vim.validate({
            on_enter = { input.config.on_enter, 'function', true },
            on_exit = { input.config.on_exit, 'function', true },
            exit = { input.config.exit, 'boolean', true },
            timeout = { input.config.timeout, { 'boolean', 'number' }, true },
            buffer = { input.config.buffer, { 'boolean', 'number' }, true },
            hint = { input.config.hint, { 'boolean', 'string', 'table' }, true },
            desc = { input.config.desc, 'string', true }
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
      for _, head in ipairs(input.heads) do
         vim.validate({ head = { head, 'table' } })
         local lhs, rhs, opts = head[1], head[2], head[3]
         vim.validate({
            lhs  = { lhs, 'string' },
            rhs  = { rhs, { 'string', 'function' }, true },
            opts = { opts, 'table', true },
         })
         if opts then
            vim.validate({
               ['head.desc'] = { opts.desc, function(d)
                  return (d == nil) or (type(d) == 'string') or (d == false)
               end, 'string or false' },
               ['head.exit'] = { opts.exit, 'boolean', true },
               ['head.exit_before'] = { opts.exit_before, 'boolean', true },
            })
         end
      end
   end

   self.id = util.generate_id() -- Unique ID for each Hydra.
   self.name = input.name
   self.mode = input.mode or 'n'
   self.body = input.body
   self.heads = {}
   self.options = options('hydra.options')
   self.plug_wait = string.format('<Plug>(Hydra%d_wait)', self.id)
   self.config = util.megre_config(default_config, input.config or {})

   do
      if not self.config.desc then
         if self.name then
            self.config.desc = '[Hydra] '..self.name
         else
            self.config.desc = '[Hydra]'
         end
      end

      -- make Hydra buffer-local
      if self.config.buffer and type(self.config.buffer) ~= 'number' then
         self.config.buffer = api.nvim_get_current_buf()
      end

      -- Bring 'foreign_keys', 'exit' and 'color' options into line.
      -- `Color` has higher precedence. If passed `color` not equal to
      -- one derived from passed `foreign-keys` and `exit` options, then
      -- override them.
      if self.config.color ~= util.get_color_from_config(self.config.foreign_keys,
                                                         self.config.exit)
      then
         self.config.foreign_keys, self.config.exit =
            util.get_config_from_color(self.config.color)
      end

      if not self.body or self.config.exit then
         self.config.invoke_on_body = true
      end

      if self.config.hint and not self.config.hint.type then
         self.config.hint.type = input.hint and 'window' or 'cmdline'
      end
   end

   local heads_spec = {}
   local has_exit_head = self.config.exit
   for index, head in ipairs(input.heads) do
      local lhs  = head[1] --[[@as string]]
      local rhs  = head[2]
      local opts = head[3] or {}

      if opts.exit_before then
         opts.exit = true
      end

      local color
      if opts.exit ~= nil then
         color = util.get_color_from_config(self.config.foreign_keys, opts.exit)
      else
         color = self.config.color
      end

      heads_spec[lhs] = {
         head  = lhs,
         index = index,
         color = color:gsub("^%l", string.upper), -- capitalize first letter
         desc  = opts.desc
      }

      if opts.exit ~= nil then -- User explicitly passed `exit` parameter to the head
         if opts.exit and not has_exit_head then
            has_exit_head = true
         end
      else
         opts.exit = self.config.exit
      end
      if type(opts.mode) == 'string' then opts.mode = { opts.mode } end
      if type(opts.desc) ~= 'string' then opts.desc = nil end

      ---@cast rhs string | function | nil
      ---@cast opts hydra.HeadOpts
      self.heads[lhs] = { rhs, opts }
   end
   if not has_exit_head then
      self.heads['<Esc>'] = { nil, { exit = true } }
      heads_spec['<Esc>'] = {
         head = '<Esc>',
         index = vim.tbl_count(self.heads),
         color = self.config.foreign_keys == 'warn' and 'Teal' or 'Blue',
         desc = 'exit'
      }
   end

   -- self.hint = hint(self, self.config.hint, input.hint)
   self.hint = make_hint({
      name = self.name,
      color = self.config.color,
      hint = input.hint,
      heads = heads_spec,
      config = self.config.hint,
      debug = self.config.debug
   })

   if self.config.color ~= 'pink' then
      -- HACK: I replace in the backstage the `vim.bo` table called inside
      -- `self.config.on_enter()` function with my own.
      if self.config.on_enter then
         getmetatable(self.options.bo).__index = util.add_hook_before(
            getmetatable(self.options.bo).__index,
            function(_, opt)
               assert(type(opt) ~= 'number',
                  '[Hydra] vim.bo[bufnr] meta-aссessor in config.on_enter() function is forbiden, use "vim.bo" instead')
            end
         )
         getmetatable(self.options.wo).__index = util.add_hook_before(
            getmetatable(self.options.wo).__index,
            function(_, opt)
               assert(type(opt) ~= 'number',
                  '[Hydra] vim.wo[winnr] meta-aссessor in config.on_enter() function is forbiden, use "vim.wo" instead')
            end
         )

         -- HACK: The `vim.deepcopy()` rize an error if try to copy `getfenv()`
         -- environment with next snippet:
         -- ```
         --    local env = vim.deepcopy(getfenv())
         -- ```
         -- But `vim.tbl_deep_extend` function makes a copy if extend `getfenv()`
         -- with not empty table; another way, it returns the reference to the
         -- original table.
         local env = vim.tbl_deep_extend('force', getfenv(), {
            vim = { o = {}, go = {}, bo = {}, wo = {} }
         })
         env.vim.o  = self.options.o
         env.vim.go = self.options.go
         env.vim.bo = self.options.bo
         env.vim.wo = self.options.wo

         setfenv(self.config.on_enter, env)
      end
      if self.config.on_exit then
         ---@param name string
         local function show_disable_message(name)
            util.warn(string.format(
               '[Hydra] "vim.%s" meta-accessor is disabled inside config.on_exit() function',
               name))
         end

         local env = vim.tbl_deep_extend('force', getfenv(), {
            vim = { o = {}, go = {}, bo = {}, wo = {} }
         })
         env.vim.o  = self.options:make_meta_accessor(
            function(opt)
               return api.nvim_get_option_value(opt, {})
            end,
            function() show_disable_message('o') end
         )
         env.vim.go = self.options:make_meta_accessor(
            function(opt)
               return api.nvim_get_option_value(opt, { scope = 'global' })
            end,
            function() show_disable_message('go') end
         )
         env.vim.bo = self.options:make_meta_accessor(
            function(opt)
               return api.nvim_buf_get_option(0, opt)
            end,
            function() show_disable_message('bo') end
         )
         env.vim.wo = self.options:make_meta_accessor(
            function(opt)
               return api.nvim_win_get_option(0, opt)
            end,
            function() show_disable_message('wo') end
         )

         setfenv(self.config.on_exit, env)
      end
      self:_setup_hydra_keymaps()
   else -- color == 'pink'
      self:_setup_pink_hydra()
   end
end

function Hydra:_setup_hydra_keymaps()
   self:_set_keymap(self.plug_wait, function() self:_leave() end)

   -- Define entering keymap if Hydra is called only on body keymap.
   if self.config.invoke_on_body and self.body then
      self:_set_keymap(self.body, function()
         self:_enter()
         if self.config.on_key then self.config.on_key() end
         self:_wait()
      end, { desc = self.config.desc })
   end

   -- Define Hydra kyebindings.
   for head, map in pairs(self.heads) do
      local rhs, opts = map[1], map[2]

      local function keymap()
         if not rhs then return end
         local keys
         if opts.expr then
            if type(rhs) == 'function' then
               keys = rhs()
            elseif type(rhs) == 'string' then
               keys = api.nvim_eval(rhs)
            end
         elseif type(rhs) == 'function' then
            rhs()
            return
         elseif type(rhs) == 'string' then
            keys = rhs
         end
         local fmode = opts.remap and 'm' or 'n'
         if not opts.exit then
            fmode = fmode .. 'x'
         end
         api.nvim_feedkeys(termcodes(keys), fmode, false)
      end

      -- Define enter mapping
      if not self.config.invoke_on_body
         and not opts.exit
         and not opts.private
      then
         self:_set_keymap(self.body .. head, function()
            self:_enter()
            keymap()
            if opts.on_key ~= false and self.config.on_key then
               self.config.on_key()
            end
            self:_wait()
         end, opts)
      end

      -- Define mapping
      if opts.exit_before then -- blue head
         self:_set_keymap(self.plug_wait .. head, function()
            self:exit(); keymap()
         end, opts)
      elseif opts.exit then -- blue head
         self:_set_keymap(self.plug_wait .. head, function()
            keymap(); self:exit()
         end, opts)
      else -- red head
         self:_set_keymap(self.plug_wait .. head, function()
            keymap()
            if opts.on_key ~= false and self.config.on_key then
               self.config.on_key()
            end
            if self.hint.update then self.hint:update() end
            self:_wait()
         end, opts)
      end

      -- Assumption:
      -- Special keys such as <C-u> are escaped with < and >, i.e.,
      -- key sequences doesn't directly contain any escape sequences.
      local keys = vim.fn.split(head, [[\(<[^<>]\+>\|.\)\zs]])
      for i = #keys - 1, 1, -1 do
         local first_n_keys = table.concat(vim.list_slice(keys, 1, i))
         self:_set_keymap(self.plug_wait .. first_n_keys, function()
            local leave = self:_leave()
            if leave then
               api.nvim_feedkeys(termcodes(first_n_keys), 'ti', false)
            end
         end)
      end
   end
end

function Hydra:_setup_pink_hydra()
   local layer = { enter = {}, layer = {}, exit = {} }
   layer.config = {
      debug = self.config.debug,
      desc = self.config.desc,
      buffer = self.config.buffer,
      timeout = self.config.timeout,
      on_key = function()
         if self.hint.update then self.hint:update() end
         if self.config.on_key then self.config.on_key() end
      end,
      on_enter = {
         function()
            _G.Hydra = self
            self.hint:show()
         end,
         self.config.on_enter
      },
      on_exit = {
         self.config.on_exit,
         function()
            self.hint:close()
            self.options:restore()
            vim.cmd 'echo'
            _G.Hydra = nil
         end
      }
   }

   if self.config.invoke_on_body and self.body then
      layer.enter[1] = { self.mode, self.body }
   end

   for head, map in pairs(self.heads) do
      -- head = termcodes(head)
      local rhs  = map[1]
      local opts = map[2] or {} ---@type hydra.HeadOpts

      ---@type hydra.NvimKeymapOpts
      local o = {
         expr   = opts.expr,
         nowait = opts.nowait,
         silent = opts.silent,
         desc   = opts.desc,
         exit_before = opts.exit_before
      }

      local mode = opts.mode or self.mode

      if self.body
         and not self.config.invoke_on_body
         and not opts.exit
         and not opts.private
      then
         table.insert(layer.enter, { mode, self.body .. head, rhs, o })
      end

      table.insert(opts.exit and layer.exit or layer.layer, { mode, head, rhs, o })
   end

   local Layer = require('hydra.layer')

   ---@type hydra.Layer
   self.layer = Layer(layer)
end

function Hydra:_enter()
   if _G.Hydra then
      if _G.Hydra.layer then
         _G.Hydra.layer:exit()
      else
         _G.Hydra:exit()
      end
   end
   _G.Hydra = self

   local o = self.options.o
   o.showcmd = false

   if self.config.timeout then
      o.timeout = true
      if type(self.config.timeout) == 'number' then
         o.timeoutlen = self.config.timeout
      end
   else
      o.timeout = false
   end
   o.ttimeout = not self.options.original.o.timeout
                or self.options.original.o.ttimeout

   if self.config.on_enter then self.config.on_enter() end

   self.hint:show()
end

---Programmatically activate hydra
function Hydra:activate()
   if self.layer then
      self.layer:activate()
   else
      self:_enter()
      self:_wait()
   end
end

-- Deactivate hydra
function Hydra:exit()
   self.options:restore()
   self.hint:close()
   if self.config.on_exit then self.config.on_exit() end
   _G.Hydra = nil
   vim.cmd 'echo'
end

function Hydra:_wait()
   api.nvim_feedkeys(termcodes(self.plug_wait), '', false)
end

---@return boolean condition Are we leaving hydra or not?
function Hydra:_leave()
   if self.config.color == 'amaranth' or self.config.color == 'teal' then
      self.hint:leave()
      if vim.fn.getchar(1) ~= 0 then
         vim.fn.getchar()
      end
      self:_wait()
      return false
   else
      self:exit()
      return true
   end
end

---@param lhs string
---@param rhs function
---@param opts? hydra.HeadOpts
function Hydra:_set_keymap(lhs, rhs, opts)
   opts = opts or {}
   vim.keymap.set(self.mode, lhs, rhs, {
      buffer = self.config.buffer,
      desc = opts.desc,
      silent = opts.silent
   })
end

function Hydra:debug(...)
   if self.config.debug then
      vim.pretty_print(...)
   end
end

return Hydra
