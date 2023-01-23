--[[
The Layer class accepts keymaps in the one form, but stores them internally in
the another.  The `Layer:_normalize_input()` method is responsible for this. It
allows utilize built-in Lua table properties, and simplifies such things as get
desired normal mode keybinding without looping through the whole list every time.

   +---------------------------------+-------------------------------------+
   |              Input              |              Internal               |
   +---------------------------------+-------------------------------------+
   |                                 |                                     |
   |     {mode, lhs, rhs, opts}      |    mode = { lhs = {rhs, opts} }     |
   |                                 |                                     |
   +---------------------------------+-------------------------------------+
   |                                 |                                     |
   |                                 |    enter_keymaps = {                |
   |                                 |       n = {                         |
   |     enter = {                   |          zl = {'zl', {}},           |
   |        {'n', 'zl', 'zl'},       |          zh = {'zh', {}},           |
   |        {'n', 'zh', 'zh'},       |          gz = {'<Nop>', {}}         |
   |        {'n', 'gz'},             |       }                             |
   |     },                          |    },                               |
   |     layer = {                   |    layer_keymaps = {                |
   |        {'n', 'l', 'zl'},        |       n = {                         |
   |        {'n', 'h', 'zh'},        |          l = {'zl', {}},            |
   |     },                          |          h = {'zh', {}}             |
   |     exit = {                    |       }                             |
   |        {'n', '<Esc>'},          |    },                               |
   |        {'n', 'q'}               |    exit_keymaps = {                 |
   |     }                           |       n = {                         |
   |                                 |          '<Esc>' = {'<Nop>', {}},   |
   |                                 |          q = {'<Nop>', {}}          |
   |                                 |       }                             |
   |                                 |    }                                |
   |                                 |                                     |
   +---------------------------------+-------------------------------------+
--]]

local class = require('hydra.lib.class')
local options = require('hydra.lib.meta-accessor')
local util = require('hydra.lib.util')
local termcodes = util.termcodes
local api = vim.api
local augroup = api.nvim_create_augroup('keymap-layer', { clear = true })
local autocmd = api.nvim_create_autocmd

---Currently active layer
_G.active_keymap_layer = nil

---@class hydra.Layer
---@field active boolean
---@field config hydra.layer.Config
---@field enter_keymaps table
---@field layer_keymaps table
---@field options hydra.MetaAccessor
---@field timer vim.loop.Timer | nil
---@field saved_keymaps table
local Layer = class()

---@class hydra.layer.Config
---@field debug? boolean
---@field desc string
---@field buffer? integer
---@field timeout? integer
---@field on_key? function
---@field on_enter? table<integer, function>
---@field on_exit? table<integer, function>

