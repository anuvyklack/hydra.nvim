local Class = require('hydra.class')
local options = require('hydra.meta-accessor')
local util = require('hydra.util')
local termcodes = util.termcodes

local augroup_name = 'Layer'
local augroup_id = vim.api.nvim_create_augroup(augroup_name, { clear = true })

---Currently active layer
_G.active_keymap_layer = nil

---@class hydra.Layer
---@field active boolean
---@field config hydra.layer.Config
---@field enter_keymaps table
---@field layer_keymaps table
---@field options hydra.MetaAccessor
---@field timer uv.Timer | nil
---@field saved_keymaps table
local Layer = Class()

---@class hydra.layer.Config
---@field debug? boolean
---@field buffer? integer
---@field timeout? integer
---@field on_key? function
---@field on_enter? table<integer, function>
---@field on_exit? table<integer, function>

---@param input table
function Layer:_constructor(input)
   if input.enter then
      for _, keymap in ipairs(input.enter) do
         local opts = keymap[4] or {}
         vim.validate({
              expr = { opts.expr,   'boolean', true },
            silent = { opts.silent, 'boolean', true },
            nowait = { opts.nowait, 'boolean', true },
              desc = { opts.desc,   'string',  true },
         })
      end
   end
   if input.layer then
      for _, keymap in ipairs(input.layer) do
         local opts = keymap[4] or {}
         vim.validate({
              expr = { opts.expr,   'boolean', true },
            silent = { opts.silent, 'boolean', true },
            nowait = { opts.nowait, 'boolean', true },
              desc = { opts.desc,   'string',  true },
         })
      end
   end
   if input.exit then
      for _, keymap in ipairs(input.exit) do
         local opts = keymap[4] or {}
         vim.validate({
            expr = { opts.expr, 'boolean', true },
            silent = { opts.silent, 'boolean', true },
            nowait = { opts.nowait, 'boolean', true },
            desc = { opts.desc, 'string', true },
         })
      end
   end
   if input.config then
      vim.validate({
         on_enter = { input.config.on_enter, { 'function', 'table' }, true },
         on_exit = { input.config.on_exit, { 'function', 'table' }, true },
         timeout = { input.config.timeout, { 'boolean', 'number' }, true },
         buffer = { input.config.buffer, { 'boolean', 'number' }, true }
      })
   end

   self.active = false
   self.id = util.generate_id() -- Unique ID for each Layer.
   self.config = input.config or {}
   if self.config.timeout == true then
      self.config.timeout = vim.o.timeoutlen --[[@as integer]]
   end
   if self.config.buffer == true then
      self.config.buffer = vim.api.nvim_get_current_buf()
   end
   if type(self.config.on_enter) == 'function' then
      self.config.on_enter = { self.config.on_enter }
   end
   if type(self.config.on_exit) == 'function' then
      self.config.on_exit = { self.config.on_exit }
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

      for _, fun in pairs(self.config.on_exit) do
         setfenv(fun, env)
      end
   end

   local exit_keymaps
   if not input.layer_keymaps then
      self.enter_keymaps, self.layer_keymaps, exit_keymaps =
         self:_normalize_input(input.enter, input.layer, input.exit)
   else -- input was passed already in the internal form.
      self.enter_keymaps = input.enter_keymaps
      self.layer_keymaps = input.layer_keymaps
      exit_keymaps  = input.exit_keymaps
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
            local rhs, opts = map[1], map[2] or {}
            local keymap = self._make_keymap_function(mode, rhs, opts)

            vim.keymap.set(mode, lhs, function()
               keymap()
               self:activate()
            end, {
               buffer = self.config.buffer,
               nowait = opts.nowait,
               silent = opts.silent,
               desc = opts.desc
            })
         end
      end
   end

   -- Setup layer keybindings
   for mode, maps in pairs(self.layer_keymaps) do
      for lhs, map in pairs(maps) do
         local rhs, opts = map[1], map[2] or {}
         local keymap = self._make_keymap_function(mode, rhs, opts)

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
            local keymap = self._make_keymap_function(mode, rhs, opts)
            self.layer_keymaps[mode] = self.layer_keymaps[mode] or {}
            self.layer_keymaps[mode][lhs] = {
               function()
                  self:exit()
                  keymap()
               end,
               {
                  nowait = opts.nowait,
                  silent = opts.silent,
                  desc = opts.desc
               }
            }
         end
      end
   end
