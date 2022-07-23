local Class = require('hydra.class')
local hint = require('hydra.hint')
local options = require('hydra.meta-accessor')
local util = require('hydra.util')
local termcodes = util.termcodes

---Currently active hydra
_G.Hydra = nil

---@class Hydra
---@field id number
---@field name? string
---@field hint hydra.Hint
---@field config hydra.Config
---@field mode string | string[]
---@field body? string
---@field heads table<string, hydra.Head>
---@field heads_spec table<string, hydra.HeadSpec>
---@field options hydra.MetaAccessor
---@field plug table<string, string>
local Hydra = Class()

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
function Hydra:_constructor(input)
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
            hint = { input.config.hint, { 'boolean', 'string', 'table' }, true }
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
   self.config = util.megre_config(default_config, input.config or {})
   self.mode  = input.mode or 'n'
   self.body  = input.body
   self.options = options('hydra.options')

   -- make Hydra buffer-local
   if self.config.buffer and type(self.config.buffer) ~= 'number' then
      self.config.buffer = vim.api.nvim_get_current_buf()
   end

   -- Bring 'foreign_keys', 'exit' and 'color' options into line.
   local color = util.get_color_from_config(self.config.foreign_keys, self.config.exit)
   if color ~= 'red' and color ~= self.config.color then
      self.config.color = color
   elseif color ~= self.config.color then
      self.config.foreign_keys, self.config.exit = util.get_config_from_color(self.config.color)
   end

   if not self.body or self.config.exit then
      self.config.invoke_on_body = true
   end

   -- Table with all left hand sides of key mappings of the type `<Plug>...`.
   self.plug = setmetatable({}, {
      __index = function(t, key)
         t[key] = ('<Plug>(Hydra%s_%s)'):format(self.id, key)
         return t[key]
      end
   })

   self.heads = {};
   self.heads_spec = {}
   local has_exit_head = self.config.exit
   for index, head in ipairs(input.heads) do
      local lhs, rhs, opts = head[1], head[2], head[3] or {}
      ---@cast lhs string

      if opts.exit ~= nil then -- User explicitly passed `exit` parameter to the head
         color = util.get_color_from_config(self.config.foreign_keys, opts.exit)
         if opts.exit and not has_exit_head then
            has_exit_head = true
         end
      else
         opts.exit = self.config.exit
         color = self.config.color
      end

      -- if opts.exit and not rhs then
      --    color = 'blue'
      -- end

      if type(opts.mode) == 'string' then
         opts.mode = { opts.mode }
      end

      self.heads_spec[lhs] = {
         head = lhs,
         index = index,
         color = color:gsub("^%l", string.upper), -- capitalize first letter
         desc = opts.desc
      }

      if type(opts.desc) ~= 'string' then opts.desc = nil end

      ---@cast rhs string | function | nil
      ---@cast opts hydra.HeadOpts
      self.heads[lhs] = { rhs, opts }
   end
   if not has_exit_head then
      self.heads['<Esc>'] = { nil, { exit = true }}
      self.heads_spec['<Esc>'] = {
         head = '<Esc>',
         index = vim.tbl_count(self.heads),
         color = self.config.foreign_keys == 'warn' and 'Teal' or 'Blue',
         -- color = 'Blue',
         desc = 'exit'
      }
   end

   if self.config.hint and not self.config.hint.type then
      if input.hint then
         self.config.hint.type = 'window'
      else
         self.config.hint.type = 'cmdline'
      end
   end
   self.hint = hint(self, self.config.hint, input.hint)

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
         }) --[[@as table]]
         env.vim.o  = self.options.o
         env.vim.go = self.options.go
         env.vim.bo = self.options.bo
         env.vim.wo = self.options.wo

         setfenv(self.config.on_enter, env)
      end
      if self.config.on_exit then

         ---@param name string
         ---@return MetaAccessor
         local function disable_meta_accessor(name)
            local function disable()
               util.warn(string.format(
                  '"vim.%s" meta-accessor is disabled inside config.on_exit() function',
                  name))
            end
            return self.options.make_meta_accessor(disable, disable)
         end

         local env = vim.tbl_deep_extend('force', getfenv(), {
            vim = { o = {}, go = {}, bo = {}, wo = {} }
         }) --[[@as table]]
         env.vim.o  = disable_meta_accessor('o')
         env.vim.go = disable_meta_accessor('go')
         env.vim.bo = disable_meta_accessor('bo')
         env.vim.wo = disable_meta_accessor('wo')

         setfenv(self.config.on_exit, env)
      end
      self:_setup_hydra_keymaps()
   else  -- color == 'pink'
      self:_setup_pink_hydra()
   end
end