---@param input table
function Layer:initialize(input)
   self.active = false
   self.id = util.generate_id() -- Unique ID for each Layer.
   self.config = input.config or {}
   if self.config.timeout == true then
      self.config.timeout = vim.o.timeoutlen
   end
   if self.config.buffer == true then
      self.config.buffer = api.nvim_get_current_buf()
   end
   if type(self.config.on_enter) == 'function' then
      self.config.on_enter = { self.config.on_enter } ---@diagnostic disable-line
   end
   if type(self.config.on_exit) == 'function' then
      self.config.on_exit = { self.config.on_exit } ---@diagnostic disable-line
   end

   self.options = options('hydra.layer_options') -- meta-accessors

   self.saved_keymaps = {}

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

      for _, fun in pairs(self.config.on_enter) do
         setfenv(fun, env)
      end
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

      for _, fun in pairs(self.config.on_exit) do
         setfenv(fun, env)
      end
   end

   local exit_keymaps
   self.enter_keymaps, self.layer_keymaps, exit_keymaps =
      self:_normalize_input(input.enter, input.layer, input.exit)

   do
      local k = {}
      for _, keymaps in ipairs({self.layer_keymaps, exit_keymaps}) do
         for mode, _ in pairs(keymaps) do
            k[mode] = k[mode] or {}
            for lhs, _ in pairs(keymaps[mode]) do
               k[mode][termcodes(lhs)] = lhs
            end
         end
      end
      self.esc_termcodes_layer_keymaps = k
   end

   -- Setup <Esc> key to exit the Layer if no one exit key has been passed.
   if not exit_keymaps then
      exit_keymaps = {}
      for mode, _ in pairs(self.layer_keymaps) do
         exit_keymaps[mode] = { ['<Esc>'] = {} }
      end
   end

   if self.enter_keymaps then
      for mode, keymaps in pairs(self.enter_keymaps) do
         for lhs, map in pairs(keymaps) do
            local rhs  = map[1]
            local opts = map[2] or {}

            local keymap = self:_make_keymap_function(mode, rhs, opts)

            vim.keymap.set(mode, lhs, function()
               keymap()
               self:activate()
            end, {
               buffer = self.config.buffer,
               nowait = opts.nowait,
               silent = opts.silent,
               desc = opts.desc or self.config.desc
            })
         end
      end
   end

   -- Setup layer keybindings
   for mode, maps in pairs(self.layer_keymaps) do
      for lhs, map in pairs(maps) do
         local rhs, opts = map[1], map[2] or {}
         local keymap = self:_make_keymap_function(mode, rhs, opts)

         self.layer_keymaps[mode][lhs] = {
            function()
               keymap()
               if self.config.on_key then self.config.on_key() end
               if self.config.timeout then self:_timer() end
            end,
            {
               nowait = opts.nowait,
               silent = opts.silent,
               desc = opts.desc
            }
         }
      end
   end

   -- Setup keybindings to exit Layer
   if exit_keymaps then
      for mode, keymaps in pairs(exit_keymaps) do
         for lhs, map in pairs(keymaps) do
            local rhs, opts = map[1], map[2] or {}

            local keymap = self:_make_keymap_function(mode, rhs, opts)
            local rhs_fun = opts.exit_before
                            and function() self:exit(); keymap() end
                            or  function() keymap(); self:exit() end

            self.layer_keymaps[mode] = self.layer_keymaps[mode] or {}
            self.layer_keymaps[mode][lhs] = { rhs_fun, {
               nowait = opts.nowait,
               silent = opts.silent,
               desc = opts.desc
            }}
         end
      end
   end
end

---Activate layer
function Layer:activate()
   if _G.active_keymap_layer then
      if _G.active_keymap_layer.id ~= self.id then
         _G.active_keymap_layer:exit()
      else
         return
      end
   end
   _G.active_keymap_layer = self
   self.active = true

   if self.config.on_enter then
      for _, fun in pairs(self.config.on_enter) do
         fun()
      end
   end

   local bufnr = self.config.buffer or api.nvim_get_current_buf()
   self:_setup_keymaps(bufnr)

   self:_timer()

   -- Apply Layer keybindings on every visited buffer while Layer is active.
   if not self.config.buffer then
      autocmd('BufEnter', { group = augroup,
         desc = 'setup Layer keymaps',
         callback = function(ctx) -- context
            self:_setup_keymaps(ctx.buf)
         end
      })
   end
end

---Exit the Layer and restore all previous keymaps
function Layer:exit()
   if not self.active then return end

   if self.timer then
      self.timer:close()
      self.timer = nil
   end

   if self.config.on_exit then
      for _, fun in pairs(self.config.on_exit) do
         fun()
      end
   end

   self:_restore_keymaps()
   self.options:restore()

   api.nvim_clear_autocmds({ group = augroup })

   self.active = false
   _G.active_keymap_layer = nil
end

function Layer:_normalize_input(enter, layer, exit)
   local r = {}
   for i, mappings in ipairs({ enter, layer, exit }) do
      if mappings and not vim.tbl_isempty(mappings) then
         local k = util.unlimited_depth_table()
         for _, map in ipairs(mappings) do
            local mode = map[1]
            local lhs  = map[2]
            local rhs  = map[3] or '<Nop>'
            local opts = map[4] or {}

            if type(mode) == 'table' then
               for _, m in ipairs(mode) do
                  k[m][lhs] = { rhs, opts }
               end
            else
               k[mode][lhs] = { rhs, opts }
            end
         end
         util.deep_unsetmetatable(k)
         r[i] = k
      end
   end
   return r[1], r[2], r[3]