end

---Activate layer
function Layer:activate()
   if _G.active_keymap_layer and _G.active_keymap_layer.id == self.id then
      return
   end
   _G.active_keymap_layer = self
   self.active = true

   if self.config.on_enter then
      for _, fun in pairs(self.config.on_enter) do
         fun()
      end
   end

   local bufnr = self.config.buffer or vim.api.nvim_get_current_buf()
   self:_setup_keymaps(bufnr)

   self:_timer()

   -- Apply Layer keybindings on every visited buffer while Layer is active.
   if not self.config.buffer then
      vim.api.nvim_create_autocmd('BufEnter', {
         group = augroup_id,
         desc = 'setup Layer keymaps',
         callback = function(input)
            self:_setup_keymaps(input.buf)
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

   vim.api.nvim_clear_autocmds({ group = augroup_id })

   self.active = false
   _G.active_keymap_layer = nil
end

function Layer:_normalize_input(enter, layer, exit)
   local r = {}
   for i, mappings in ipairs({ enter, layer, exit }) do
      if mappings then
         local k = util.unlimited_depth_table()
         for _, map in ipairs(mappings) do
            local mode, lhs, rhs, opts = map[1], map[2], map[3] or '<Nop>', map[4] or {}
            lhs = termcodes(lhs)
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
---@param opts? KeymapOpts
---@return function
function Layer._make_keymap_function(mode, rhs, opts)
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
         vim.api.nvim_feedkeys(util.termcodes('<Esc>'), 'n', false)
         -- local m = opts.remap and 'xm' or 'xn'
         -- vim.api.nvim_feedkeys(operator, m, false)
         vim.api.nvim_feedkeys(operator, 'x', false)
         vim.fn.winrestview(win_view)
      end

      local f = {} -- keys to feed
      if opts.expr then
         if type(rhs) == 'function' then
            f.keys = rhs()
         elseif type(rhs) == 'string' then
            f.keys = vim.api.nvim_eval(rhs)
         end
      elseif type(rhs) == 'function' then
         rhs()
         return
      elseif type(rhs) == 'string' then
         f.keys = rhs
      end
      f.keys = util.termcodes(f.keys)
      f.mode = opts.remap and 'im' or 'in'
      vim.api.nvim_feedkeys(f.keys, f.mode, true)
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

   for mode, keymaps in pairs(self.layer_keymaps) do
      self.saved_keymaps[bufnr][mode] = {}
      for _, map in ipairs(vim.api.nvim_buf_get_keymap(bufnr, mode)) do
         map.lhs = termcodes(map.lhs)
         if keymaps[map.lhs] then
            self.saved_keymaps[bufnr][mode][map.lhs] = {
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

---Restore original keymaps and options overwritten by Layer
function Layer:_restore_keymaps()
   if not self.active then return end

   -- Restore keymaps
   for mode, keymaps in pairs(self.layer_keymaps) do
      for lhs, _ in pairs(keymaps) do
         for bufnr, _ in pairs(self.saved_keymaps) do
            if vim.api.nvim_buf_is_valid(bufnr) then
               local map = self.saved_keymaps[bufnr][mode][lhs]
               if map then
                  vim.api.nvim_buf_set_keymap(bufnr, mode, lhs, map.rhs, {
                     expr = map.expr,
                     callback = map.callback,
                     noremap = map.noremap,
                     script = map.script,
                     silent = map.silent,
                     nowait = map.nowait
                  })
               else
                  vim.keymap.del(mode, lhs, { buffer = bufnr })
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