function Hydra:_setup_hydra_keymaps()
   self:_set_keymap(self.plug.wait, function() self:_leave() end)

   -- Define entering keymap if Hydra is called only on body keymap.
   if self.config.invoke_on_body and self.body then
      self:_set_keymap(self.body, function()
         self:_enter()
         if self.config.on_key then self.config.on_key() end
         self:_wait()
      end)
   end

   -- Define Hydra kyebindings.
   for head, map in pairs(self.heads) do
      local rhs, opts = map[1], map[2]

      local keymap = function()
         if not rhs then return end
         local keys, mode ---@type string
         if opts.expr then
            if type(rhs) == 'function' then
               keys = rhs()
            elseif type(rhs) == 'string' then
               keys = vim.api.nvim_eval(rhs)
            end
         elseif type(rhs) == 'function' then
            rhs()
            return
         elseif type(rhs) == 'string' then
            keys = rhs
         end
         keys = util.termcodes(keys)
         mode = opts.remap and 'im' or 'in'
         vim.api.nvim_feedkeys(keys, mode, true)
      end

      -- Define enter mapping
      if not self.config.invoke_on_body
         and not opts.exit
         and not opts.private
      then
         self:_set_keymap(self.body..head, function()
            self:_enter()
            keymap()
            if opts.on_key ~= false and self.config.on_key then
               self.config.on_key()
            end
            self:_wait()
         end, opts)
      end

      -- Define mapping
      if opts.exit then -- blue head
         self:_set_keymap(self.plug.wait..head, function()
            self:exit()
            keymap()
         end, opts)
      else -- red head
         self:_set_keymap(self.plug.wait..head, function()
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
      for i = #keys-1, 1, -1 do
         local first_n_keys = table.concat(vim.list_slice(keys, 1, i))
         self:_set_keymap(self.plug.wait..first_n_keys, function()
            local leave = self:_leave()
            if leave then
               vim.api.nvim_feedkeys( termcodes(first_n_keys), 'ti', false)
            end
         end)
      end
   end
end

function Hydra:_setup_pink_hydra()
   local Layer = require('hydra.layer')

   local function create_layer_input_in_internal_form()
      local layer = util.unlimited_depth_table()
      layer.config = {
         debug = self.config.debug,
         buffer = self.config.buffer,
         timeout = self.config.timeout,
         on_key = function()
            if self.hint.update then self.hint:update() end
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
               vim.api.nvim_echo({}, false, {})  -- vim.cmd 'echo'
               _G.Hydra = nil
            end
         }
      }

      self.mode = type(self.mode) == 'table' and self.mode or { self.mode }

      if self.body then
         self.body = termcodes(self.body)

         if self.config.invoke_on_body then
            for _, mode in ipairs(self.mode) do
               layer.enter_keymaps[mode][self.body] = { '<Nop>', {} }
            end
         end
      end

      for head, map in pairs(self.heads) do
         head = termcodes(head)
         local rhs = map[1] or '<Nop>'
         local opts = map[2] or {} ---@type hydra.HeadOpts

         ---@type KeymapOpts
         local o = {
            desc = opts.desc,
            nowait = opts.nowait,
            silent = opts.silent
         }

         for _, mode in ipairs(opts.mode or self.mode) do
            if self.body
               and not self.config.invoke_on_body
               and not opts.exit
               and not opts.private
            then
               layer.enter_keymaps[mode][self.body..head] = { rhs, o }
            end

            if opts.exit then
               layer.exit_keymaps[mode][head] = { rhs, o }
            else
               layer.layer_keymaps[mode][head] = { rhs, o }
            end
         end
      end

      util.deep_unsetmetatable(layer)
      return layer
   end

   local function create_layer_input_in_public_form()
      local layer = { enter = {}, layer = {}, exit = {} }
      layer.config = {
         debug = self.config.debug,
         buffer = self.config.buffer,
         timeout = self.config.timeout,
         on_key = self.hint.update,
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
               vim.api.nvim_echo({}, false, {})  -- vim.cmd 'echo'
               _G.Hydra = nil
            end
         }
      }

      if self.config.invoke_on_body then
         layer.enter[1] = { self.mode, self.body }
      end

      for head, map in pairs(self.heads) do
         head = termcodes(head)
         local rhs  = map[1]
         local opts = map[2] or {} ---@type hydra.HeadOpts

         ---@type KeymapOpts
         local o = {
            desc = opts.desc,
            nowait = opts.nowait,
            silent = opts.silent
         }

         local mode = opts.mode or self.mode

         if not self.config.invoke_on_body and not opts.exit and not opts.private then
            table.insert(layer.enter, { mode, self.body..head, rhs, o })
         end

         if opts.exit then
            table.insert(layer.exit, { mode, head, rhs, o })
         else
            table.insert(layer.layer, { mode, head, rhs, o })
         end
      end

      return layer
   end

   local layer = create_layer_input_in_internal_form()
   -- local layer = create_layer_input_in_public_form()

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
   o.ttimeout = not self.options.original.timeout and true
                or self.options.original.ttimeout

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
   vim.api.nvim_echo({}, false, {})  -- vim.cmd 'echo'
end

function Hydra:_wait()
   vim.api.nvim_feedkeys( termcodes(self.plug.wait), '', false)
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
   local o = {} ---@type KeymapOpts
   o.buffer = self.config.buffer
   if opts then
      o.desc = opts.desc
      o.silent = opts.silent
   end
   vim.keymap.set(self.mode, lhs, rhs, o)
end

function Hydra:debug(...)
   if self.config.debug then
      vim.pretty_print(...)
   end
end

return Hydra
