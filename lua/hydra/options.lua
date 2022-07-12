local Class = require('hydra.class')
local util = require('hydra.util')

---@class HydraOptions
---@field augroup_id integer
---@field o MetaAccessor
---@field go MetaAccessor
---@field bo MetaAccessor
---@field wo MetaAccessor
local opts = Class()

---@param augroup_name string
function opts:_constructor(augroup_name)
   self.augroup_name = augroup_name
   self.augroup_id = vim.api.nvim_create_augroup(augroup_name, { clear = true })
   self.original = {}

   self.o = util.make_meta_accessor(
      function(opt)
         return vim.api.nvim_get_option_value(opt, {})
      end,
      function(opt, val)
         self.original.o = self.original.o or {}
         self.original.o[opt] = vim.api.nvim_get_option_value(opt, {})
         vim.api.nvim_set_option_value(opt, val, {})
      end
   )

   self.go = util.make_meta_accessor(
      function(opt)
         return vim.api.nvim_get_option_value(opt, { scope = 'global' })
      end,
      function(opt, val)
         self.original.go = self.original.go or {}
         self.original.go[opt] = vim.api.nvim_get_option_value(opt, { scope = 'global' })
         vim.api.nvim_set_option_value(opt, val, { scope = 'global' })
      end
   )

   self.bo = util.make_meta_accessor(
      function(opt)
         -- assert(type(opt) ~= 'number',
         --    '[Hydra] "vim.bo[bufnr]" meta-aссessor in config.on_enter() function is forbiden, use "vim.bo" instead')
         return vim.api.nvim_buf_get_option(0, opt)
      end,
      function(opt, val)
         self:_set_buf_option(opt, val)

         vim.api.nvim_create_autocmd('BufEnter', {
            group = self.augroup_id,
            desc = string.format('set "%s" buffer option', opt),
            callback = function()
               self:_set_buf_option(opt, val)
            end
         })
      end
   )

   self.wo = util.make_meta_accessor(
      function(opt)
         -- assert(type(opt) ~= 'number',
         --    '[Hydra] "vim.wo[winnr]" meta-aссessor in config.on_enter() function is forbiden, use "vim.wo" instead')
         return vim.api.nvim_win_get_option(0, opt)
      end,
      function(opt, val)
         self:_set_win_option(opt, val)

         vim.api.nvim_create_autocmd('WinEnter', {
            group = self.augroup_id,
            desc = string.format('set "%s" window option', opt),
            callback = function()
               self:_set_win_option(opt, val)
            end
         })
      end
   )
end

function opts:_set_buf_option(opt, val)
   local bufnr = vim.api.nvim_get_current_buf()
   self.original.bo = self.original.bo or {}
   self.original.bo[bufnr] = self.original.bo[bufnr] or {}
   if self.original.bo[bufnr][opt] then return end
   self.original.bo[bufnr][opt] = vim.api.nvim_buf_get_option(bufnr, opt)
   vim.api.nvim_buf_set_option(bufnr, opt, val)
end

function opts:_set_win_option(opt, val)
   local winnr = vim.api.nvim_get_current_win()
   self.original.wo = self.original.wo or {}
   self.original.wo[winnr] = self.original.wo[winnr] or {}
   if self.original.wo[winnr][opt] then return end
   self.original.wo[winnr][opt] = vim.api.nvim_win_get_option(winnr, opt)
   vim.api.nvim_win_set_option(winnr, opt, val)
end

function opts:restore()
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

   vim.api.nvim_clear_autocmds({ group = self.augroup_id })
   self.original = {}
end

return opts
