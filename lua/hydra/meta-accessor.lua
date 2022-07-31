local Class = require('hydra.class')

---@class hydra.MetaAccessor.original
---@field o table<string, any>
---@field go table<string, any>
---@field bo table<integer, table<string, any>>
---@field wo table<integer, table<string, any>>

---@class hydra.MetaAccessor
---@field _augroup_id integer
---@field o MetaAccessor
---@field go MetaAccessor
---@field bo MetaAccessor
---@field wo MetaAccessor
---@field original hydra.MetaAccessor.original
local ma = Class()

---@param augroup_name string
function ma:_constructor(augroup_name)
   self._augroup_name = augroup_name
   self._augroup_id = vim.api.nvim_create_augroup(augroup_name, { clear = true })
   self.original = {}

   self.o = self.make_meta_accessor(
      ---@param opt string
      function(opt)
         return vim.api.nvim_get_option_value(opt, {})
      end,
      ---@param opt string
      ---@param val any
      function(opt, val)
         self.original.o = self.original.o or {}
         if not self.original.o[opt] then
            self.original.o[opt] = vim.api.nvim_get_option_value(opt, {})
         end
         vim.api.nvim_set_option_value(opt, val, {})
      end
   )

   self.go = self.make_meta_accessor(
      ---@param opt string
      function(opt)
         return vim.api.nvim_get_option_value(opt, { scope = 'global' })
      end,
      ---@param opt string
      ---@param val any
      function(opt, val)
         self.original.go = self.original.go or {}
         if self.original.go[opt] then
            self.original.go[opt] = vim.api.nvim_get_option_value(opt, { scope = 'global' })
         end
         vim.api.nvim_set_option_value(opt, val, { scope = 'global' })
      end
   )

   self.bo = self.make_meta_accessor(
      ---@param opt string
      function(opt)
         -- assert(type(opt) ~= 'number',
         --    '[Hydra] "vim.bo[bufnr]" meta-aссessor in config.on_enter() function is forbiden, use "vim.bo" instead')
         return vim.api.nvim_buf_get_option(0, opt)
      end,
      ---@param opt string
      ---@param val any
      function(opt, val)
         self:_set_buf_option(opt, val)

         vim.api.nvim_create_autocmd('BufEnter', {
            group = self._augroup_id,
            desc = string.format('set "%s" buffer option', opt),
            callback = function()
               self:_set_buf_option(opt, val)
            end
         })
      end
   )

   self.wo = self.make_meta_accessor(
      ---@param opt string
      function(opt)
         -- assert(type(opt) ~= 'number',
         --    '[Hydra] "vim.wo[winnr]" meta-aссessor in config.on_enter() function is forbiden, use "vim.wo" instead')
         return vim.api.nvim_win_get_option(0, opt)
      end,
      ---@param opt string
      ---@param val any
      function(opt, val)
         self:_set_win_option(opt, val)

         vim.api.nvim_create_autocmd('WinEnter', {
            group = self._augroup_id,
            desc = string.format('set "%s" window option', opt),
            callback = function()
               self:_set_win_option(opt, val)
            end
         })
      end
   )
end

--- **Static method**
---@param get function
---@param set function
---@return MetaAccessor
function ma.make_meta_accessor(get, set)
   return setmetatable({}, {
      __index = not get and nil or function(_, k) return get(k) end,
      __newindex = not set and nil or function(_, k, v) return set(k, v) end
   })
end

---@param opt string
---@param val any
function ma:_set_buf_option(opt, val)
   ---@type integer
   local bufnr = vim.api.nvim_get_current_buf()
   self.original.bo = self.original.bo or {}
   self.original.bo[bufnr] = self.original.bo[bufnr] or {}

   if not self.original.bo[bufnr][opt] then
      self.original.bo[bufnr][opt] = vim.api.nvim_buf_get_option(bufnr, opt)
   end
   vim.api.nvim_buf_set_option(bufnr, opt, val)
end

---@param opt string
---@param val any
function ma:_set_win_option(opt, val)
   ---@type integer
   local winnr = vim.api.nvim_get_current_win()
   self.original.wo = self.original.wo or {}
   self.original.wo[winnr] = self.original.wo[winnr] or {}
   if not self.original.wo[winnr][opt] then
      self.original.wo[winnr][opt] = vim.api.nvim_win_get_option(winnr, opt)
   end
   vim.api.nvim_win_set_option(winnr, opt, val)
end

function ma:restore()
   for _, otype in ipairs({'o', 'go'}) do
      if self.original[otype] then
         for opt, val in pairs(self.original[otype]) do
            vim[otype][opt] = val
         end
      end
   end

   if self.original.bo then
      for bufnr, opts in pairs(self.original.bo) do
         if vim.api.nvim_buf_is_valid(bufnr) then
            for opt, val in pairs(opts) do
               vim.bo[bufnr][opt] = val
            end
         end
      end
   end

   if self.original.wo then
      for winnr, opts in pairs(self.original.wo) do
         if vim.api.nvim_win_is_valid(winnr) then
            for opt, val in pairs(opts) do
               vim.wo[winnr][opt] = val
            end
         end
      end
   end

   vim.api.nvim_clear_autocmds({ group = self._augroup_id })
   self.original = {}
end

return ma