end

---**Static method**
---Wraps a passed keymap into a function, on call of which
---the keymap content will be executed.
---@param mode string
---@param rhs string | function
---@param opts? hydra.NvimKeymapOpts
---@return function
function Layer:_make_keymap_function(mode, rhs, opts)
   opts = opts or {}
   local nop = {
      ['<nop>'] = true,
      ['<Nop>'] = true,
      ['<NOP>'] = true
   }
   if not rhs or nop[rhs] then
      return function() end
   end

   return function()
      if mode == 'o' then -- operator-pending mode
         local win_view = vim.fn.winsaveview()
         local operator = vim.v.operator
         api.nvim_feedkeys(termcodes('<Esc>'), 'n', false)
         api.nvim_feedkeys(operator, 'x', false)
         vim.fn.winrestview(win_view)
      end

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
      local fmode = opts.remap and 'im' or 'in'
      api.nvim_feedkeys(termcodes(keys), fmode, true)
   end
end

---Setup layer keymaps for buffer with number `bufnr`
---@param bufnr integer the buffer ID
function Layer:_setup_keymaps(bufnr)
   -- If original keymaps for `bufnr` buffer are saved,
   -- then we have already set keymaps for that buffer.
   if util.tbl_rawget(self.saved_keymaps, bufnr) then return end

   self:_save_keymaps(bufnr)

   for mode, keymaps in pairs(self.layer_keymaps) do
      for lhs, map in pairs(keymaps) do
         local rhs, opts = map[1], map[2]
         opts.buffer = bufnr
         vim.keymap.set(mode, lhs, rhs, opts)
         opts.buffer = nil
      end
   end
end

---Save key mappings overwritten by Layer for the paticular buffer
---for future restore.
---@param bufnr integer the buffer ID for which to save keymaps
function Layer:_save_keymaps(bufnr)
   assert(not self.saved_keymaps[bufnr], 'Layer:_save_keymaps() called twice for same buffer')
   self.saved_keymaps[bufnr] = {}

   for mode, esc_termcodes_keymaps in pairs(self.esc_termcodes_layer_keymaps)
   do
      self.saved_keymaps[bufnr][mode] = {}
      for _, map in ipairs(api.nvim_buf_get_keymap(bufnr, mode)) do
         local lhs = esc_termcodes_keymaps[termcodes(map.lhs)]
         if lhs then
            self.saved_keymaps[bufnr][mode][lhs] = {
               rhs = map.rhs or '',
               expr = map.expr == 1,
               callback = map.callback,
               noremap = map.noremap == 1,
               script = map.script == 1,
               silent = map.silent == 1,
               nowait = map.nowait == 1,
            }
         end
      end
   end
end

---Restore original keymaps overwritten by Layer.
function Layer:_restore_keymaps()
   if not self.active then return end

   -- Restore keymaps
   for mode, keymaps in pairs(self.layer_keymaps) do
      for lhs, _ in pairs(keymaps) do
         for bufnr, _ in pairs(self.saved_keymaps) do
            if api.nvim_buf_is_valid(bufnr) then
               local map = self.saved_keymaps[bufnr][mode][lhs]
               if map then
                  api.nvim_buf_set_keymap(bufnr, mode, lhs, map.rhs, {
                     expr = map.expr,
                     callback = map.callback,
                     noremap = map.noremap,
                     script = map.script,
                     silent = map.silent,
                     nowait = map.nowait
                  })
               else
                  pcall(vim.keymap.del, mode, lhs, { buffer = bufnr })
               end
            end
         end
      end
   end

   self.saved_keymaps = {}
end

---Set or restart timer
function Layer:_timer()
   if not self.config.timeout then return end

   if self.timer then
      self.timer:again()
   else
      self.timer = vim.loop.new_timer()
      self.timer:start(self.config.timeout, self.config.timeout,
                       vim.schedule_wrap(function() self:exit() end))
   end
end

function Layer:debug(...)
   if self.config.debug then
      vim.pretty_print(...)
   end
end

return Layer
