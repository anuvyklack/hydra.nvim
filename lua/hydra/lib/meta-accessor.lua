local class = require('hydra.lib.class')
local api = vim.api

---@class hydra.MetaAccessor.original
---@field o table<string, any>
---@field go table<string, any>
---@field bo table<integer, table<string, any>>
---@field wo table<integer, table<string, any>>

---@class hydra.MetaAccessor
---@field _augroup integer
---@field o hydra.MetaAccessor
---@field go hydra.MetaAccessor
---@field bo hydra.MetaAccessor
---@field wo hydra.MetaAccessor
---@field original hydra.MetaAccessor.original
local ma = class()

---@param augroup string
function ma:initialize(augroup)
   self._augroup = api.nvim_create_augroup(augroup, { clear = true })
   self.original = {}

   self.o = self:make_meta_accessor(
      ---@param opt string
      function(opt)
         return api.nvim_get_option_value(opt, {})
      end,

      ---@param opt string
      function(opt, val)
         self.original.o = self.original.o or {}
         if not self.original.o[opt] then
            self.original.o[opt] = api.nvim_get_option_value(opt, {})
         end
         api.nvim_set_option_value(opt, val, {})
      end
   )

   self.go = self:make_meta_accessor(
      ---@param opt string
      function(opt)
         return api.nvim_get_option_value(opt, { scope = 'global' })
      end,

      ---@param opt string
      function(opt, val)
         self.original.go = self.original.go or {}
         if self.original.go[opt] then
            self.original.go[opt] = api.nvim_get_option_value(opt, { scope = 'global' })
         end
         api.nvim_set_option_value(opt, val, { scope = 'global' })
      end
   )

   self.bo = self:make_meta_accessor(
      ---@param opt string
      function(opt)
         return api.nvim_buf_get_option(0, opt)
      end,

      ---@param opt string
      function(opt, val)
         self:_set_buf_option(opt, val)

         api.nvim_create_autocmd('BufEnter', {
            group = self._augroup,
            desc = string.format('set "%s" buffer option', opt),
            callback = function() self:_set_buf_option(opt, val) end
         })
      end
   )

   self.wo = self:make_meta_accessor(
      ---@param opt string
      function(opt)
         return api.nvim_win_get_option(0, opt)
      end,

      ---@param opt string
      function(opt, val)
         self:_set_win_option(opt, val)

         api.nvim_create_autocmd('WinEnter', {
            group = self._augroup,
            desc = string.format('set "%s" window option', opt),
            callback = function() self:_set_win_option(opt, val) end
         })
      end
   )
end

--- **Static method**
---@param get function
---@param set function
---@return hydra.MetaAccessor
function ma:make_meta_accessor(get, set)
   return setmetatable({}, {
      __index = not get and nil or function(_, k) return get(k) end,
      __newindex = not set and nil or function(_, k, v) return set(k, v) end
   })
end

---@param opt string
function ma:_set_buf_option(opt, val)
   ---@type integer
   local bufnr = api.nvim_get_current_buf()
   self.original.bo = self.original.bo or {}
   self.original.bo[bufnr] = self.original.bo[bufnr] or {}

   if not self.original.bo[bufnr][opt] then
      self.original.bo[bufnr][opt] = api.nvim_buf_get_option(bufnr, opt)
   end
   api.nvim_buf_set_option(bufnr, opt, val)
end

---@param opt string
function ma:_set_win_option(opt, val)
   ---@type integer
   local winnr = api.nvim_get_current_win()
   self.original.wo = self.original.wo or {}
   self.original.wo[winnr] = self.original.wo[winnr] or {}
   if not self.original.wo[winnr][opt] then
      self.original.wo[winnr][opt] = api.nvim_win_get_option(winnr, opt)
   end
   api.nvim_win_set_option(winnr, opt, val)
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
         if api.nvim_buf_is_valid(bufnr) then
            for opt, val in pairs(opts) do
               api.nvim_buf_set_option(bufnr, opt, val)
            end
         end
      end
   end

   if self.original.wo then
      for winnr, opts in pairs(self.original.wo) do
         if api.nvim_win_is_valid(winnr) then
            for opt, val in pairs(opts) do
               api.nvim_win_set_option(winnr, opt, val)
            end
         end
      end
   end

   api.nvim_clear_autocmds({ group = self._augroup })
   self.original = {}
end

return ma
